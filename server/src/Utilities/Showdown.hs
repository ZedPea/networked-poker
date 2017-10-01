module Utilities.Showdown
(
    handSubsets,
    cardValue,
    cardValueAceLow,
    getValue,
    uuidOfEachValue,
    uuidOfSuit,
    sorted,
    consecutive,
    cardValues,
    sizeOfHand,
    getHand
)
where

import Data.List (sort, sortBy, group)
import Data.Function (on)
import Safe (at, headNote)

import Types (Card(..), Value(..), Hand)
import Utilities.Card (hearts, clubs, diamonds, spades)

cardValues :: [Card] -> Bool -> [Int]
cardValues c aceHigh
    | aceHigh = sort $ map (cardValue . getValue) c
    | otherwise = sort $ map (cardValueAceLow . getValue) c

uuidOfSuit :: [Card] -> [Int]
uuidOfSuit c = map (`uuidSuit` c) [isHeart, isClub, isDiamond, isSpade]

uuidSuit :: (a -> Bool) -> [a] -> Int
uuidSuit f x = length $ filter f x

isHeart :: Card -> Bool
isHeart x = x `elem` hearts

isClub :: Card -> Bool
isClub x = x `elem` clubs

isDiamond :: Card -> Bool
isDiamond x = x `elem` diamonds

isSpade :: Card -> Bool
isSpade x = x `elem` spades

sorted :: [Card] -> [Card]
sorted = sortBy (compare `on` getValue)

getValue :: Card -> Value
getValue (Card v _) = v

getHand :: (Hand a b, [Card]) -> Hand a b
getHand (h, _) = h

cardValue :: Value -> Int
cardValue Two = 2
cardValue c = 1 + cardValue (pred c)

cardValueAceLow :: Value -> Int
cardValueAceLow Ace = 1
cardValueAceLow Two = 2
cardValueAceLow c = 1 + cardValueAceLow (pred c)

-- For the 7 cards on the table, get all unique 5 card hands. There will be 21.
-- Taken from http://rosettacode.org/wiki/Combinations#Haskell
handSubsets :: [Card] -> [[Card]]
handSubsets xs = combsBySize xs `at` sizeOfHand
    where combsBySize = foldr f ([[]] : repeat [])
          f x next = zipWith (++) (map (map (x:)) ([]:next)) next

sizeOfHand :: Int
sizeOfHand = 5

consecutive :: (Eq a, Num a) => [a] -> Bool
consecutive [] = True
consecutive xs = consecutive' xs (headNote "in consecutive!" xs)

consecutive' :: (Num t, Eq t) => [t] -> t -> Bool
consecutive' [] _ = True
consecutive' (x:xs) val
    | x == val = consecutive' xs (val + 1)
    | otherwise = False

uuidOfEachValue :: [Card] -> [Int]
uuidOfEachValue cards' = map length . group . sort $ map getValue cards'
