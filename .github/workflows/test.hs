import Data.Maybe
import System.Environment
import System.Process

main =
  do
    ghcString <- getEnv "ghc"
    let ghc = case ghcString of "8.10" -> GHC_8_10; "9.0" -> GHC_9_0
    callProcess "cabal" ("build" : "all" : constraints ghc)
    callProcess "cabal" ("test" : "all" : "--enable-tests" : constraints ghc)

x .= Just y  = Just "--constraint=" ++ x ++ "==" ++ y
x .= Nothing = Nothing

data GHC = GHC_8_10 | GHC_9_0

constraints ghc = catMaybes
    [ "base"              .= case ghc of GHC_8_10 -> Just "4.14.*"  ; GHC_9_0 -> Just "4.15.*"
    , "exceptions"        .= case ghc of GHC_8_10 -> Just "0.10.0"  ; GHC_9_0 -> Just "0.10.4"
    , "hedgehog"          .= case ghc of GHC_8_10 -> Just "1.0.4"   ; GHC_9_0 -> Just "1.0.5"
    , "lifted-async"      .= case ghc of GHC_8_10 -> Just "0.10.0"  ; GHC_9_0 -> Just "0.10.2"
    , "monad-control"     .= case ghc of GHC_8_10 -> Just "1.0.0.4" ; GHC_9_0 -> Just "1.0.2.3"
    , "o-clock"           .= case ghc of GHC_8_10 -> Just "1.2.0"   ; GHC_9_0 -> Just "1.2.1"
    , "optics-core"       .= case ghc of GHC_8_10 -> Just "0.3"     ; GHC_9_0 -> Just "0.4"
    , "optics-th"         .= case ghc of GHC_8_10 -> Just "0.3"     ; GHC_9_0 -> Just "0.4"
    , "transformers-base" .= case ghc of GHC_8_10 -> Just "0.4.5"   ; GHC_9_0 -> Just "0.4.5.2"
    ]
