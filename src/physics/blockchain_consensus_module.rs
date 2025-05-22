use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use rand::Rng;
use tokio::sync::mpsc::{self, Sender, Receiver};
use tokio::task;
use tokio::time::{sleep, timeout};
use sha2::{Sha256, Digest};
use thiserror::Error;

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
struct Block {
    index: u64,
    previous_hash: Vec<u8>,
    timestamp: u128,
    data: Vec<u8>,
    nonce: u64,
    hash: Vec<u8>,
}

#[derive(Clone, Debug)]
struct Blockchain {
    chain: Vec<Block>,
    difficulty: usize,
}

#[derive(Error, Debug)]
enum ConsensusError {
    #[error("Invalid block")]
    InvalidBlock,
    #[error("Chain fork detected")]
    ForkDetected,
    #[error("Synchronization error")]
    SyncError,
    #[error("Timeout occurred")]
    Timeout,
}

struct Node {
    id: u64,
    blockchain: Arc<Mutex<Blockchain>>,
    peers: Vec<Sender<Block>>,
    mempool: Arc<Mutex<HashSet<Vec<u8>>>>,
    transaction_pool: Arc<Mutex<Vec<Vec<u8>>>>,
    received_blocks: Arc<Mutex<HashSet<Vec<u8>>>>,
    validator: Arc<Mutex<Validator>>,
    consensus_state: Arc<Mutex<ConsensusState>>,
    message_tx: Sender<Message>,
    message_rx: Receiver<Message>,
}

#[derive(Clone)]
enum Message {
    NewBlock(Block),
    RequestChain,
    RespondChain(Vec<Block>),
    Transaction(Vec<u8>),
}

struct Validator {
    private_key: Vec<u8>,
    public_key: Vec<u8>,
}

struct ConsensusState {
    current_round: u64,
    last_ask_time: Instant,
    leader_id: Option<u64>,
    votes: HashMap<Vec<u8>, HashSet<u64>>,
    proposals: HashMap<u64, Block>,
}

impl Node {
    fn new(id: u64, peers: Vec<Sender<Message>>) -> Self {
        let (tx, rx) = mpsc::channel(100);
        let validator = Validator {
            private_key: vec![0u8; 32],
            public_key: vec![1u8; 32],
        };
        let blockchain = Arc::new(Mutex::new(Blockchain {
            chain: vec![],
            difficulty: 4,
        }));
        let mempool = Arc::new(Mutex::new(HashSet::new()));
        let transaction_pool = Arc::new(Mutex::new(vec![]));
        let received_blocks = Arc::new(Mutex::new(HashSet::new()));
        let consensus_state = Arc::new(Mutex::new(ConsensusState {
            current_round: 0,
            last_ask_time: Instant::now(),
            leader_id: None,
            votes: HashMap::new(),
            proposals: HashMap::new(),
        }));
        Self {
            id,
            blockchain,
            peers,
            mempool,
            transaction_pool,
            received_blocks,
            validator: Arc::new(Mutex::new(validator)),
            consensus_state,
            message_tx: tx,
            message_rx: rx,
        }
    }

    async fn start(mut self) {
        let message_handler = {
            let rx = self.message_rx.clone();
            let node = self.clone();
            task::spawn(async move {
                node.handle_messages(rx).await;
            })
        };

        let consensus_loop = {
            let node = self.clone();
            task::spawn(async move {
                node.run_consensus().await;
            })
        };

        let broadcast_blocks = {
            let node = self.clone();
            task::spawn(async move {
                node.broadcast_new_blocks().await;
            })
        };

        tokio::join!(message_handler, consensus_loop, broadcast_blocks);
    }

    async fn handle_messages(&self, mut rx: Receiver<Message>) {
        while let Some(message) = rx.recv().await {
            match message {
                Message::NewBlock(block) => {
                    self.process_incoming_block(block).await;
                }
                Message::RequestChain => {
                    self.send_chain().await;
                }
                Message::RespondChain(chain) => {
                    self.resolve_chain(chain).await;
                }
                Message::Transaction(tx) => {
                    self.add_transaction(tx).await;
                }
            }
        }
    }

