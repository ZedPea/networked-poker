module Utilities.Player
(
    numInPlay,
    numInPlayPure,
    numAllIn,
    numAllInPure,
    numPlayers,
    getCurrentPlayerPure,
    getCurrentPlayer,
    getPlayerByUUID,
    victor,
    nextPlayer,
    nextDealer,
    resetDealer,
    removeOutPlayers,
    leftOfDealer,
    mkNewPlayer,
    getCurrentPlayerUUID
)
where

import Control.Lens (Getting, (^.), (^?!), (%=), (.=), (^..), _head, traversed)
import Control.Monad.Trans.State (get)
import Control.Monad.Trans.Class (lift)
import Data.List (elemIndex, find)
import Data.Maybe (mapMaybe)
import Control.Monad (when, unless, replicateM_)
import Safe (headNote, tailNote)
import Data.UUID.Types (UUID)
import Network.Socket (Socket, close)
import System.Random (getStdRandom, random)
import Data.Tuple (swap)

import Types (Player(..), GameState, GameStateT, Game)

import Lenses (inPlay, allIn, gameFinished, dealer, uuid, chips, players,
               playerQueue, socket)

numInPlayPure :: Game -> Int
numInPlayPure = numXPure inPlay

numAllInPure :: Game -> Int
numAllInPure = numXPure allIn

numXPure :: Getting Bool Player Bool -> Game -> Int
numXPure lens s = length $ filter (^.lens) (s^.playerQueue.players)

numInPlay :: (Monad m) => GameState m Int
numInPlay = numX inPlay

numAllIn :: (Monad m) => GameState m Int
numAllIn = numX allIn

numX :: (Monad m) => Getting Bool Player Bool -> GameState m Int
numX lens = do
    s <- get

    return . length $ filter (^.lens) (s^.playerQueue.players)

numPlayers :: (Monad m) => GameState m Int
numPlayers = do
    s <- get

    return . length $ s^.playerQueue.players

getCurrentPlayerPure :: Game -> Player
getCurrentPlayerPure s = s^.playerQueue.players ^?! _head

getCurrentPlayer :: (Monad m) => GameState m Player
getCurrentPlayer = do
    s <- get

    return $ s^.playerQueue.players ^?! _head

victor :: (Monad m) => GameState m Player
victor = do
    s <- get

    return $ headNote "in victorID!" 
                      (filter (^.inPlay) (s^.playerQueue.players))

-- this function resets the current player to the one left of the dealer
-- imagine there are 6 players. the dealer is pointing at player 4, so left
-- of the dealer is player 5. He goes first next round. To findDealer out how many
-- times we need to shift him to get him to the front of the queue, we take
-- the number of players (6) minus (the dealer (3) + 1) - remember arrays
-- are 0 indexed, so if dealer is pointing at 4, actual value is 3.
-- so we need to shift the player twice, once to position 6, then once
-- to loop around to position 1.
-- we then set the dealer to numPlayers(6) - 1. Pointing at player 6,
-- who was player 4.
resetDealer :: (Monad m) => GameState m ()
resetDealer = do
    s <- get

    numPlayers' <- numPlayers

    let shift = (numPlayers' - 1) - (s^.playerQueue.dealer)

    replicateM_ shift nextPlayer 

    playerQueue.dealer .= (numPlayers' - 1)

nextDealer :: (Monad m) => GameState m ()
nextDealer = do
    numPlayers' <- numPlayers

    playerQueue.dealer %= advance numPlayers'

    where advance numPlayers' n
            | numPlayers' == 0 = error "Divide by zero in nextDealer"
            | otherwise = n + 1 `rem` numPlayers'

nextPlayer :: (Monad m) => GameState m ()
nextPlayer = playerQueue.players %= shift
    where shift x = tailNote "in nextPlayer!" x ++ 
                   [headNote "in nextPlayer!" x]

-- don't want to import Output.hs because then we have an import loop, 
-- as output imports a few convenience funcs from here
removeOutPlayers :: (Maybe [UUID] -> GameStateT ()) -> GameStateT ()
removeOutPlayers outputFunc = do
    s <- get

    -- findDealer out who needs removing
    let toRemove = filter (\x -> x^.chips <= 0) (s^.playerQueue.players)
        removed
            | null toRemove = Nothing
            | otherwise = Just $ toRemove^..traversed.uuid

    -- let them know they're being removed
    outputFunc removed

    -- Close their sockets so we don't run out
    lift $ mapM_ close (toRemove^..traversed.socket)

    -- then actually removed them, if we remove them before telling them
    -- they are being removed, we don't have their socket to message them
    unless (null toRemove) $ do
        playerQueue.players %= remove

        -- stick dealer at head of list
        let oldPlayers = flatten (s^.playerQueue.dealer) (s^.playerQueue.players)
        -- search through list starting with guy at head to findDealer new person
        -- nearest left to old dealer
        updateDealer oldPlayers

        numPlayers' <- numPlayers

        when (numPlayers' <= 1) $ gameFinished .= True

    where remove = filter (\x -> x^.chips > 0)

updateDealer :: (Monad m) => [Player] -> GameState m ()
updateDealer old = do
    new <- get

    playerQueue.dealer .= findDealer (new^.playerQueue.players) old

findDealer :: Eq a => [a] -> [a] -> Int
findDealer new = head . mapMaybe (`elemIndex` new)

flatten :: Int -> [a] -> [a]
flatten x = uncurry (++) . swap . splitAt x

leftOfDealer :: (Monad m) => [Player] -> GameState m UUID
leftOfDealer subset = do
    s <- get

    case findNearestToDealer subset (s^.playerQueue.players) of
        Just x -> return x
        Nothing -> error "Couldn't find dealer in subset!"

findNearestToDealer :: [Player] -> [Player] -> Maybe UUID
findNearestToDealer subset = fmap (^.uuid) . find (`elem` subset)

getPlayerByUUID :: (Monad m) => UUID -> GameState m Player
getPlayerByUUID uuid' = do
    s <- get

    unless (uuid' `elem` (s^..playerQueue.players.traversed.uuid)) $ 
        error "UUID does not belong to any known players in getPlayerByUUID!"

    let players' = filter (\p -> p^.uuid == uuid') (s^.playerQueue.players)

    return $ headNote "in getPlayerByUUIDPure!" players'

mkNewPlayer :: String -> Socket -> IO Player
mkNewPlayer name' sock = do
    uuid' <- getStdRandom random
    return $ Player sock name' uuid' 1000 [] True False 0 False Nothing True

getCurrentPlayerUUID :: (Monad m) => GameState m UUID
getCurrentPlayerUUID = fmap (^.uuid) getCurrentPlayer
