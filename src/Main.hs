-- Copyright (c) 2013-2014 PivotCloud, Inc.
--
-- Main
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
{-# LANGUAGE UnicodeSyntax #-}

module Main where

import Aws.Kinesis.Reshard.Analysis
import Aws.Kinesis.Reshard.Monad
import Aws.Kinesis.Reshard.Shards

import Control.Concurrent.Lifted
import Control.Lens
import Control.Monad.Trans.Either
import Control.Monad.Trans.Reader (runReaderT)
import Control.Monad.Trans.Resource
import Control.Monad.Unicode
import Data.Traversable
import qualified Options.Applicative as OA
import Prelude.Unicode

loop
  ∷ MonadReshard m
  ⇒ m ()
loop = do
  recommendation ← analyzeStream
  liftIO ∘ putStrLn $
    case recommendation of
      Nothing → "No resharding action recommended at this time"
      Just rsa → "Will perform resharding action: " ++ show rsa
  _ ← for recommendation performReshardingAction
  threadDelay =≪ view oReshardingInterval
  loop

main ∷ IO ()
main =
  eitherT (fail ∘ show) return ∘ runResourceT $
    liftIO (OA.execParser parserInfo)
      ≫= runReaderT loop

