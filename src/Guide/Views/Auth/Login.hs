-- {-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}

module Guide.Views.Auth.Login where

import Imports hiding ((&))

import Lucid hiding (for_)

import Lens.Micro.Platform ((&))

import Guide.Views.Page

import Guide.Config
import Guide.State
-- import Guide.Types
import Guide.Utils
import Guide.JS (JS(..), JQuerySelector)
import qualified Guide.JS as JS
import Guide.Markdown
import Guide.Cache

loginContent :: (MonadIO m, MonadReader Config m) => HtmlT m ()
loginContent = do
  div_ ""

renderLogin :: (MonadIO m, MonadReader Config m) => HtmlT m ()
renderLogin = do
  renderPage $ 
    pageDef & title .~ "Aelve Guide"
            & name .~ Just "Login"
            & content .~ loginContent