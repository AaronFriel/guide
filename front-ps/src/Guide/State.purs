module Guide.State where

import Guide.Config (config)
import Guide.Routes (Route, match)
import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Show (genericShow)
import Data.Newtype (class Newtype)
import Data.Show (class Show)

newtype State = State
  { title :: String
  , route :: Route
  , loaded :: Boolean
  , errors :: Array String
  , users :: String
  }

derive instance gState :: Generic State _
derive instance newtypeState :: Newtype State _
instance showState :: Show State where
  show = genericShow

init :: String -> State
init url = State
  { title: config.title
  , route: match url
  , loaded: false
  , errors: []
  -- playground
  , users: ""
  }
