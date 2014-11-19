-- Copyright (c) 2013-2014 PivotCloud, Inc.
--
-- Aws.Kinesis.Reshard.Exception
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

{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UnicodeSyntax #-}

module Aws.Kinesis.Reshard.Exception
( InvalidRegionException(InvalidRegionException)
, _InvalidRegionException
, ireProposedRegion
, ireParsingError

, InvalidStreamNameException(InvalidStreamNameException)
, _InvalidStreamNameException
, isnProposedStreamName
, isnParsingError
) where

import Control.Exception.Lifted
import Control.Lens
import qualified Data.Text as T
import Data.Typeable

data InvalidRegionException
  = InvalidRegionException
  { _ireProposedRegion ∷ T.Text
  , _ireParsingError ∷ T.Text
  } deriving (Eq, Typeable, Show)

instance Exception InvalidRegionException

makeLenses ''InvalidRegionException
makePrisms ''InvalidRegionException

data InvalidStreamNameException
  = InvalidStreamNameException
  { _isnProposedStreamName ∷ T.Text
  , _isnParsingError ∷ T.Text
  } deriving (Eq, Typeable, Show)

instance Exception InvalidStreamNameException

makeLenses ''InvalidStreamNameException
makePrisms ''InvalidStreamNameException

