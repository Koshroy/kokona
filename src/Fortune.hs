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
  (_, hOutM, _, p) <- createProcess (shell "fortune") { std_out = CreatePipe }
  case hOutM of
    Nothing -> return ()
    Just hOut -> do
      fortune <- hGetContents hOut
      atomically
              (writeTChan outQueue
               (slackPayloadWithChannel (channel cmd) fortune))
      hClose hOut
  waitForProcess p
  return ()
