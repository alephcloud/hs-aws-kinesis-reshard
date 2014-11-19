-- Copyright (c) 2013-2014 PivotCloud, Inc.
--
-- Aws.Kinesis.Reshard.Common
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
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE UnicodeSyntax #-}

module Aws.Kinesis.Reshard.Common
( kinesisStreamName
, runKinesis
) where

import Aws
import Aws.General
import Aws.Kinesis
import Aws.Kinesis.Reshard.Monad

import Control.Applicative
import Control.Exception.Lifted
import Control.Lens
import Control.Monad.Error.Hoist
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import Prelude.Unicode

awsCredentials
  ∷ MonadReshard m
  ⇒ m Credentials
awsCredentials = do
  accessKey ← view $ oAccessKey ∘ to T.encodeUtf8
  secretKey ← view $ oSecretAccessKey ∘ to T.encodeUtf8
  makeCredentials
    accessKey
    secretKey

awsConfiguration
  ∷ MonadReshard m
  ⇒ m Configuration
awsConfiguration = do
  cred ← awsCredentials
  return Configuration
    { timeInfo = Timestamp
    , credentials = cred
    , logger = defaultLog Warning
    }

awsRegion
  ∷ MonadReshard m
  ⇒ m Region
awsRegion = do
  r ← view oRegion
  fromText r <%?>
    SomeException ∘ InvalidRegionException r ∘ T.pack

kinesisConfiguration
  ∷ MonadReshard m
  ⇒ m (KinesisConfiguration NormalQuery)
kinesisConfiguration =
  KinesisConfiguration
    <$> awsRegion

kinesisStreamName
  ∷ MonadReshard m
  ⇒ m StreamName
kinesisStreamName = do
  sn ← view oStreamName
  streamName sn <%?>
    SomeException ∘ InvalidStreamNameException sn

runKinesis
  ∷ ( MonadReshard m
    , Transaction r α
    , ServiceConfiguration r ~ KinesisConfiguration
    , AsMemoryResponse α
    )
  ⇒ r
  → m (MemoryResponse α)
runKinesis request = do
  cfg ← awsConfiguration
  kinCfg ← kinesisConfiguration
  simpleAws cfg kinCfg request
