{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Common
    ( SlackMessage(..)

    , slackPayloadWithChannel
    ) where

import ClassyPrelude

data SlackMessage = SlackMessage
  { channel :: Text
  , message :: Text
  } deriving (Eq, Show)

slackPayloadWithChannel :: Text -> Text -> Text
slackPayloadWithChannel channel payload =
  "{\"channel\": \"" ++ channel ++ "\", \"text\": \"" ++ payload ++ "\"}"
