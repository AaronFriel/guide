module StackageCommands(
                        showSnapshots,
                        showLTSContents,
                        showStackageMapContents,
                        updateLTSFile, 
                        updateAllLTSFiles,
                        updatePersistentFromLTS) where

import qualified Data.ByteString as BS
import qualified Data.Map.Strict as M

import Common              
import StackageUpdate
import StackageArchive

showSnapshots :: URL -> IO ()
showSnapshots url = do
    SSS snapshots <- fetchStackageSnapshots url
    putStrLn $ "Showing snapshots from " ++ url
    mapM_ (putStrLn.(\s -> "\tSnapshot: " ++ s).show) snapshots

showLTSContents :: FilePath -> IO ()
showLTSContents ltsFile = do
    putStrLn $ "Showing the contents of " ++ ltsFile
    body <- BS.readFile ltsFile
    datum <- parseYamlFileThrow body
    print datum

-- updates the lts file from github
updateLTSFile :: FilePath -> URL -> IO ()
updateLTSFile = fetchLTS 

-- updates all of the lts files from the snapshot file at stackage

updateAllLTSFiles :: FilePath -> URL -> URL -> IO ()
updateAllLTSFiles ltsDir ltsURL snapshotsURL = do
    snapshots <- fetchStackageSnapshots snapshotsURL
    fetchAllLTSFiles ltsDir ltsURL (filterNormal snapshots)

updatePersistentFromLTS :: FilePath -> FilePath -> IO()
updatePersistentFromLTS updateDir ltsDir = undefined

showStackageMapContents :: FilePath -> URL -> URL -> Int -> IO()
showStackageMapContents ltsDir ltsURL snapshotsURL count = do
    putStrLn "Fetching snapshot lists"
    snapshots <- fetchStackageSnapshots snapshotsURL
    putStrLn "Downloading YAML files"
    fetchAllLTSFiles ltsDir ltsURL (filterNormal snapshots)
    putStrLn "Generating stackage map"
    map <- generateStackageMap ltsDir (filterNormal snapshots)
    putStrLn $ "Printing " ++ show count ++ " packages"
    mapM_ print $ take count $ M.toList map
