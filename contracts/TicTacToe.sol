pragma solidity ^0.5.0;

contract TicTacToe {

    struct Player {
        uint256 wins;
        uint256 losses;
        uint256 draws;
        // number of matches played against an opponent
        mapping(address => uint256) opponentNonce;
    }

    struct Match {
        address[2] players;
        bool inProgress;
        bytes32 currentStateRoot;
        bool dispute;
        uint256 disputeTimeLimit;
    }

    // map from player address to his stats
    mapping(address => Player) playerStats;
    // map from matchId to current state of that match
    mapping(bytes32 => Match) matches;

    event NewMatch(address player1, address player2, bytes32 matchId);

    function startMatch(address opponent, uint256 disputeTimeLimit)
        public
        returns (bytes32 matchId)
    {
        playerStats[msg.sender].opponentNonce[opponent] = playerStats[msg.sender].opponentNonce[opponent] + 1;
        uint256 nonce = playerStats[msg.sender].opponentNonce[opponent];

        // hash address of the 2 players and nonce
        matchId = keccak256(abi.encode(msg.sender, opponent, nonce));
        matches[matchId].inProgress = true;
        matches[matchId].disputeTimeLimit = disputeTimeLimit;
        matches[matchId].players = [msg.sender, opponent];

        // TODO: does the opponent need to accept the challenge?

        emit NewMatch(msg.sender, opponent, matchId);
        return matchId;
    }

    function updateMatchState(
        bytes32 matchId,
        bytes32 newStateRoot,
        uint8[9] memory boardState,
        uint8 gameStatus,
        uint256 stateRootNonce,
        bytes memory signatures
    )
        public
    {
        Match memory currMatch = matches[matchId];

        require(currMatch.inProgress, "State root can only be updated for matches in progress");
        require(
            currMatch.players[0] == msg.sender || currMatch.players[1] == msg.sender,
            "Must be a player in the match in order to update state root"
        );

        if(gameStatus == 0) {
            // rlp encode board and mode_modifier
            // hash them and require they equal state root
            // verify signatures
            // resolve dispute if any
        } else if(gameStatus == 1) {
            // player 1 win
        } else if(gameStatus == 2) {
            // player 2 win
        } else if(gameStatus == 3){
            // draw
        } else {
            revert("invalid game status");
        }
    }

    // start dispute stating state transition you wish
    function startDispute() public {
        // check if transition is valid
        // if transition valid, start dispute timer for opponent to answer
    }

    // bob accepts the state and sends his next move
    function resolveDispute() public {

    }

    // bob did not answer the dispute, so alice forces a win
    function terminateDispute() public {

    }
}