{-
  メインフレーム：
  メッセージを受け取り、各モジュールに渡すだけを行う
-}

module Main (main) where

import qualified Data.Map as Map
import Control.Concurrent
import Utility.Prim
import qualified UI.Operator as UI
import MetaData.Types
import qualified MetaData.Operator as MetaData

procedures :: [(Signature, Procedure, ClientState)] 
procedures = [(UI, UI.operation, UnitState), (MetaData, MetaData.operation, CS emptyBinder)]

main :: IO ()
main = runMT (threadManager procedures) () Map.empty

threadManager :: [(Signature, Procedure, ClientState)] -> DispatcherThread ()
threadManager wps = do wl <- fork wps
                       setStatus $ Map.fromList wl
                       dispatch

dispatch :: DispatcherThread ()
dispatch = do (sig, m) <- fetch
              sigm <- getStatus
              case Map.lookup sig sigm of
                Nothing -> dispatch
                Just tid -> 
                    do require tid m
                       if isExit m 
                       then do killMThread tid -- threadの死に方は検討課題
                               let sigm' = Map.delete sig sigm
                               if Map.null sigm' 
                               then return ()
                               else setStatus sigm' >> dispatch
                       else dispatch
    where
      isExit (NM m) = m == "exit"

fork :: [(Signature, Procedure, ClientState)] 
     -> DispatcherThread [(Signature, ThreadId)]
fork [] = return []
fork ((sig, proc, initial):wps) = do tid <- forkMT initial proc
                                     ths <- fork wps
                                     return $ (sig, tid):ths
