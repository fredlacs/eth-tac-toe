pragma solidity ^0.5.0;

contract TicTacToe {

    struct Player {
        uint256 wins;
        uint256 losses;
        uint256 draws;
        // number of matches played against an opponent
        mapping(address => uint256) opponentNonce;
    }

    // map from player address to his stats
    mapping(address => Player) playerStats;
    // map from matchId to current state of that match
    mapping(bytes32 => bytes32) currentStateRoot;

    event NewMatch(address player1, address player2, bytes32 matchId);

    function startMatch(address opponent, uint256 timeoutLimit)
        public
        returns (bytes32 matchId)
    {
        playerStats[msg.sender].opponentNonce[opponent] = playerStats[msg.sender].opponentNonce[opponent] + 1;
        uint256 nonce = playerStats[msg.sender].opponentNonce[opponent];

        // hash address of the 2 players and nonce
        matchId = keccak256(abi.encode(msg.sender, opponent, nonce));
        emit NewMatch(msg.sender, opponent, matchId);
        return matchId;
    }

    function updateMatchState(bytes32 newStateRoot, uint8[9] memory boardState, uint8 gameStatus, bytes memory signatures) public {
        if(gameStatus == 0) {
            // in progress
        } else if(gameStatus == 1) {
            // win
        } else if(gameStatus == 2) {
            // loss
        } else {
            // draw
        }

        // rlp encode board and mode_modifier
        // hash them and require they equal state root
        // verify signatures
    }
}