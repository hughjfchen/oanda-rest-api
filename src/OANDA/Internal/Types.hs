-- | Defines types used in the REST API

module OANDA.Internal.Types
  ( OandaEnv
  , apiType
  , accessToken
  , practiceAuth
  , liveAuth
  , APIType (..)
  , AccessToken (..)
  , AccountID (..)
  , InstrumentText
  , InstrumentName (..)
  , AccountUnits (..)
  , Currency (..)
  ) where

import qualified Data.ByteString as BS
import OANDA.Internal.Import

-- | Wraps an `APIType` and an `AccessToken`. Mainly just a convenience wrapper
-- to make functions have fewer arguments. To instantiate this type, use the
-- `practiceAuth` or `liveAuth` functions.
data OandaEnv = OandaEnv
  { apiType     :: APIType
  , accessToken :: AccessToken
  } deriving (Show)

-- | Use the practice API.
practiceAuth :: AccessToken -> OandaEnv
practiceAuth = OandaEnv Practice

-- | Use the live API.
liveAuth :: AccessToken -> OandaEnv
liveAuth = OandaEnv Live

-- | The three endpoint types used in the REST API. See the following link for
-- details: <http://developer.oanda.com/rest-live/development-guide/>
data APIType
  = Practice
  | Live
  deriving (Show)

-- | The token given by OANDA used to access the API
newtype AccessToken = AccessToken { unAccessToken :: BS.ByteString }
  deriving (Show)

-- | Integer representing the Account ID of an account
newtype AccountID = AccountID { unAccountID :: String }
  deriving (Show, FromJSON, ToJSON)

type InstrumentText = Text

newtype InstrumentName = InstrumentName { unInstrumentName :: Text }
  deriving (Show, FromJSON, ToJSON, IsString)

newtype AccountUnits = AccountUnits { unAccountUnits :: Text }
  deriving (Show, FromJSON, ToJSON, IsString)

newtype Currency = Currency { unCurrency :: Text }
  deriving (Show, FromJSON, ToJSON, IsString)
