module Showdown
(
    distributePot,
    getHandValue
)
where

import Control.Lens
import Data.Maybe (fromJust)
import Data.List (sortBy)

import Types (GameState, Card, HandInfo, Player, Pot)
import Showdown.Ord (ordHand)
import Utilities.Player (leftOfDealer)
import Control.Monad.Trans.State (get)
import Control.Monad (when)

import Showdown.Value 
    (isStraightFlush7Card, isFourOfAKind, isFullHouse, isFlush, 
     isStraight7Card, isThreeOfAKind, isTwoPair, isPair)

import Showdown.Best 
    (bestStraightFlush, bestFourOfAKind, bestFullHouse, bestFlush, 
     bestStraight, bestThreeOfAKind, bestTwoPair, bestPair, bestHighCard)

import Lenses 
    (playerQueue, players, cardInfo, handInfo, tableCards, cards, num, 
     playerIDs, chips, pot)

topHand :: [Card] -> HandInfo
topHand cards'
    | isStraightFlush7Card cards' = bestStraightFlush cards'
    | isFourOfAKind cards' = bestFourOfAKind cards'
    | isFullHouse cards' = bestFullHouse cards'
    | isFlush cards' = bestFlush cards'
    | isStraight7Card cards' = bestStraight cards'
    | isThreeOfAKind cards' = bestThreeOfAKind cards'
    | isTwoPair cards' = bestTwoPair cards'
    | isPair cards' = bestPair cards'
    | otherwise = bestHighCard cards'

getHandValue :: GameState ()
getHandValue = do
    s <- get
    let cards' = s^.cardInfo.tableCards

    zoom (playerQueue.players.traversed) $ do
        p <- get
        let allCards = cards' ++ p^.cards
        handInfo .= Just (topHand allCards)

getWinners :: [Player] -> [Player]
getWinners p = filter equalToWinner sorted
    where sorted = sortBy (flip sortHandValue) p
          winnerHand = fromJust $ head sorted^.handInfo
          equalToWinner x = ordHand winnerHand (fromJust (x^.handInfo)) == EQ

sortHandValue :: Player -> Player -> Ordering
sortHandValue p1 p2 = ordHand hand1 hand2
    where hand1 = fromJust $ p1^.handInfo
          hand2 = fromJust $ p2^.handInfo

distributePot :: Pot -> GameState (Pot, [Player])
distributePot sidePot = do
    s <- get

    let inPot = filter (\p -> p^.num `elem` sidePot^.playerIDs) 
                       (s^.playerQueue.players)
        winners = getWinners $ inPot
        chipsPerPerson = sidePot^.pot `div` length winners
        spareChips = sidePot^.pot `rem` length winners
        allPlayers = playerQueue.players.traversed
        isWinner p = p^.num `elem` winners^..traversed.num

    spareID <- leftOfDealer winners

    zoom (allPlayers.(filtered isWinner)) $ do
        p <- get

        chips += chipsPerPerson

        when (p^.num == spareID) $ chips += spareChips

    return (sidePot, winners)
