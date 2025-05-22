{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Blockchain.Consensus where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.List (sortOn)
import Data.Maybe (fromMaybe, isJust, mapMaybe)
import Data.Time.Clock (UTCTime, getCurrentTime)
import Data.Foldable (foldlM)
import Control.Monad.State
import Control.Monad.Reader
import Control.Monad.Except
import GHC.Generics (Generic)
import Data.Hashable (Hashable)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS

type Hash = ByteString

data BlockHeader = BlockHeader
  { bhParentHash :: Hash
  , bhTimestamp  :: UTCTime
  , bhNonce      :: Integer
  , bhMinerID    :: ValidatorID
  } deriving (Show, Eq, Generic)

data Block = Block
  { blockHeader :: BlockHeader
  , blockBody   :: [Transaction]
  } deriving (Show, Eq, Generic)

type Transaction = ByteString

type ValidatorID = ByteString

data LedgerState = LedgerState
  { balances       :: Map.Map ValidatorID Integer
  , processedTxs   :: Set.Set Hash
  , chain          :: Blockchain
  , pendingTxs     :: [Transaction]
  } deriving (Show, Eq)

data Blockchain = Blockchain
  { blocks       :: Map.Map Hash Block
  , headHash     :: Hash
  , height       :: Integer
  } deriving (Show, Eq)

data ConsensusParams = ConsensusParams
  { maxTxPerBlock :: Int
  , difficulty    :: Integer
  , blockTime     :: Integer
  } deriving (Show, Eq)

data ConsensusState = ConsensusState
  { csLedger         :: LedgerState
  , csParams         :: ConsensusParams
  , csValidators     :: Set.Set ValidatorID
  , csPendingVotes   :: Map.Map Hash (Set.Set ValidatorID)
  , csCurrentHeight  :: Integer
  , csPendingBlocks  :: Map.Map Hash Block
  , csLastBlockTime  :: UTCTime
  } deriving (Show, Eq)

data Vote = Vote
  { vValidator :: ValidatorID
  , vBlockHash :: Hash
  } deriving (Show, Eq)

data ValidationResult = ValidationSuccess | ValidationFailure String deriving (Show, Eq)

type ConsensusM = StateT ConsensusState (ExceptT String IO)

initializeLedger :: [Transaction] -> Map.Map ValidatorID Integer -> Blockchain -> LedgerState
initializeLedger txs balances genesisChain = LedgerState
  { balances = balances
  , processedTxs = Set.empty
  , chain = genesisChain
  , pendingTxs = txs
  }

initializeConsensus :: ConsensusParams -> Set.Set ValidatorID -> LedgerState -> UTCTime -> ConsensusState
initializeConsensus params validators ledger lastTime = ConsensusState
  { csLedger = ledger
  , csParams = params
  , csValidators = validators
  , csPendingVotes = Map.empty
  , csCurrentHeight = height (chain ledger) + 1
  , csPendingBlocks = Map.empty
  , csLastBlockTime = lastTime
  }

validateTransaction :: Transaction -> LedgerState -> Either String (Hash, Integer)
validateTransaction tx LedgerState{..} =
  let txHash = -- derive hash from transaction content
        BS.pack (show tx)
      sender = extractSender tx
      amount = extractAmount tx
      senderBalance = Map.findWithDefault 0 sender balances
  in if senderBalance >= amount
     then Right (txHash, amount)
     else Left ("Insufficient balance for sender: " ++ BS.unpack sender)

extractSender :: Transaction -> ValidatorID
extractSender = BS.takeWhile (/= ':') -- placeholder logic

extractAmount :: Transaction -> Integer
extractAmount tx =
  case BS.split ':' tx of
    [_sender, amtStr] -> read (BS.unpack amtStr)
    _ -> 0

applyTransactions :: [Transaction] -> LedgerState -> Either String LedgerState
applyTransactions txs ledger@LedgerState{..} = foldlM applyTx ledger txs
  where
    applyTx :: LedgerState -> Transaction -> Either String LedgerState
    applyTx l tx =
      case validateTransaction tx l of
        Left err -> Left err
        Right (txHash, amt) ->
          if Set.member txHash processedTxs
          then Left "Transaction already processed"
          else
            let sender = extractSender tx
                receiver = extractReceiver tx
                balances' = Map.adjust (subtract amt) sender $
                            Map.insertWith (+) receiver amt (balances)
                processed' = Set.insert txHash processedTxs
            in Right l { balances = balances', processedTxs = processed' }

extractReceiver :: Transaction -> ValidatorID
extractReceiver = BS.dropWhile (/= ':') . BS.drop 1 -- placeholder

createBlock :: BlockHeader -> [Transaction] -> Block
createBlock header txs = Block header txs

computeBlockHash :: Block -> Hash
computeBlockHash Block{..} =
  BS.concat [BS.pack (show blockHeader), BS.concat blockBody]

validateBlock :: Block -> LedgerState -> ConsensusM ValidationResult
validateBlock block ledger@LedgerState{..} = do
  ConsensusParams{..} <- gets csParams
  let header = blockHeader block
  currentTime <- liftIO getCurrentTime
  if bhTimestamp header > currentTime
    then return $ ValidationFailure "Block timestamp is in the future"
    else do
      let parentBlock = Map.lookup (bhParentHash header) (blocks (chain ledger))
      case parentBlock of
        Nothing -> return $ ValidationFailure "Parent block not found"
        Just _ -> do
          let blockHash = computeBlockHash block
          if Map.member blockHash (blocks (chain ledger))
            then return $ ValidationFailure "Block already exists"
            else do
              result <- liftEither $ applyTransactions (blockBody block) ledger
              case result of
                Left err -> return $ ValidationFailure err
                Right updatedLedger -> do
                  return ValidationSuccess

verifyVotes :: Hash -> ConsensusM (Set.Set ValidatorID)
verifyVotes blockHash = do
  votesMap <- gets csPendingVotes
  return $ Map.findWithDefault Set.empty blockHash votesMap

castVote :: Hash -> ValidatorID -> ConsensusM ()
castVote blockHash validator = do
  votesMap <- gets csPendingVotes
  let voters = Map.findWithDefault Set.empty blockHash votesMap
      voters' = Set.insert validator voters
  modify' $ \s -> s { csPendingVotes = Map.insert blockHash voters' votesMap }

