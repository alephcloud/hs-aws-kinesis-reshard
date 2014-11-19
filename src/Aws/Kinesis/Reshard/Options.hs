-- Copyright (c) 2013-2014 PivotCloud, Inc.
--
-- Aws.Kinesis.Reshard.Options
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

{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UnicodeSyntax #-}

module Aws.Kinesis.Reshard.Options where

import qualified Data.Text as T
import Options.Applicative
import Control.Applicative.Unicode
import Control.Lens
import Data.Monoid.Unicode
import Prelude.Unicode

data Options
  = Options
  { _oAccessKey ∷ T.Text
  , _oSecretAccessKey ∷ T.Text
  , _oRegion ∷ T.Text
  , _oStreamName ∷ T.Text
  , _oSampleDuration ∷ Int
  , _oShardCapacityThreshold ∷ Double
  } deriving Show

makeLenses ''Options

accessKeyParser ∷ Parser T.Text
accessKeyParser =
  fmap T.pack ∘ option str $
    long "access-key"
      ⊕ metavar "AK"
      ⊕ help "Your AWS access key"

secretAccessKeyParser ∷ Parser T.Text
secretAccessKeyParser =
  fmap T.pack ∘ option str $
    long "secret-access-key"
      ⊕ metavar "SK"
      ⊕ help "Your AWS secret access key"

regionParser ∷ Parser T.Text
regionParser =
  fmap T.pack ∘ option str $
    long "region"
      ⊕ short 'r'
      ⊕ metavar "R"
      ⊕ help "The AWS region"
      ⊕ value "us-west-2"
      ⊕ showDefault

streamNameParser ∷ Parser T.Text
streamNameParser =
  fmap T.pack ∘ option str $
    long "stream-name"
      ⊕ short 's'
      ⊕ metavar "SN"
      ⊕ help "The Kinesis stream name"

sampleDurationParser ∷ Parser Int
sampleDurationParser =
  option auto $
    long "sample-duration"
      ⊕ short 'd'
      ⊕ metavar "SD"
      ⊕ help "The sample duration in seconds"
      ⊕ value (60 * 60)
      ⊕ showDefault

capacityThresholdReader ∷ ReadM Double
capacityThresholdReader = do
  cap ← auto
  if | cap > 0 ∧ cap <= 1 → return cap
     | otherwise → readerError "Capacity threshold must be in range [0,1)"

capacityThresholdParser ∷ Parser Double
capacityThresholdParser =
  option capacityThresholdReader $
    long "shard-capacity-threshold"
      ⊕ short 't'
      ⊕ metavar "SCT"
      ⊕ help "The threshold percent capacity per shard (max: 1)"
      ⊕ value 0.1
      ⊕ showDefault

optionsParser ∷ Parser Options
optionsParser =
  pure Options
    ⊛ accessKeyParser
    ⊛ secretAccessKeyParser
    ⊛ regionParser
    ⊛ streamNameParser
    ⊛ sampleDurationParser
    ⊛ capacityThresholdParser

parserInfo ∷ ParserInfo Options
parserInfo =
  info (helper ⊛ optionsParser) $
    fullDesc
    ⊕ progDesc "Monitor Kinesis throughput and reshard accordingly"
    ⊕ header "The Kinesis Resharder CLI"

