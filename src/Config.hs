{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Config
  ( BotConfig,
    ParseException,

    getBotConfig,
    brokerAddr,
    consumerTopic,
    producerTopic,
    rinkPath
  ) where


import ClassyPrelude
import GHC.Generics
import Data.Yaml
import System.FilePath

data BotConfig = BotConfig
  { brokerAddr :: Text
  , consumerTopic :: Text
  , producerTopic :: Text
  , rinkPath :: Text
  } deriving (Generic, Eq, Show)

instance FromJSON BotConfig


getBotConfig :: FilePath -> IO (Either ParseException BotConfig)
getBotConfig = decodeFileEither