    async fn process_incoming_block(&self, block: Block) {
        let mut received = self.received_blocks.lock().unwrap();
        if !received.contains(&block.hash) {
            received.insert(block.hash.clone());
            let mut chain = self.blockchain.lock().unwrap();
            if self.validate_block(&block, &chain.chain) {
                chain.chain.push(block.clone());
                self.update_state_with_block(&block).await;
                for peer in &self.peers {
                    let _ = peer.send(Message::NewBlock(block.clone())).await;
                }
            }
        }
    }

    fn validate_block(&self, block: &Block, chain: &Vec<Block>) -> bool {
        if chain.is_empty() {
            return block.previous_hash.is_empty() && self.check_difficulty(&block.hash);
        }
        let last_block = chain.last().unwrap();
        if &block.previous_hash != &last_block.hash {
            return false;
        }
        let computed_hash = Self::calculate_hash(block.index, &block.previous_hash, block.timestamp, &block.data, block.nonce);
        if &computed_hash != &block.hash {
            return false;
        }
        self.check_difficulty(&block.hash)
    }

    fn check_difficulty(&self, hash: &Vec<u8>) -> bool {
        let leading_zeros = &hash[..1];
        leading_zeros[0] < (1 << (8 - self.blockchain.lock().unwrap().difficulty))
    }

    async fn update_state_with_block(&self, _block: &Block) {
        // Placeholder for state update logic
    }

    async fn send_chain(&self) {
        let chain = self.blockchain.lock().unwrap().chain.clone();
        for peer in &self.peers {
            let _ = peer.send(Message::RespondChain(chain.clone())).await;
        }
    }

    async fn resolve_chain(&self, chain: Vec<Block>) {
        let mut current_chain = self.blockchain.lock().unwrap();
        if chain.len() > current_chain.chain.len() {
            current_chain.chain = chain;
        }
    }

    async fn add_transaction(&self, tx: Vec<u8>) {
        let mut pool = self.transaction_pool.lock().unwrap();
        pool.push(tx);
    }

    async fn run_consensus(&self) {
        loop {
            let round_start = Instant::now();
            {
                let mut state = self.consensus_state.lock().unwrap();
                state.current_round += 1;
            }
            self.leader_selection().await;
            self.propose_block().await;
            self.collect_votes().await;
            self.finalize_block().await;
            let elapsed = round_start.elapsed();
            if elapsed < Duration::from_secs(10) {
                sleep(Duration::from_secs(10) - elapsed).await;
            }
        }
    }

    async fn leader_selection(&self) {
        let state = self.consensus_state.lock().unwrap();
        let leader_id = state.leader_id.unwrap_or_else(|| {
            let leader = self.determine_leader().await;
            leader
        });
        drop(state);
        let mut state = self.consensus_state.lock().unwrap();
        state.leader_id = Some(leader_id);
    }

    async fn determine_leader(&self) -> u64 {
        let hash_input = format!("{}-{}", self.id, Instant::now().elapsed().as_nanos());
        let mut hasher = Sha256::new();
        hasher.update(hash_input.as_bytes());
        let result = hasher.finalize();
        let leader = u64::from_be_bytes([result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7]]);
        leader % (self.peers.len() as u64 + 1)
    }

    async fn propose_block(&self) {
        let state = self.consensus_state.lock().unwrap();
        if state.leader_id != Some(self.id) {
            return;
        }
        let previous_hash = {
            let chain = self.blockchain.lock().unwrap();
            if chain.chain.is_empty() {
                vec![]
            } else {
                chain.chain.last().unwrap().hash.clone()
            }
        };
        let index = {
            let chain = self.blockchain.lock().unwrap();
            chain.chain.len() as u64 + 1
        };
        let data = self.collect_transactions().await;
        let timestamp = Instant::now().elapsed().as_millis();
        let mut nonce = 0u64;
        let hash = loop {
            let candidate_hash = Self::calculate_hash(index, &previous_hash, timestamp, &data, nonce);
            if self.check_difficulty(&candidate_hash) {
                break candidate_hash;
            }
            nonce += 1;
        };
        let new_block = Block {
            index,
            previous_hash,
            timestamp,
            data,
            nonce,
            hash: hash.clone(),
        };
        {
            let mut chain = self.blockchain.lock().unwrap();
            chain.chain.push(new_block.clone());
        }
        for peer in &self.peers {
            let _ = peer.send(Message::NewBlock(new_block.clone())).await;