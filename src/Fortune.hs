{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Fortune
    ( fortuneEmitter
    ) where

import Common

import ClassyPrelude
import System.Command


fortuneEmitter :: SlackMessage -> IO Text
fortuneEmitter cmd = do
  (_, hOutM, _, p) <- createProcess (shell "fortune") { std_out = CreatePipe }
  case hOutM of
    Nothing -> do
      waitForProcess p
      return ""
    Just hOut -> do
      fortune <- hGetContents hOut
      let payload = slackPayloadWithChannel (channel cmd) fortune
      hClose hOut
      waitForProcess p
      return payload
