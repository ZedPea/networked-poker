module StateUtilities
(
    isShowdown
)
where

import Types
import Lenses (state)

import Control.Lens

isShowdown :: Game -> Bool
isShowdown game = case game^.state of
    Showdown -> True
    _ -> False