checkConsensus :: Hash -> ConsensusM Bool
checkConsensus blockHash = do
  votes <- verifyVotes blockHash
  totalValidators <- gets (Set.size . csValidators)
  return $ Set.size votes > totalValidators `div` 2

finalizeBlock :: Hash -> ConsensusM ()
finalizeBlock blockHash = do
  pendingBlocks <- gets csPendingBlocks
  case Map.lookup blockHash pendingBlocks of
    Nothing -> return ()
    Just block -> do
      ledger <- gets csLedger
      result <- validateBlock block ledger
      case result of
        ValidationSuccess -> do
          newChain <- gets csLedger >>= \l -> return (chain l)
          let newBlocks = (blocks (chain ledger)) `Map.union` Map.singleton (computeBlockHash block) block
              newChain' = newChain { blocks = newBlocks, headHash = computeBlockHash block, height = csCurrentHeight <$> get }
          modify' $ \s -> s { csLedger = (csLedger s) { chain = newChain', balances = (balances (csLedger s)), processedTxs = (processedTxs (csLedger s)) } }
          clearVotes blockHash
        ValidationFailure _ -> return ()

clearVotes :: Hash -> ConsensusM ()
clearVotes bh = modify' $ \s -> s { csPendingVotes = Map.delete bh (csPendingVotes s) }

proposeBlock :: ValidatorID -> [Transaction] -> ConsensusM ()
proposeBlock validator txs = do
  ledger <- gets csLedger
  params <- gets csParams
  currentTime <- liftIO getCurrentTime
  let parentHash = headHash (chain ledger)
      header = BlockHeader
        { bhParentHash = parentHash
        , bhTimestamp = currentTime
        , bhNonce = 0
        , bhMinerID = validator
        }
      block = createBlock header txs
      blockHash = computeBlockHash block
  modify' $ \s -> s { csPendingBlocks = Map.insert blockHash block (csPendingBlocks s) }
  broadcastVote blockHash validator

broadcastVote :: Hash -> ValidatorID -> ConsensusM ()
broadcastVote bh validator = castVote bh validator

processReceivedVote :: Vote -> ConsensusM ()
processReceivedVote Vote{..} = do
  isValidator <- gets (Set.member vValidator . csValidators)
  when isValidator $
    castVote vBlockHash vValidator

consensusLoop :: ConsensusM ()
consensusLoop = forever $ do
  pendingBlocks <- gets csPendingBlocks
  forM_ (Map.elems pendingBlocks) $ \block -> do
    let blockHash = computeBlockHash block
    consensusReached <- checkConsensus block