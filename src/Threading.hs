{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}

module Threading
    ( acceptorThread
    , botCommandThread
    , processCommandQueue
    , loopProcessor
    ) where

import Common

import ClassyPrelude

import Control.Lens
import Data.Aeson
import Data.Aeson.Lens


processCommandQueue :: MessageAcceptor -> TChan Text -> TChan SlackMessage -> STM Text
processCommandQueue acceptor inQueue outQueue = do
  slackText <- readTChan inQueue
  let payloadType = slackText ^? key "event" . key "type" . _String
  case payloadType of
    Nothing -> return slackText
    Just typeStr -> case typeStr == "message" of
                      False -> return slackText
                      True -> let payloadTextM = slackText ^? key "event" . key "text" . _String
                                  payloadChannelM = slackText ^? key "event" . key "channel" . _String in
                                case payloadTextM of
                                  Nothing -> return slackText
                                  Just payloadText ->
                                    do
                                      case (acceptor payloadText) of
                                        False -> do
                                          return ()
                                        True ->
                                          case payloadChannelM of
                                            Nothing -> do
                                              return ()
                                            Just channelName -> do
                                              writeTChan outQueue $ SlackMessage {channel = channelName, message = payloadText}
                                      return payloadText

                                      
acceptorThread :: MessageAcceptor -> TChan Text -> TChan SlackMessage -> IO ()
acceptorThread acceptor inQueue outQueue = do
  r <- atomically $ processCommandQueue acceptor inQueue outQueue
  acceptorThread acceptor inQueue outQueue


loopProcessor :: MonadIO m =>
  (SlackMessage -> m Text) -> TChan SlackMessage -> TChan Text -> m ()
loopProcessor processor msgChan outChan = do
  msg <- liftIO $ atomically $ readTChan msgChan
  procMsg <- processor msg
  liftIO $ atomically $ writeTChan outChan procMsg
  loopProcessor processor msgChan outChan


botCommandThread :: (MonadIO m, MonadBaseControl IO m) =>
  TChan Text ->
  TChan Text ->
  MessageAcceptor ->
  (TChan SlackMessage -> TChan Text -> m ()) ->
  m ()
botCommandThread consumerChan producerChan acceptor processor = do
  consumerChanDup <- liftIO $ atomically $ dupTChan consumerChan
  acceptorChan <- liftIO newTChanIO
  processorChan <- liftIO newTChanIO
  fork $ liftIO $ acceptorThread acceptor consumerChanDup acceptorChan
  fork $ processor acceptorChan producerChan
  return ()
  --msg <- liftIO $ atomically $ readTChan inChan

-- acceptorThread ::
--   MonadIO m => MessageAcceptor -> (Text -> m SlackMessage) -> (TChan Text -> TChan SlackMessage -> m ())
-- acceptorThread acceptor processorFunc = do
--   atomically # processorFunc
