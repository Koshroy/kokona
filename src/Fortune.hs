{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Fortune
    ( fortuneThread
    ) where

import Common

import ClassyPrelude
import System.Command

fortuneThread :: TChan SlackMessage -> TChan Text -> IO ()
fortuneThread cmdQueue outQueue = do
  cmd <- atomically $ readTChan cmdQueue
  payload <- fortuneEmitter cmd
  atomically $ writeTChan outQueue payload
  fortuneThread cmdQueue outQueue


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
