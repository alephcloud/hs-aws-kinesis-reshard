-- Copyright (c) 2013-2014 PivotCloud, Inc.
--
-- Aws.Kinesis.Reshard.Metrics
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
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE UnicodeSyntax #-}

module Aws.Kinesis.Reshard.Metrics
( getBytesPerSecond
) where

import AWS
import AWS.CloudWatch
import AWS.CloudWatch.Types

import Aws.Kinesis.Reshard.Options
import Aws.Kinesis.Reshard.Monad

import Control.Applicative
import Control.Applicative.Unicode
import Control.Concurrent.Async.Lifted
import Control.Lens
import Control.Monad.Trans
import Control.Monad.Unicode
import qualified Data.Text.Encoding as T
import Data.Time
import Prelude.Unicode

getCredential
  ∷ MonadReshard m
  ⇒ m Credential
getCredential =
  pure newCredential
    ⊛ view (oAccessKey ∘ to T.encodeUtf8)
    ⊛ view (oSecretAccessKey ∘ to T.encodeUtf8)

dimensionFilters
  ∷ MonadReshard m
  ⇒ m [DimensionFilter]
dimensionFilters =
  (:[]) ∘ ("StreamName",)
    <$> view oStreamName

getBytesPerSecond
  ∷ MonadReshard m
  ⇒ m Double
getBytesPerSecond = do
  cred ← getCredential
  filters ← dimensionFilters
  duration ← view oSampleDuration

  runCloudWatch cred $ do
    setRegion =≪ lift (view oRegion)
    endTime ← liftIO getCurrentTime

    let startTime = addUTCTime (fromInteger $ -duration) endTime

    let getMetrics metric = do
          (datapoints, _) ← getMetricStatistics
            filters
            startTime
            endTime
            metric
            "AWS/Kinesis"
            (fromIntegral duration)
            [StatisticSum]
            Nothing
          return $ foldr (\Datapoint{..} n → maybe n (+ n) datapointSum) 0 datapoints


    totalBytes ← runConcurrently $
      pure (+)
        ⊛ Concurrently (getMetrics "PutRecord.Bytes")
        ⊛ Concurrently (getMetrics "PutRecords.Bytes")

    return $ totalBytes / fromIntegral duration
