{-# LANGUAGE TypeFamilies, QuasiQuotes, TemplateHaskell, OverloadedStrings, MultiParamTypeClasses #-}
module Handler.Home where

import Yesod
import Yesod.Helpers.Static
import Yesod.Helpers.Sitemap
import Yesod.Helpers.AtomFeed
import Yesod.Form.Jquery
import Settings
import Text.Pandoc (readMarkdown, defaultParserState, writeHtmlString, defaultWriterOptions)
import Language.Haskell.HsColour hiding (string)
import Language.Haskell.HsColour.Colourise (defaultColourPrefs)
import qualified Language.Haskell.HsColour.CSS as CSS
import Entry
import Control.Arrow ((&&&))
import Data.List (groupBy, stripPrefix)
import Data.Maybe (fromMaybe)
import Data.Function (on)
import qualified System.IO.UTF8 as U
import Data.Time
import Book
import qualified Data.Text as T
import qualified Data.Text as TS -- FIXME remove
import Data.Text (Text)
import qualified Text.Highlighting.Kate as Kate
import Text.XHtml.Strict (showHtmlFragment)
import Data.Either (lefts)
import Control.Concurrent.AdvSTM
import Control.Concurrent.AdvSTM.TVar
import Comments
import Data.List (sortBy)
import Text.Blaze (toHtml)
import qualified Data.ByteString.Char8 as S8
import YesodDocs

getHomeR :: Handler RepHtml
getHomeR = defaultLayout $ do
    setTitle "Yesod Web Framework for Haskell"
    let faqR = ChapterR "faq"
    addHamlet $(hamletFile "root")
    addHtmlHead [$hamlet|\
<meta name="description" content="Yesod Web Framework for Haskell. Create RESTful web apps with type safety.">
|]
    addCassius $(cassiusFile "root")
    addStylesheet $ StaticR hk_html_css
    y <- lift getYesod
    addScriptEither $ urlJqueryJs y
    addScriptRemote "http://cdn.jquerytools.org/1.2.0/full/jquery.tools.min.js"
    addJulius $(juliusFile "root")

getFiveMinutesR :: Handler RepHtml
getFiveMinutesR = defaultLayout $ do
    setTitle "Yesod in Five Minutes"
    addCassius $(cassiusFile "five-minutes")
    addHamlet $(hamletFile "five-minutes")

getAboutR :: Handler RepHtml
getAboutR = defaultLayout $ do
    setTitle "About Yesod"
    addCassius $(cassiusFile "about")
    addHamlet $(hamletFile "about")

getExamplesR :: Handler RepHtml
getExamplesR = defaultLayout [$hamlet|\
<h1>We've Moved!
<p>
    \The examples have now been merged into the 
    <a href="@{BookR}">Yesod book
    \. Each example is its own chapter in the Examples part. Enjoy!
|]

getScreencastsR :: Handler RepHtml
getScreencastsR = do
    raw <- liftIO $ U.readFile "screencasts.html"
    y <- getYesod
    defaultLayout $ do
        setTitle "Yesod Web Framework Screencasts"
        addScriptEither $ urlJqueryJs y
        addScriptEither $ urlJqueryUiJs y
        addStylesheetEither $ urlJqueryUiCss y
        addJulius $(juliusFile "screencasts")
        addCassius $(cassiusFile "screencasts")
        addHamlet $ const $ preEscapedString raw

getArticlesR :: Handler ()
getArticlesR = redirect RedirectPermanent $ ChapterR "blog-posts"

getSynWrqR :: Handler RepHtml
getSynWrqR = do
    let title = "web-routes-quasi Synopsis"
    raw <- liftIO $ U.readFile "yesod-examples/synopsis/web-routes-quasi.markdown"
    let pandoc = readMarkdown defaultParserState raw
    let content = preEscapedString $ writeHtmlString defaultWriterOptions pandoc
    defaultLayout $ do
        setTitle title
        addHamlet $(hamletFile "synopsis")

synLhs :: String -> String -> Handler RepHtml
synLhs file title' = do
    let title = title' ++ " Synopsis"
    raw <- liftIO $ U.readFile $ "yesod-examples/synopsis/" ++ file ++ ".lhs"
    let content = preEscapedString $ colorize title raw True
    defaultLayout $ do
        setTitle $ string title
        addStylesheet $ StaticR hscolour_css
        addHamlet $(hamletFile "synopsis")

getSynPerR :: Handler RepHtml
getSynPerR = synLhs "persistent" "Persistent"

getSynHamR :: Handler RepHtml
getSynHamR = synLhs "hamlet" "Hamlet"

getFaviconR :: Handler ()
getFaviconR = sendFile "image/x-icon" "favicon.ico" >> return ()

getRobotsR :: Handler RepPlain
getRobotsR = robots SitemapR

getSitemapR :: Handler RepXml
getSitemapR = do
    y <- getYesod
    sitemap $ home : screencasts : examples' : book
            : map go1 (concatMap partChapters $ bookParts $ getBook y)
            ++ map go2 (getEntries y)
  where
    date = UTCTime (read "2010-09-01") $ secondsToDiffTime 0
    home = SitemapUrl HomeR date Daily 1.0
    screencasts = SitemapUrl ScreencastsR date Daily 0.9
    examples' = SitemapUrl ExamplesR date Daily 0.9
    book = SitemapUrl BookR date Daily 0.9
    go1 (Chapter { chapterSlug = name }) =
        SitemapUrl (ChapterR $ T.unpack name) date Weekly 0.8
    go2 e = SitemapUrl
                (EntryR $ entrySlug e)
                (UTCTime (entryDay e) $ secondsToDiffTime 0)
                Monthly 0.5
