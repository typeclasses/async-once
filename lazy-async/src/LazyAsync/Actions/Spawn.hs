{-# language Safe #-}

module LazyAsync.Actions.Spawn
  ( lazyAsync, withLazyAsyncIO
  , manyLazyAsyncs, withLazyAsyncListIO
  , acquire, acquireIO
  ) where

import LazyAsync.Libraries.Async (Async, async, cancel, pollSTM, withAsync)

import LazyAsync.Types (LazyAsync (A1), Outcome (..), Resource (..),
                        StartPoll (..), Status (..))

import LazyAsync.Prelude (Applicative ((*>)), Bool (..), ContT (..),
                          Either (..), Functor (fmap), IO, Maybe (..),
                          MonadBase (..), MonadBaseControl (StM), MonadIO (..),
                          SomeException, TVar, Traversable, atomically, check,
                          lift, newTVarIO, readTVar, return, traverse,
                          writeTVar, (<&>), (>>=))

startPoll :: MonadBaseControl IO m =>
    m a -- ^ Action
    -> ContT b m (StartPoll (StM m a))
startPoll action =
  do
    s <- lift (newTVar False)
    a <- ContT (withAsync (waitForTrue s *> action))
    return (makeStartPoll s a)

acquireStartPoll :: MonadBaseControl IO m =>
    m a -- ^ Action
    -> m (Resource m (StartPoll (StM m a)))
acquireStartPoll action =
  do
    s <- newTVar False
    a <- async (waitForTrue s *> action)
    return (Resource{ release = cancel a, resource = makeStartPoll s a})

makeStartPoll :: TVar Bool -> Async a -> StartPoll a
makeStartPoll s a = StartPoll (writeTVar s True) (pollSTM a <&> maybeEitherStatus)

{- | Creates a situation wherein:

  * The action shall begin running only once it is needed (that is, until prompted by 'LazyAsync.start')
  * The action shall run asynchronously (other than where it is 'LazyAsync.wait'ed upon)
  * The action shall run at most once
  * The action shall run only within the continuation (when the continuation ends, the action is stopped)
-}
lazyAsync :: MonadBaseControl IO m =>
    m a -- ^ Action
    -> ContT r m (LazyAsync (StM m a))
lazyAsync action = fmap A1 (startPoll action)

-- | 🌈 'manyLazyAsyncs' = @'traverse' 'lazyAsync'@
manyLazyAsyncs :: (MonadBaseControl IO m, Traversable t) =>
    t (m a) -> ContT r m (t (LazyAsync (StM m a)))
manyLazyAsyncs = traverse lazyAsync

-- | Akin to 'manyLazyAsyncs'
withLazyAsyncListIO :: [IO a] -> ([LazyAsync a] -> IO b) -> IO b
withLazyAsyncListIO actions = runContT (manyLazyAsyncs actions)

{- | Like 'lazyAsync', but does not automatically stop the action

The returned 'Resource' includes the desired 'LazyAsync' (the 'resource'), as
well as a 'release' action that brings it to a halt. If the action is not yet
started, 'release' prevents it from ever starting. If the action is in progress,
'release' throws an async exception to stop it. If the action is completed,
'release' has no effect.

A 'LazyAsync.LazyAsync' represents a background thread which may be utilizing
time and space. A running thread is not automatically reaped by the garbage
collector, so one should take care to eventually 'release' every 'LazyAsync'
resource to avoid accidentally leaving unwanted 'LazyAsync's running.

-}
acquire :: MonadBaseControl IO m =>
    m a -- ^ Action
    -> m (Resource m (LazyAsync (StM m a)))
acquire action = fmap (fmap A1) (acquireStartPoll action)

-- | Akin to 'acquire'
acquireIO :: IO a -> IO (Resource IO (LazyAsync a))
acquireIO = acquire

-- | Akin to 'lazyAsync'
withLazyAsyncIO :: IO a -> (LazyAsync a -> IO b) -> IO b
withLazyAsyncIO action = runContT (lazyAsync action)

waitForTrue :: (MonadBase base m, MonadIO base) => TVar Bool -> m ()
waitForTrue x = liftBase (liftIO (atomically (readTVar x >>= check)))

newTVar :: (MonadBase base m, MonadIO base) => a -> m (TVar a)
newTVar x = liftBase (liftIO (newTVarIO x))

maybeEitherStatus :: Maybe (Either SomeException a) -> Status a
maybeEitherStatus Nothing  = Incomplete
maybeEitherStatus (Just x) = Done (eitherDone x)

eitherDone :: Either SomeException a -> Outcome a
eitherDone (Left e)  = Failure e
eitherDone (Right x) = Success x
