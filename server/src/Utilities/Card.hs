{-# LANGUAGE CPP #-}

module Utilities.Card
(
    dealCards,
    hearts,
    clubs,
    diamonds,
    spades,
    fullDeck,
    revealFlop,
    revealTurn,
    revealRiver,
)
where

import System.Random (getStdRandom, randomR)
import Control.Lens ((^.), (.=), (%=), ix)
import Control.Monad.Trans.State (get)
import Control.Monad.Trans.Class (lift)
import Control.Monad (when, replicateM_)

import Types (Card(..), Value, Suit(..), Stage(..), GameStateT)
import Utilities.Player (numPlayers)
import Utilities.Types (fromPure)

import Lenses 
    (cards, cardInfo, deck, tableCards, stage, playerQueue, players)

#ifdef DEBUG
import Output.Terminal.Output (outputPlayerCards)
#else
import Output.Network.Output (outputPlayerCards)
#endif

dealCards :: GameStateT ()
dealCards = do
    updateCards =<< fromPure numPlayers
    outputPlayerCards

updateCards :: Int -> GameStateT ()
updateCards 0 = return ()
updateCards n = do
    cards' <- drawPlayerCards
    playerQueue.players.ix (n-1).cards .= cards'
    updateCards (n-1)

drawPlayerCards :: GameStateT [Card]
drawPlayerCards = do
    a <- getRandomCard
    b <- getRandomCard
    return [a, b]

getRandomCard :: GameStateT Card
getRandomCard = do
    s <- get

    let deck' = s^.cardInfo.deck

    when (null deck') $ error "Can't take a card from an empty deck!"

    cardNum <- lift . getStdRandom $ randomR (0, length deck' - 1)
    deleteNth cardNum

    return $ deck' !! cardNum

drawCard :: GameStateT ()
drawCard = do
    card <- getRandomCard
    cardInfo.tableCards %= (\cards' -> cards' ++ [card])

revealFlop :: GameStateT ()
revealFlop = do
    replicateM_ 3 drawCard
    stage .= Flop

revealTurn :: GameStateT ()
revealTurn = do
    drawCard
    stage .= Turn

revealRiver :: GameStateT ()
revealRiver = do
    drawCard
    stage .= River

deleteNth :: Int -> GameStateT ()
deleteNth n = do
    when (n < 0) $ error "Can't remove negative deck index!"

    cardInfo.deck %= (\xs -> take n xs ++ drop (n+1) xs)

fullDeck :: [Card]
fullDeck = [Card value suit | value <- [minBound :: Value .. maxBound],
                              suit <- [minBound :: Suit .. maxBound]]

hearts :: [Card]
hearts = [Card value Heart | value <- [minBound :: Value .. maxBound]]

clubs :: [Card]
clubs = [Card value Club | value <- [minBound :: Value .. maxBound]]

diamonds :: [Card]
diamonds = [Card value Diamond | value <- [minBound :: Value .. maxBound]]

spades :: [Card]
spades = [Card value Spade | value <- [minBound :: Value .. maxBound]]