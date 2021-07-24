{-# language Safe #-}

module LazyAsync.Actions.Start where

import LazyAsync.Types.Apply     (Apply (..))
import LazyAsync.Types.LazyAsync (LazyAsync (..))
import LazyAsync.Types.StartPoll (StartPoll (..))

import LazyAsync.Prelude (Applicative ((*>)), IO, MonadBase (..), MonadIO (..),
                          STM, atomically, return)

-- | Starts an asynchronous action, if it has not already been started
start :: (MonadBase base m, MonadIO base) => LazyAsync a -> m ()
start Pure{}               = return ()
start Empty{}              = return ()
start (A1 (StartPoll s _)) = liftBase (liftIO (atomically s))
start (Ap (Apply x y))     = start x *> start y
start (Choose x y)         = start x *> start y

-- | Akin to 'start'
startIO :: LazyAsync a -> IO ()
startIO = start

-- | Akin to 'start'
startSTM :: LazyAsync a -> STM ()
startSTM Pure{}               = return ()
startSTM Empty{}              = return ()
startSTM (A1 (StartPoll s _)) = s
startSTM (Ap (Apply x y))     = startSTM x *> startSTM y
startSTM (Choose x y)         = startSTM x *> startSTM y
