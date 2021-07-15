module AsyncOnce.PollType where

import AsyncOnce.Done      (Done (Failure, Success))
import Control.Applicative (Applicative (pure, (<*>)))
import Data.Function       (($), (.))
import Data.Functor        (Functor (fmap))

data Poll a = Incomplete | Done (Done a)

instance Functor Poll where
    _ `fmap` Incomplete = Incomplete
    f `fmap` Done x = Done (f `fmap` x)

instance Applicative Poll where
    pure = Done . pure

    Done (Failure e) <*> _                = Done $ Failure e
    _                <*> Done (Failure e) = Done $ Failure e
    Done (Success f) <*> Done (Success x) = Done $ Success $ f x
    _                <*> _                = Incomplete
