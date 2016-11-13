{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Common
    ( SlackMessage(..)
    , MessageAcceptor

    , slackPayloadWithChannel
    , startMessageAcceptor
    , textInMessageAcceptor
    ) where

import ClassyPrelude
import Data.Aeson

type MessageAcceptor = Text -> Bool


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


startMessageAcceptorGenerator :: Text -> Text -> Bool
startMessageAcceptorGenerator start message =
  let messageWords = words message in
    case (headMay messageWords) of
      Nothing -> False
      Just firstWord -> firstWord == start


startMessageAcceptor :: Text -> MessageAcceptor
startMessageAcceptor start =
  startMessageAcceptorGenerator start


textInMessageAcceptorGenerator :: Text -> Text -> Bool
textInMessageAcceptorGenerator needle message =
  isInfixOf needle (toLower message)


textInMessageAcceptor :: Text -> MessageAcceptor
textInMessageAcceptor needle =
  textInMessageAcceptorGenerator needle
