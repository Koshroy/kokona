{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    ( mainFunc,

      module ClassyPrelude,
      module Haskakafka
    ) where

import Common
import Config
import Fortune
import Kansha
import Threading

import Control.Lens
import Data.Aeson
import Data.Aeson.Lens
import GHC.IO.Handle hiding (hGetLine)
import System.Command
import System.IO (hReady)

import ClassyPrelude
import Haskakafka



startRink :: Text -> IO (Maybe (Handle, Handle))
startRink rinkPath = do
  let rinkCmd = rinkPath ++ " -"
  (hInM, hOutM, _, _) <- createProcess (shell $ unpack rinkCmd)
    { std_out = CreatePipe, std_in = CreatePipe }
  return $ do
    hIn <- hInM
    hOut <- hOutM
    return (hIn, hOut)


readHandleUntilNotReady :: Handle -> IO Text
readHandleUntilNotReady hIn =
  let readOutput handle results = do
        handleReady <- hReady handle
        case handleReady of
          False -> return (unlines results)
          True -> do
            line <- hGetLine handle
            readOutput handle (mappend results [line])
  in
    readOutput hIn []


runRinkCmd :: (Handle, Handle) -> Text -> IO Text
runRinkCmd (hIn, hOut) cmdStr = do
  let newCmdStr = ((replaceSeqStrictText "&gt;" ">") . (replaceSeqStrictText "&lt;" "<")) cmdStr
  hPutStrLn hIn newCmdStr
  hFlush hIn
  --readHandleUntilNotReady hOut
  hGetLine hOut


rinkCmdLooper :: (Handle, Handle) -> TChan SlackMessage -> TChan Text -> IO ()
rinkCmdLooper (hIn, hOut) cmdQueue outQueue = do
  cmd <- atomically $ readTChan cmdQueue
  let rawInput = message cmd
  case (tailMay $ words rawInput) of
    Nothing -> rinkCmdLooper (hIn, hOut) cmdQueue outQueue
    Just others -> do
      output <- runRinkCmd (hIn, hOut) (unwords others)
      let outputStripped = stripSuffix "\n" output
      case outputStripped of
        Nothing -> atomically $ writeTChan outQueue $ slackPayloadWithChannel (channel cmd) output
        Just stripped -> atomically $ writeTChan outQueue $ slackPayloadWithChannel (channel cmd) stripped
      rinkCmdLooper (hIn, hOut) cmdQueue outQueue


consumer :: TChan Text -> Kafka -> KafkaTopic -> IO ()
consumer queue kafka topic = do
  messageE <- consumeMessage topic 0 10000
  case messageE of
    Left (KafkaResponseError _) -> return ()
    Left err -> do
      putStrLn $ "Kafka error: " ++ tshow err
    Right msg -> do
      let writeQueue = writeTChan queue
      atomically $ (writeQueue . asText . decodeUtf8 . asByteString . messagePayload) msg
  consumer queue kafka topic


producer :: TChan Text -> Kafka -> KafkaTopic -> IO ()
producer queue kafka topic = do
  msg <- atomically $ readTChan queue
  putStrLn $ "producer: " ++ msg
  produceMessage topic KafkaUnassignedPartition (KafkaProduceMessage $ encodeUtf8 msg)
  producer queue kafka topic


echoEmitter :: SlackMessage -> IO Text
echoEmitter msg = do
  return $ slackPayloadWithChannel (channel msg) "Hollo!"

papikaEmitter :: SlackMessage -> IO Text
papikaEmitter msg = return $ slackPayloadWithChannel (channel msg) "Cocona!"

kafkaProducerThread :: Text -> Text -> TChan Text -> IO ()
kafkaProducerThread brokerString topicName producerQueue = do
  withKafkaProducer [] [] (unpack brokerString) (unpack topicName) (producer producerQueue)
  return ()


kafkaConsumerThread :: Text -> Text -> TChan Text -> IO ()
kafkaConsumerThread brokerString topicName consumerQueue = do
  withKafkaConsumer [] [("offset.store.method", "file")] (unpack brokerString) (unpack topicName) 0 (KafkaOffsetStored) (consumer consumerQueue)
  return ()


emitterThread :: (TChan SlackMessage -> TChan Text -> STM ()) -> TChan SlackMessage -> TChan Text -> IO ()
emitterThread emitter inQueue outQueue = do
  atomically $ emitter inQueue outQueue
  emitterThread emitter inQueue outQueue


rinkThread :: Text -> TChan SlackMessage -> TChan Text -> IO ()
rinkThread rinkPath inputQueue outputQueue = do
  handlesM <- startRink rinkPath
  case handlesM of
    Nothing -> do
      putStrLn "Error opening up rink"
      return ()
    Just (hIn, hOut) -> do
      hSetBinaryMode hIn False
      hSetBinaryMode hOut False
      rinkCmdLooper (hIn, hOut) inputQueue outputQueue


mainFunc :: FilePath -> IO ()
mainFunc configPath = do
  botConfigE <- getBotConfig configPath
  case botConfigE of
    Left err -> do
      hPutStrLn stderr $ asText "Could not parse config, using defaults"
      hPutStrLn stderr $ tshow err
    Right _ -> return ()
    
  putStrLn "Starting Kokona"
  consumerQueue <- newTChanIO
  producerQueue <- newTChanIO

  let (brokerString, consumerTopicString, producerTopicString, rinkPathStr) =
        case botConfigE of
          Left _ -> ("localhost:9092", "consumer", "producer", "rink")
          Right cfg -> (
            (brokerAddr cfg), (consumerTopic cfg), (producerTopic cfg), (rinkPath cfg)
            )

  let holloAcceptor = startMessageAcceptor "!hollo"
  let calcAcceptor = startMessageAcceptor "!calc"
  let dhggsAcceptor  = startMessageAcceptor "dhggs"
  let fortuneAcceptor = startMessageAcceptor "!fortune"
  let papikaAcceptor = textInMessageAcceptor "papika"

  let cmdThreadWithQueue = botCommandThread consumerQueue producerQueue

  cmdThreadWithQueue holloAcceptor (loopProcessor echoEmitter)
  cmdThreadWithQueue calcAcceptor (rinkThread rinkPathStr)
  cmdThreadWithQueue dhggsAcceptor (loopProcessor kanshaEmitter)
  cmdThreadWithQueue fortuneAcceptor (loopProcessor fortuneEmitter)
--  cmdThreadWithQueue papikaAcceptor (loopProcessor papikaEmitter)
  
  
  producerTId <- fork (kafkaProducerThread brokerString producerTopicString producerQueue)

  kafkaConsumerThread brokerString consumerTopicString consumerQueue
  putStrLn $ tshow producerTId
