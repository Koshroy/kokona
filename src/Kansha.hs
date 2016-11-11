{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Kansha
    ( kanshaEmitter
    ) where

import Common

import ClassyPrelude

kanshaEmitter :: TChan SlackMessage -> TChan Text -> STM ()
kanshaEmitter inQueue outQueue = do
    msg <- readTChan inQueue
    writeTChan outQueue $ slackPayloadWithChannel (channel msg) "がんじゃ"
