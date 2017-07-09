module Guide.State where

import Prelude

import Data.Generic (class Generic, gShow)
import Data.Newtype (class Newtype)
import Guide.Config (config)
import Guide.Routes (Route, match)
import Guide.Types (CGrandCategories, Users)
import Network.RemoteData (RemoteData(..))

newtype State = State
  { title :: String
  , hello :: String
  , route :: Route
  , loaded :: Boolean
  , errors :: Array String
  , users :: RemoteData String Users
  , grandCategories :: RemoteData String CGrandCategories
  , countHomeRoute :: Int
  , countPGRoute :: Int
  }

derive instance gState :: Generic State
derive instance newtypeState :: Newtype State _
instance showState :: Show State where
  show = gShow

init :: String -> State
init url = State
  { title: config.title
  , hello: "world"
  , route: match url
  , loaded: false
  , errors: []
  , grandCategories: NotAsked
  -- playground
  , users: NotAsked
  , countHomeRoute: 0
  , countPGRoute: 0
  }
