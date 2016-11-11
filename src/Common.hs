{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Common
    ( SlackMessage(..)

    , slackPayloadWithChannel
    ) where

import ClassyPrelude
import Data.Aeson


data SlackMessage = SlackMessage
  { channel :: Text
  , message :: Text
  } deriving (Eq, Show)

instance ToJSON SlackMessage where
  toJSON sm = object [
    "channel" .= channel sm,
    "text" .= message sm ]

slackPayloadWithChannel :: Text -> Text -> Text
slackPayloadWithChannel channel payload =
  decodeUtf8 $ toStrict $ encode $ SlackMessage channel payload
