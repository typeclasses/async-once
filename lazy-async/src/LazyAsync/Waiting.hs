module LazyAsync.Waiting where

import Control.Applicative    ((*>))
import Control.Concurrent.STM (STM, atomically, retry)
import Control.Monad          (return, (>=>))
import Control.Monad.Catch    (MonadThrow, throwM)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Function          ((.))
import LazyAsync.LazyAsync    (LazyAsync)
import LazyAsync.Outcome      (Outcome (Failure, Success))
import LazyAsync.Polling      (pollSTM)
import LazyAsync.Starting     (start)
import LazyAsync.Status       (Status (Done, Incomplete))
import System.IO              (IO)

-- | Same as 'waitCatch', but in 'STM'
waitCatchSTM :: LazyAsync a -> STM (Outcome a)
waitCatchSTM = pollSTM >=> statusOutcomeSTM

-- | Waits for the action to complete, and returns its value
--
-- If the action throws an exception, then the exception is returned
--
-- Does __not__ start the action
waitCatch :: MonadIO m => LazyAsync a -> m (Outcome a)
waitCatch = liftIO . waitCatchIO

-- | Specialization of 'waitCatch'
waitCatchIO :: LazyAsync a -> IO (Outcome a)
waitCatchIO = atomically . waitCatchSTM

-- | Waits for the action to complete, and returns its value
--
-- If the action throws an exception, then the exception is re-thrown
--
-- Does __not__ start the action
wait :: LazyAsync a -> IO a
wait = liftIO . waitIO

-- | Specialization of 'wait'
waitIO :: LazyAsync a -> IO a
waitIO = waitCatch >=> outcomeSuccess

-- | Starts an asynchronous action, waits for it to complete, and returns its value
--
-- If the action throws an exception, then the exception is re-thrown.
startWait :: MonadIO m => LazyAsync a -> m a
startWait = liftIO . startWaitIO

-- | Specialization of 'startWait'
startWaitIO :: LazyAsync a -> IO a
startWaitIO ao = start ao *> wait ao

-- | Starts an asynchronous action, waits for it to complete, and returns its value
--
-- If the action throws an exception, then the exception is returned
startWaitCatch :: MonadIO m => LazyAsync a -> m (Outcome a)
startWaitCatch = liftIO . startWaitCatchIO

-- | Specialization of 'startWaitCatch'
startWaitCatchIO :: LazyAsync a -> IO (Outcome a)
startWaitCatchIO ao = start ao *> waitCatch ao

statusOutcomeSTM :: Status a -> STM (Outcome a)
statusOutcomeSTM Incomplete = retry
statusOutcomeSTM (Done x)   = return x

outcomeSuccess :: MonadThrow m => Outcome a -> m a
outcomeSuccess (Failure e) = throwM e
outcomeSuccess (Success x) = return x
