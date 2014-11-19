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
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UnicodeSyntax #-}

module Aws.Kinesis.Reshard.Shards
( fetchOpenShards
) where

import Aws
import Aws.Core
import Aws.General
import Aws.Kinesis
import Aws.Kinesis.Reshard.Common
import Aws.Kinesis.Reshard.Exception
import Aws.Kinesis.Reshard.Monad
import Aws.Kinesis.Reshard.Options

import Control.Applicative
import Control.Applicative.Unicode
import Control.Exception.Lifted
import Control.Lens
import Control.Monad.Error.Hoist
import Control.Monad.Trans

import Data.Maybe
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import Data.Typeable
import Data.Conduit
import qualified Data.Conduit.List as CL
import Prelude.Unicode

fetchShardsConduit
  ∷ MonadReshard m
  ⇒ Conduit (Maybe ShardId) m Shard
fetchShardsConduit = do
  streamName ← lift kinesisStreamName
  awaitForever $ \mshardId → do
    let req = DescribeStream
          { describeStreamExclusiveStartShardId = mshardId
          , describeStreamLimit = Nothing
          , describeStreamStreamName = streamName
          }
    resp@(DescribeStreamResponse StreamDescription{..}) ←
      lift $ runKinesis req
    yield `mapM_` streamDescriptionShards
    _ ← traverse (leftover ∘ Just) $
      describeStreamExclusiveStartShardId =<<
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

fetchOpenShards
  ∷ MonadReshard m
  ⇒ m [Shard]
fetchOpenShards =
  shardsSource
    $= CL.filter shardIsOpen
    $$ CL.consume