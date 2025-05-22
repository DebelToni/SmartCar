-module(blockchain_consensus).
-export([start_link/0, init/0, handle_new_block/2, validate_block/2, propose_block/1, handle_vote/2, finalize_block/2, get_chain/0, reset/0]).

-define(TIMEOUT, 5000).
-define(VOTE_THRESHOLD, 0.66).

-record(state, {
    chain = [],         % List of blocks
    pending_blocks = [],% Blocks waiting for validation
    votes = #{},        % Map of block_hash() => [vote()],
    validators = [],    % List of validator pids
    current_height = 0,
    proposal_in_progress = false
}).

-record(block, {
    index,
    previous_hash,
    timestamp,
    data,
    hash,
    proposer
}).

-record(vote, {
    block_hash,
    voter,
    vote_type    % 'approve' | 'reject'
}).

start_link() ->
    spawn_link(?MODULE, init, []).

init() ->
    register(blockchain_consensus, self()),
    process_flag(trap_exit, true),
    State = #state{},
    loop(State).

loop(State) ->
    receive
        {new_block, Block} ->
            NewState = handle_new_block(Block, State),
            loop(NewState);
        {vote, Vote} ->
            NewState = handle_vote(Vote, State),
            loop(NewState);
        {propose_block, Data} ->
            NewState = propose_block(Data, State),
            loop(NewState);
        {finalize_block, Block} ->
            NewState = finalize_block(Block, State),
            loop(NewState);
        {get_chain, Caller} ->
            Caller ! {chain, State#state.chain},
            loop(State);
        reset ->
            loop(#state{}),
        {'EXIT', _From, Reason} ->
            %% Handle exits
            io:format("Exiting: ~p~n", [Reason]),
            ok;
        after ?TIMEOUT ->
            %% Periodic tasks can be added here
            loop(State)
    end.

handle_new_block(Block, State) ->
    case validate_block(Block, State) of
        true ->
            UpdatedPending = lists:delete(Block, State#state.pending_blocks),
            NewChain = [Block | State#state.chain],
            NewState = State#state{
                chain = NewChain,
                pending_blocks = UpdatedPending,
                current_height = Block#index
            },
            broadcast({finalize_block, Block}),
            NewState;
        false ->
            State
    end.

validate_block(Block, State) ->
    %% Basic validation: previous hash matches
    case State#state.chain of
        [] ->
            %% Genesis block
            true;
        [Prev | _] ->
            Prev#block.hash =:= Block#block.previous_hash andalso
            Block#block.index =:= Prev#block.index + 1 andalso
            (now() - Block#block.timestamp) >= 0 andalso
            is_valid_hash(Block#block.hash)
    end.

is_valid_hash(Hash) ->
    %% Placeholder for hash validation
    true.

propose_block(Data, State) ->
    case State#state.proposal_in_progress of
        true ->
            State;
        false ->
            LatestBlock = hd(State#state.chain),
            NewBlock = #block{
                index = LatestBlock#block.index + 1,
                previous_hash = LatestBlock#block.hash,
                timestamp = now(),
                data = Data,
                hash = compute_hash(LatestBlock#block.hash, Data, now()),
                proposer = self()
            },
            NewState = State#state{
                pending_blocks = [NewBlock | State#state.pending_blocks],
                proposal_in_progress = true
            },
            broadcast({propose_block, NewBlock}),
            NewState
    end.

compute_hash(PrevHash, Data, Timestamp) ->
    %% Placeholder for hash computation
    crypto:hash(md5, io_lib:format("~p~p~p", [PrevHash, Data, Timestamp])).

handle_vote(Vote, State) ->
    BlockHash = Vote#vote.block_hash,
    VotesForBlock = maps:get(BlockHash, State#state.votes, []),
    UpdatedVotes = [Vote | VotesForBlock],
    NewVotesMap = maps:put(BlockHash, UpdatedVotes, State#state.votes),
    {approve_count, reject_count} = count_votes(UpdatedVotes),
    TotalVotes = length(UpdatedVotes),
    case (approve_count / max(TotalVotes,1)) >= ?VOTE_THRESHOLD of
        true ->
            %% Finalize block if threshold reached
            case find_block_by_hash(BlockHash, State#state.pending_blocks) of
                {ok, Block} ->
                    finalize_block(Block, State);
                error ->
                    State
            end;
        false ->
            State#state{votes = NewVotesMap}
    end.

count_votes(Votes) ->
    Approves = length([V || V <- Votes, V#vote.vote_type =:= approve]),
    Rejects = length([V || V <- Votes, V#vote.vote_type =:= reject]),
    {ApproveCount, RejectCount} = {Approves, Rejects},
    {ApproveCount, RejectCount}.

find_block_by_hash(Hash, Blocks) ->
    case lists:filter(fun(B) -> B#block.hash =:= Hash end, Blocks) of
        [Block] -> {ok, Block};
        [] -> error
    end.

finalize_block(Block, State) ->
    UpdatedChain = [Block | State#state.chain],
    NewState = State#state{
        chain = UpdatedChain,
        votes = maps:remove(Block#block.hash, State#state.votes),
        proposal_in_progress = false
    },
    broadcast({block_finalized, Block}),
    NewState.

get_chain() ->
    self() ! {get_chain, self()}.

reset() ->
    self() ! reset.

broadcast(Message) ->
    %% Placeholder for broadcast mechanism
    ok.