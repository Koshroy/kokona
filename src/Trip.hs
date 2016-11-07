{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Trip
  (
  ) where

import ClassyPrelude
import Text.Parsec hiding ((<|>))

data Transportation = Driving | Walking | Biking deriving (Eq, Show)

data Trip = Trip
  { source :: Text
  , destination :: Text
  , method :: Transportation
  } deriving (Eq, Show)

fromStringMatch :: Parsec Text () Text
fromStringMatch = pack <$> string "from"

toStringMatch :: Parsec Text () Text
toStringMatch = pack <$> string "to"

comma :: Parsec Text () Char
comma = char ','

word :: Parsec Text () Text
word = (pack . asString) <$> many1 (letter <|> comma)

number :: Parsec Text () Text
number = pack <$> many1 digit

address :: Parsec Text () [Text]
address = many1 (number <|> word)

tripDesc :: Parsec Text () Trip
tripDesc = buildTrip <$> address <*> toStringMatch <*> address

buildTrip :: [Text] -> Text -> [Text] -> Trip
buildTrip src _ dest = Trip
  { source = (unwords src), destination = (unwords dest), method = Driving }
