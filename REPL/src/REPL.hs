{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module REPL ( {-
              showFirstDirEntries,
              showFileSnapshot,
              showUpdateData,
              showFileSubstring,
              showHelp,
              showMap,
              showDiffMap,
              showTarContents,
              showArchiveCompare,
              exitREPL,
              copyArchive,
              cutFile,
              unzipArchive,
              -}
              processCycle,
              ProcessBuilderInfo (..)
              ) where 
import qualified Codec.Archive.Tar.Index as TI
import qualified Data.Map.Strict as M
import qualified Data.Char as DC
import qualified Data.List as DL
import qualified Control.Exception as X
import Control.Monad(forever)
import System.IO (stdout, hFlush)

import Data.Int(Int64)
import System.Exit(exitSuccess)
import System.Directory(copyFile)

import TarUtil
import ArchiveUpdate

data ProcessBuilderInfo = PBI {
  archive :: FilePath,
  archiveClone :: FilePath,
  tar :: FilePath,
  tarClone :: FilePath,
  snapshotURL :: URL,
  archiveURL :: URL
} deriving (Eq, Show)

parseIntEnd :: (Num a, Read a) => String -> a
parseIntEnd val | DL.length l > 0 = read (DL.last l)
                | otherwise = 0
  where l = words val

processCycle :: ProcessBuilderInfo -> IO ()
processCycle pbi = forever $ do
  putStr "Input command: "
  hFlush stdout
  command <- getLine
  hFlush stdout
  (processCommand command) `X.catch` eh `X.catch` eh2 `X.catch` eh3
  where 
    processCommand = buildCommand pbi
    eh (e :: X.IOException) = putStrLn $ "IO Error: " ++ (show e)
    eh2 (e :: UpdateArchiveException) = putStrLn $ "Parsing error: " ++ (show e) 
    eh3 (e :: X.ErrorCall) = putStrLn $ "Error call: " ++ (show e)

buildCommand :: ProcessBuilderInfo -> (String -> IO())
buildCommand pbi = processCommand
  where 
    processCommand command
      -- checks the current gzip archive and understands what to download
      | chk "checkclone" = showUpdateData (archiveClone pbi) (snapshotURL pbi) 
      -- checks the current gzip archive and understands what to download
      | chk "check" = showUpdateData (archive pbi) (snapshotURL pbi)     

      | chk "fileclone" = showFileSnapshot (archiveClone pbi)
      | chk "file" = showFileSnapshot (archive pbi)  -- shows the snapshot of hackage file
      
      | chk "copyorig" = copyArchive (archive pbi) (archiveClone pbi) -- copies the current archive to the orig place

      | chk "cutclone" = cutFile (archiveClone pbi) (parseIntEnd command) 
      | chk "cut" = cutFile (archive pbi) (parseIntEnd command) -- cuts the end of the gzip file for checking purposes

      | chk "unzipclone" = unzipArchive (archiveClone pbi) (tarClone pbi) -- unzips the downloaded gzip archive
      | chk "unzip" = unzipArchive (archive pbi) (tar pbi)  -- unzips the downloaded gzip archive

      | chk "tarparseclone" = showMap (tarClone pbi) 50 -- loads the tar clone information in the memory
      | chk "tarparse" = showMap (tar pbi) 50  -- loads the tar information in the memory

      | chk "tarshowclone" = showTarContents (tarClone pbi)
      | chk "tarshow" = showTarContents (tar pbi)

      | chk "compare" = showArchiveCompare (archive pbi) (archiveClone pbi) 

      | chk "updatecut" = performArchiveCutUpdate (snapshotURL pbi) (archiveURL pbi) 
                          (archive pbi) (parseIntEnd command) >> return ()
      | chk "update" = performArchiveFileUpdate (snapshotURL pbi) (archiveURL pbi) (archive pbi) >> return ()
      -- | chk "updatesmart" = undefined

      | chk "tarcmp" = showDiffMap (tar pbi) (tarClone pbi)
      | chk "exit" = exitREPL

      | chk "help" = showHelp pbi
      | otherwise = showHelp pbi

      where pc = map DC.toLower command
            chk val = DL.isPrefixOf val pc

showFirstDirEntries :: TI.TarIndex -> Int -> IO ()
showFirstDirEntries index count = mapM_ print $ take count (getEntries index)

-- Displays the snapshot of the file
showFileSnapshot :: FilePath -> IO()
showFileSnapshot file = do
  filesnapshot <- calcFileData file
  putStrLn $ "File result for " ++ file
  putStrLn $ "\tFile snapshot: " ++ (show filesnapshot)

-- Shows the update data for the archive on disk
showUpdateData :: FilePath -> URL -> IO()
showUpdateData file json = do
  (range, snapshot, filesnapshot) <- calcUpdateResult2 file json
  putStrLn $ "Update result for file " ++ file
  putStrLn $ "\tHackage snapshot: " ++ (show snapshot)
  putStrLn $ "\tFile snapshot: " ++ (show filesnapshot)
  putStrLn $ "\tRange to update: " ++ (show range)

-- shows the substring of specified length from file from offset 
showFileSubstring :: FilePath -> Int64 -> Int64 -> IO ()
showFileSubstring file from length = do
  putStrLn $ "Showing " ++ file ++ " substr"
  putStr "\t"
  substr <- getFileSubstring file from length
  print substr

-- Copies the archive from first filename to the second
copyArchive :: FilePath -> FilePath -> IO ()
copyArchive archive1 archive2 = do
  copyFile archive1 archive2
  putStrLn $ "Copied the " ++ archive1 ++ " to " ++ archive2

showMap :: FilePath -> Int -> IO()
showMap path count = do
  putStrLn $ "Displaying " ++ (show count) ++ " entries for " ++ path
  tarIndexE <- loadTarIndex path
  case tarIndexE of 
    Left error -> putStrLn "Whoa. Error loading tar"
    Right index -> mapM_ (print.snd) $ take count $ M.toList $ buildHackageMap index

showDiffMap :: FilePath -> FilePath -> IO ()
showDiffMap newTarFile oldTarFile = do
  putStrLn $ "Displaying difference between " ++ newTarFile ++ " and " ++ oldTarFile
  newTarIndexE <- loadTarIndex newTarFile
  oldTarIndexE <- loadTarIndex oldTarFile
  let newMapE = buildHackageMap <$> newTarIndexE
  let oldMapE = buildHackageMap <$> oldTarIndexE
  let diffMapE = buildDifferenceMap <$> oldMapE <*> newMapE
  case diffMapE of 
    Right m -> mapM_ (print.snd) $ M.toList m
    Left _ -> print "Error creating the indexes"

showHelp :: ProcessBuilderInfo -> IO()
showHelp pbi = do
  putStrLn "Available commands: "

  putStrLn $ "check - downloads the json length and md5 hash from " ++ (snapshotURL pbi) ++ 
             ", and compares it with local " ++ (archive pbi)
  putStrLn $ "checkclone - same for " ++ (archiveClone pbi)
  putStrLn $ "file - displays the current " ++ (archive pbi) ++ " length and md5 hash"
  putStrLn $ "fileclone - same for " ++ (archiveClone pbi) ++ " file"
  putStrLn $ "copyorig - copy the " ++ (archive pbi) ++ " to " ++ (archiveClone pbi)
  putStrLn $ "cut size - cuts the size bytes from the end of the " ++ (archive pbi) ++ " , for update command"
  putStrLn $ "cutclone size - cuts the size bytes from the end of the 01-index.tar.gz, for update command"
  putStrLn $ "unzip - unzips the " ++ (archive pbi) ++ " in the " ++ (tar pbi) ++ " file"
  putStrLn $ "unzipclone - unzips the " ++ (archiveClone pbi) ++ " in the " ++ (tarClone pbi) ++ " file"
  putStrLn $ "compare - compares the " ++ (archive pbi) ++ " with " ++ (archiveClone pbi)
  putStrLn $ "tarparse - loads the map of entries from " ++ (tar pbi) ++ " and displays it" 
  putStrLn $ "tarparseclone - same for " ++ (tarClone pbi)
  putStrLn $ "tarshow - show sample contents from " ++ (tar pbi)
  putStrLn $ "tarshowclone - show sample contents from " ++ (tarClone pbi)
  putStrLn $ "tarcmp - compares the entries of " ++ (tar pbi) ++ " and " ++ (tarClone pbi)
  putStrLn $ "update - updates the current " ++ (archive pbi) ++ " from " ++ (archiveURL pbi)
  putStrLn $ "updatecut size - cuts the size from " ++ (archive pbi) ++ " and then updates"
  putStrLn "exit - exits this repl"

showArchiveCompare :: FilePath -> FilePath -> IO()
showArchiveCompare archive1 archive2= do
  val <- compareFiles archive1 archive2
  putStrLn $ "Compare result " ++ archive1 ++ " " ++ archive2 ++ " " ++ (show val)


showTarContents :: FilePath -> IO()
showTarContents archive = do
  putStrLn $ "Displaying the tar indices" ++ " for " ++ archive
  tarIndexE <- loadTarIndex archive
  case tarIndexE of 
    Left error -> putStrLn "Whoa. Error loading tar"
    Right index -> showFirstDirEntries index 100 



exitREPL :: IO()
exitREPL = putStrLn "Finished working with hackage REPL" >> exitSuccess

-- this method cuts the data from the end of the archive
-- needed mostly for testing purposes
cutFile :: FilePath -> Int64 -> IO()
cutFile path size = do
  truncateIfExists path size
  putStrLn $ "Cut " ++ (show size) ++ " bytes from " ++ path

unzipArchive :: FilePath -> FilePath -> IO()
unzipArchive archive tar = do
  putStrLn $ "Unzipping " ++ archive ++ " to " ++ tar
  unzipFile archive tar


