{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Kansha
    ( kanshaEmitter
    ) where

import Common

import ClassyPrelude

kanshaEmitter :: SlackMessage -> IO Text
kanshaEmitter msg = return $ slackPayloadWithChannel (channel msg) "がんじゃ"
