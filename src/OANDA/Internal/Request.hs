{-# LANGUAGE OverloadedStrings #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

-- | Internal module for dealing with requests via wreq

module OANDA.Internal.Request
  ( OANDARequest (..)
  , OANDARequestType (..)
  , makeOandaRequest
  , baseRequest
  , constructRequest
  , baseURL
  , commaList
  , jsonOpts
  , jsonResponse
  , jsonResponseArray
  , formatTimeRFC3339
  ) where

import Control.Monad.IO.Class
import qualified Data.Aeson.TH as TH
import qualified Data.ByteString as BS
import qualified Data.Map as Map

import OANDA.Internal.Import
import OANDA.Internal.Types

-- | This is the type returned by the API functions. This is meant to be used
-- with some of our request functions, depending on how safe the user wants to
-- be.
data OANDARequest a
  = OANDARequest
  { oandaRequestRequest :: Request
  , oandaRequestType :: OANDARequestType
  } deriving (Show)

data OANDARequestType
  = JsonRequest
  | JsonArrayRequest String
  deriving (Show)

-- | Simplest way to make requests, but throws exception on errors.
makeOandaRequest :: (MonadIO m, FromJSON a) => OANDARequest a -> m a
makeOandaRequest (OANDARequest request JsonRequest) = getResponseBody <$> httpJSON request
makeOandaRequest (OANDARequest request (JsonArrayRequest key)) = (Map.! key) . getResponseBody <$> httpJSON request

-- | Specifies the endpoints for each `APIType`. These are the base URLs for
-- each API call.
baseURL :: OandaEnv -> String
baseURL env = apiEndpoint (apiType env)
  where
    apiEndpoint Practice = "https://api-fxpractice.oanda.com"
    apiEndpoint Live     = "https://api-fxtrade.oanda.com"

baseRequest :: OandaEnv -> String -> String -> Request
baseRequest env requestType url =
  unsafeParseRequest (requestType ++ " " ++ baseURL env ++ url)
  & makeAuthHeader (accessToken env)
  where
    makeAuthHeader (AccessToken t) = addRequestHeader "Authorization" ("Bearer " `BS.append` t)

unsafeParseRequest :: String -> Request
unsafeParseRequest = unsafeParseRequest' . parseRequest
  where
    unsafeParseRequest' (Left err) = error $ show err
    unsafeParseRequest' (Right request) = request

-- TODO: Delete
constructRequest :: OandaEnv -> String -> [(Text, Maybe [Text])] -> IO Request
constructRequest env url params = do
  initRequest <- parseRequest url
  return $
    initRequest
    & makeAuthHeader (accessToken env)
    & setRequestQueryString params'
  where
    makeAuthHeader (AccessToken t) = addRequestHeader "Authorization" ("Bearer " `BS.append` t)
    paramToMaybe (name, Just xs') = Just (encodeUtf8 name, Just $ encodeUtf8 $ commaList xs')
    paramToMaybe (_, Nothing) = Nothing
    params' = catMaybes $ fmap paramToMaybe params

-- | Convert a Maybe [Text] item into empty text or comma-separated text.
commaList :: [Text] -> Text
commaList = intercalate ","

-- | Used to derive FromJSON instances.
jsonOpts :: String -> TH.Options
jsonOpts s = TH.defaultOptions { TH.fieldLabelModifier = firstLower . drop (length s) }
  where firstLower [] = []
        firstLower (x:xs) = toLower x : xs

-- | Boilerplate function to perform a request and extract the response body.
jsonResponse :: (FromJSON a) => Request -> IO a
jsonResponse request = getResponseBody <$> httpJSON request

-- | Boilerplate function to perform a request and extract the response body.
jsonResponseArray :: (FromJSON a) => Request -> String -> IO a
jsonResponseArray request name =
  do body <- jsonResponse request
     return $ body Map.! (name :: String)

-- | Formats time according to RFC3339 (which is the time format used by
-- OANDA). Taken from the <https://github.com/HugoDaniel/timerep timerep> library.
formatTimeRFC3339 :: ZonedTime -> String
formatTimeRFC3339 zt@(ZonedTime _ z) = formatTime defaultTimeLocale "%FT%T" zt <> printZone
  where timeZoneStr = timeZoneOffsetString z
        printZone = if timeZoneStr == timeZoneOffsetString utc
                    then "Z"
                    else take 3 timeZoneStr <> ":" <> drop 3 timeZoneStr

instance (Show a, Integral a) => ToJSON (DecimalRaw a) where
  toJSON = toJSON . show

instance (Integral a) => FromJSON (DecimalRaw a) where
  parseJSON (Number n) = readDecimalJSON n
  parseJSON (String s) = readDecimalJSON (read (unpack s))
  parseJSON _          = mempty


readDecimalJSON :: (Num i, Applicative f) => Scientific -> f (DecimalRaw i)
readDecimalJSON n = pure $ Decimal ((*) (-1) $ fromIntegral $ base10Exponent n)
                                    (fromIntegral $ coefficient n)