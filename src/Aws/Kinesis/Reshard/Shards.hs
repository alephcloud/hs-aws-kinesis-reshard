-- Copyright (c) 2013-2014 PivotCloud, Inc.
--
-- Aws.Kinesis.Reshard.Shards
--
-- Please feel free to contact us at licensing@pivotmail.com with any
-- contributions, additions, or other feedback; we would love to hear from
-- you.
--
-- Licensed under the Apache License, Version 2.0 (the "License"); you may
-- not use this file except in compliance with the License. You may obtain a
-- copy of the License at http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
-- WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
-- License for the specific language governing permissions and limitations
-- under the License.
--

{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE UnicodeSyntax #-}

module Aws.Kinesis.Reshard.Shards
( fetchOpenShards
, countOpenShards
, awaitStreamActive
, ReshardingAction(..)
, performReshardingAction
) where

import Aws.Core
import Aws.Kinesis
import Aws.Kinesis.Reshard.Common
import Aws.Kinesis.Reshard.Monad

import Control.Applicative
import Control.Exception.Lifted
import Control.Lens
import Control.Monad
import Control.Monad.Error.Hoist
import Control.Monad.Trans
import Control.Monad.Unicode

import qualified Data.List as L
import Data.Maybe
import Data.Conduit
import qualified Data.Conduit.List as CL
import Prelude.Unicode

data ReshardingAction
  = SplitShardsAction
  | MergeShardsAction
  deriving (Eq, Show)

awaitStreamActive
  ∷ MonadReshard m
  ⇒ m ()
awaitStreamActive = do
  name ← kinesisStreamName
  DescribeStreamResponse StreamDescription{..} ← runKinesis DescribeStream
    { describeStreamLimit = Just 1
    , describeStreamExclusiveStartShardId = Nothing
    , describeStreamStreamName = name
    }
  case streamDescriptionStreamStatus of
    StreamStatusActive → return ()
    _ → awaitStreamActive

fetchShardsConduit
  ∷ MonadReshard m
  ⇒ Conduit (Maybe ShardId) m Shard
fetchShardsConduit = do
  name ← lift kinesisStreamName
  awaitForever $ \mshardId → do
    let req = DescribeStream
          { describeStreamExclusiveStartShardId = mshardId
          , describeStreamLimit = Nothing
          , describeStreamStreamName = name
          }
    resp@(DescribeStreamResponse StreamDescription{..}) ←
      lift $ runKinesis req
    yield `mapM_` streamDescriptionShards
    _ ← traverse (leftover ∘ Just) $
      describeStreamExclusiveStartShardId =≪
        nextIteratedRequest req resp
    return ()

shardsSource
  ∷ MonadReshard m
  ⇒ Source m Shard
shardsSource =
  CL.sourceList [Nothing]
    $= fetchShardsConduit

shardIsOpen
  ∷ Shard
  → Bool
shardIsOpen =
  isNothing
    ∘ view _2
    ∘ shardSequenceNumberRange

counterSink
  ∷ ( Monad m
    , Integral i
    )
  ⇒ Sink α m i
counterSink =
  CL.fold (\i _ → i + 1)  0

fetchOpenShards
  ∷ MonadReshard m
  ⇒ m [Shard]
fetchOpenShards = do
  awaitStreamActive
  shards ← shardsSource
    $= CL.filter shardIsOpen
    $$ CL.consume
  let orderShards s s' = compare (endingHashKey s) (endingHashKey s')
      endingHashKey = view _2 ∘ shardHashKeyRange
  return $ L.sortBy orderShards shards

countOpenShards
  ∷ ( MonadReshard m
    , Integral i
    )
  ⇒ m i
countOpenShards = do
  awaitStreamActive
  shardsSource
    $= CL.filter shardIsOpen
    $$ counterSink

-- | Get a 'PartitionHash' directly in between two other hashes.
partitionHashInRange
  ∷ (PartitionHash, PartitionHash)
  → Either InvalidPartitionHashException PartitionHash
partitionHashInRange range@(lower, upper) = do
  unless (upper > lower) $
    throwError $ InvalidPartitionHashRange range
  let upperInteger = partitionHashInteger upper
      lowerInteger = partitionHashInteger lower
      middleInteger = lowerInteger + (upperInteger - lowerInteger) `div` 2
  partitionHash middleInteger
    & either (Left ∘ InvalidPartitionHash middleInteger) return

performReshardingAction
  ∷ MonadReshard m
  ⇒ ReshardingAction
  → m ()
performReshardingAction SplitShardsAction = do
  stream ← kinesisStreamName
  shard ← (fetchOpenShards ^!? acts ∘ _head) <!?> SomeException (NoShardsFoundException stream)
  startingHashKey ← partitionHashInRange (shardHashKeyRange shard) <%?> SomeException
  SplitShardResponse ← runKinesis SplitShard
    { splitShardNewStartingHashKey = startingHashKey
    , splitShardShardToSplit = shardShardId shard
    , splitShardStreamName = stream
    }
  return ()
performReshardingAction MergeShardsAction = do
  stream ← kinesisStreamName
  openShards ← fetchOpenShards
  case take 2 $ shardShardId <$> openShards of
    [s,s'] → do
      MergeShardsResponse ← runKinesis MergeShards
        { mergeShardsShardToMerge = s
        , mergeShardsAdjacentShardToMerge = s'
        , mergeShardsStreamName = stream
        }
      return ()
    _ → return ()
