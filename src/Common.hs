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
  let cleanPayload = replaceSeq "\n" "" (replaceSeq "\"" "\\\"" payload) in
    "{\"channel\": \"" ++ channel ++ "\", \"text\": \"" ++ cleanPayload ++ "\"}"
