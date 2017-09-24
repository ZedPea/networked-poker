module Types where

import Control.Monad.Trans.State (StateT(..), State)
import Data.Char (toLower)
import Text.Printf (PrintfArg(..), printf, fmtPrecision, fmtChar, vFmt, 
                    formatString, errorBadFormat)

-- DATA TYPES

data Game = Game {
    _playerQueue :: PlayerQueue,
    _stage :: Stage,
    _cardInfo :: Cards,
    _roundDone :: Bool,
    _bets :: Bets,
    _gameFinished :: Bool,
    _roundNumber :: Int
} deriving (Show)

data Player = Player {
    _name :: String,
    _num :: Int,
    _chips :: Int,
    _cards :: [Card],
    _inPlay :: Bool,
    _allIn :: Bool,
    _bet :: Int,
    _madeInitialBet :: Bool,
    _hand :: [Card],
    _handInfo :: Maybe HandInfo,
    _canReRaise :: Bool
} deriving (Eq, Show)

data Cards = Cards {
    _tableCards :: [Card],
    _deck :: [Card]
} deriving (Show)

data Bets = Bets {
    _pots :: [Pot],
    _currentBet :: Int,
    _smallBlindSize :: Int,
    _bigBlindSize :: Int,
    _minimumRaise :: Int
} deriving (Show)

data Card = Card {
    _value :: Value,
    _suit :: Suit
} deriving (Eq)

data HandInfo = HandInfo {
    _handValue :: Hand Value Value,
    _bestHand :: [Card]
} deriving (Eq, Show)

data Pot = Pot {
    _pot :: Int,
    _playerIDs :: [Int]
} deriving (Show)

data PlayerQueue = PlayerQueue {
    _players :: [Player],
    _dealer :: Int
} deriving (Show)

data Stage = PreFlop 
           | Flop 
           | Turn 
           | River 
           | Showdown 
           deriving (Show)

data Suit = Heart 
          | Spade 
          | Club 
          | Diamond 
          deriving (Show, Bounded, Enum, Eq)

data Value = Two 
           | Three 
           | Four 
           | Five 
           | Six 
           | Seven 
           | Eight 
           | Nine 
           | Ten 
           | Jack 
           | Queen 
           | King 
           | Ace 
           deriving (Show, Bounded, Enum, Eq, Ord)

data Action a = Fold 
              | Check 
              | Call 
              | Raise a 
              | AllIn 
              deriving (Show)

data Hand a b = HighCard a 
              | Pair a 
              | TwoPair a b
              | ThreeOfAKind a
              | Straight a b 
              | Flush a
              | FullHouse a b 
              | FourOfAKind a
              | StraightFlush a b
              deriving (Eq, Ord)

-- TYPES

type GameStateT a = StateT Game IO a

type GameState a = State Game a

type PlayerID = Int

-- INSTANCES

instance (PrintfArg a, PrintfArg b) => Show (Hand a b) where
    show (HighCard a) = printf "high card %V" a
    show (Pair a) = printf "pair of %Vs" a
    show (TwoPair a b) = printf "two pair, %Vs and %Vs" a b
    show (ThreeOfAKind a) = printf "three of a kind, %Vs" a
    show (Straight a b) = printf "straight, %V to %V" a b
    show (Flush a) = printf "flush, %V high" a
    -- a's over b's == 3 a's, 2 b's
    show (FullHouse a b) = printf "full house, %Vs over %Vs" a b
    show (FourOfAKind a) = printf "four of a kind, %Vs" a
    show (StraightFlush a b) = printf "straight flush, %V to %V" a b

instance PrintfArg Value where
    formatArg x fmt
        | fmtChar (vFmt 'V' fmt) == 'V' 
            = formatString (map toLower $ show x) 
              (fmt { fmtChar = 's', fmtPrecision = Nothing })
        | otherwise = errorBadFormat $ fmtChar fmt

instance Show Card where
    show (Card value' suit') = show value' ++ " of " ++ show suit' ++ "s"
