{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Trip
  (
    tripBodyParser,
    tripVerbParser,
    tripGerundParser,
    Trip
  ) where

import ClassyPrelude
import Data.List (insert)
import Text.Parsec hiding ((<|>), many, optional, try)
import qualified Text.Parsec as TP (try)

data Transportation = Driving | Walking | Biking deriving (Eq, Show)

data Trip = Trip
  { addresses :: [Text]
  , method :: Transportation
  } deriving (Eq, Show)

fromStringMatch :: Parsec Text () Text
fromStringMatch = pack <$> string "<"

toStringMatch :: Parsec Text () Text
toStringMatch = pack <$> string "to"

byStringMatch :: Parsec Text () Text
byStringMatch = pack <$> string "@"

verbTransport :: Parsec Text () Text
verbTransport = pack <$>
  ((TP.try (string "drive")) <|> (TP.try (string "walk")) <|> (string "bike"))

gerundTransport :: Parsec Text () Text
gerundTransport = pack <$>
  ((TP.try (string "driving")) <|> (TP.try (string "walking")) <|> (string "biking"))

fromVerbText :: Text -> Transportation
fromVerbText t = case t of
  "drive" -> Driving
  "walk" -> Walking
  "bike" -> Biking
  _ -> Driving

fromNounText :: Text -> Transportation
fromNounText t = case t of
  "driving" -> Driving
  "walking" -> Walking
  "biking" -> Biking
  _ -> Driving

comma :: Parsec Text () Char
comma = char ','

commaText :: Parsec Text () Text
commaText = (pack . pure) <$> comma

number :: Parsec Text () Text
number = pack <$> many1 digit

name :: Parsec Text () Text
name = pack <$> (mappend <$> (many digit) <*> (many1 letter) <* (optional commaText))

seperator :: Parsec Text () Text
seperator = pack <$> string "| "

addressUnit :: Parsec Text () Text
addressUnit = (TP.try name) <|> number

address :: Parsec Text () Text
address = unwords <$> (sepEndBy addressUnit space)

tripBodyParser :: Parsec Text () [Text]
tripBodyParser = sepEndBy address seperator

tripVerbParser :: Parsec Text () Trip
tripVerbParser = buildTrip <$>
  (fromVerbText <$> verbTransport <* spaces) <*> ((fromStringMatch <* spaces) *> tripBodyParser)

tripGerundParser :: Parsec Text () Trip
tripGerundParser = (flip buildTrip) <$>
  tripBodyParser <*> (fromNounText <$> ((byStringMatch <* spaces) *> gerundTransport))

buildTrip :: Transportation -> [Text] -> Trip
buildTrip transportation manyAddrs = Trip
  { addresses = manyAddrs, method = transportation }
