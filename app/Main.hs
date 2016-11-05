{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Lib

getConfigArg :: IO (Maybe FilePath)
getConfigArg = do
  args <- getArgs
  return $ unpack <$> headMay args
  

main :: IO ()
main = do
  cfgPathM <- getConfigArg
  case cfgPathM of
    Nothing ->
      hPutStrLn stderr
      (asText "Error: no config file found\nUsage: kokona <config-path>")
    Just cfgPath ->
      mainFunc cfgPath
