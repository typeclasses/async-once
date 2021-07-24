module LazyAsync.Actions.Memoize where

import LazyAsync.Actions.Spawn     (lazyAsync)
import LazyAsync.Actions.StartWait (startWait)

import LazyAsync.Prelude (ContT (runContT), Functor (fmap), IO,
                          MonadBaseControl)

{- | Creates a situation wherein:

  * The action shall begin running only once the memoized action runs
  * The action shall run at most once
  * The action shall run only within the continuation (when the continuation ends, the action is stopped)
-}
memoize :: (MonadBaseControl IO m) =>
    m a -- ^ Action
    -> ContT r m (m a) -- ^ Memoized action, in a continuation
memoize action = fmap startWait (lazyAsync action)

-- | Akin to 'memoize'
withMemoizedIO :: IO a -> (IO a -> IO b) -> IO b
withMemoizedIO action = runContT (memoize action)
