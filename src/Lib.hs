{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Lib
    ( someFunc,

      module ClassyPrelude,
      module Haskakafka
    ) where

import Control.Lens
import Data.Aeson
import Data.Aeson.Lens
import GHC.IO.Handle hiding (hGetLine)
import System.Command
import System.IO (hReady)

import ClassyPrelude
import Haskakafka

data SlackMessage = SlackMessage
  { channel :: Text
  , message :: Text
  } deriving (Eq, Show)


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


processCommandQueue :: Text -> TChan Text -> TChan SlackMessage -> STM Text
processCommandQueue command inQueue outQueue = do
  slackText <- readTChan inQueue
  let payloadType = slackText ^? key "event" . key "type" . _String
  case payloadType of
    Nothing -> return slackText
    Just typeStr -> case typeStr == "message" of
                      False -> return slackText
                      True -> let payloadTextM = slackText ^? key "event" . key "text" . _String
                                  payloadChannelM = slackText ^? key "event" . key "channel" . _String in
                                case slackText ^? key "event" . key "text" . _String of
                                  Nothing -> return slackText
                                  Just payloadText ->
                                    let payloadTextWords = words payloadText in
                                      case (headMay payloadTextWords) of
                                        Nothing -> return $ tshow payloadText
                                        Just commandWord ->
                                          case commandWord == command of
                                            False -> return $ tshow payloadText
                                            True -> do
                                              case payloadChannelM of
                                                Nothing ->
                                                  writeTChan
                                                  outQueue
                                                  SlackMessage {channel = "", message = payloadText}
                                                Just channelName -> 
                                                  writeTChan
                                                  outQueue
                                                  SlackMessage {channel = channelName, message = payloadText}
                                              return $ tshow payloadText


producer :: TChan Text -> Kafka -> KafkaTopic -> IO ()
producer queue kafka topic = do
  msg <- atomically $ readTChan queue
  putStrLn $ "producer: " ++ msg
  -- let ex = "{\"channel\": \"#chatter-technical\", \"text\": \"Hollo!\"}"
  produceMessage topic KafkaUnassignedPartition (KafkaProduceMessage $ encodeUtf8 msg)
  -- produceMessage topic KafkaUnassignedPartition (KafkaProduceMessage $ encodeUtf8 ex)
  producer queue kafka topic


-- channelEmitter :: TChan Text -> TChan Text -> STM ()
-- channelEmitter inQueue outQueue = do
--   payload <- readTChan


echoEmitter :: TChan SlackMessage -> TChan Text -> STM ()
echoEmitter inQueue outQueue = do
  msg <- readTChan inQueue
  writeTChan outQueue $ "{\"channel\": \"" ++ (channel msg) ++ "\", \"text\": \"Hollo!\"}"


kafkaProducerThread :: Text -> Text -> TChan Text -> IO ()
kafkaProducerThread brokerString topicName producerQueue = do
  withKafkaProducer [] [] (unpack brokerString) (unpack topicName) (producer producerQueue)
  return ()

kafkaConsumerThread :: Text -> Text -> TChan Text -> IO ()
kafkaConsumerThread brokerString topicName consumerQueue = do
  withKafkaConsumer [] [("offset.store.method", "file")] (unpack brokerString) (unpack topicName) 0 (KafkaOffsetStored) (consumer consumerQueue)
  return ()


processorThread :: Text -> TChan Text -> TChan SlackMessage -> IO ()
processorThread command inQueue outQueue = do
  r <- atomically $ processCommandQueue command inQueue outQueue
  processorThread command inQueue outQueue


emitterThread :: (TChan SlackMessage -> TChan Text -> STM ()) -> TChan SlackMessage -> TChan Text -> IO ()
emitterThread emitter inQueue outQueue = do
  atomically $ emitter inQueue outQueue
  emitterThread emitter inQueue outQueue


slackPayloadWithChannel :: Text -> Text -> Text
slackPayloadWithChannel channel payload =
  "{\"channel\": \"" ++ channel ++ "\", \"text\": \"" ++ payload ++ "\"}"


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


someFunc :: IO ()
someFunc = do
  putStrLn "Starting Kokona"
  consumerQueue <- newTChanIO
  producerQueue <- newTChanIO
  processorQueue <- newTChanIO

  rinkQueue <- newTChanIO
  consumerQueue1 <- atomically $ dupTChan consumerQueue  

  let brokerString = "10.244.0.10:9092"
  let consumerTopicString = "papika_from_slack"
  let producerTopicString = "papika_to_slack"

--  consumerTId <- fork (kafkaConsumerThread brokerString consumerTopicString consumerQueue)
  processorTId <- fork (processorThread "!hollo" consumerQueue processorQueue)
  processorTId1 <- fork (processorThread "!calc" consumerQueue1 rinkQueue)
  emitterTId <- fork (emitterThread echoEmitter processorQueue producerQueue)
  producerTId <- fork (kafkaProducerThread brokerString producerTopicString producerQueue)
  rinkTId <- fork (
    rinkThread "/home/torifuda/src/rink-rs/target/release/rink" rinkQueue producerQueue
    )

  kafkaConsumerThread brokerString consumerTopicString consumerQueue
--  putStrLn "starting b"
--  kafkaProducerThread brokerString producerTopicString consumerQueue

--  putStrLn $ tshow consumerTId
--  putStrLn $ tshow processorTId
--  putStrLn $ tshow emitterTId
  putStrLn $ tshow producerTId
