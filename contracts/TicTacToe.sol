pragma solidity ^0.5.0;

import "./Libraries/SafeMath.sol";
import "./Libraries/RLP.sol";
import "./Libraries/ECDSA.sol";

contract TicTacToe {
    using SafeMath for uint256;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using ECDSA for bytes32;

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
        uint256 currentStateNonce;
        bool termination;
        uint256 terminationStartTimestamp;
        uint256 terminationTimeLimit;
    }

    // map from player address to his stats
    mapping(address => Player) playerStats;
    // map from matchId to current state of that match
    mapping(bytes32 => Match) matches;

    event MatchStarted(address player1, address player2, bytes32 matchId);
    event MatchWon(address winner, bytes32 matchId);
    event MatchDrawn(bytes32 matchId);
    event TerminationStarted(bytes32 matchId, uint256 terminationTimeLimit);
    event TerminationCancelled(bytes32 matchId);

    function startMatch(address opponent, uint256 terminationTimeLimit)
        public
        returns (bytes32 matchId)
    {
        playerStats[msg.sender].opponentNonce[opponent] = playerStats[msg.sender].opponentNonce[opponent].add(1);
        uint256 nonce = playerStats[msg.sender].opponentNonce[opponent];

        // no need to verify if matchId is unique, if we assume the hash function is collision resistant
        matchId = keccak256(abi.encode(msg.sender, opponent, nonce));
        matches[matchId].inProgress = true;
        // termination time limit in seconds
        matches[matchId].terminationTimeLimit = terminationTimeLimit;
        matches[matchId].players = [msg.sender, opponent];

        emit MatchStarted(msg.sender, opponent, matchId);
        return matchId;
    }

    modifier matchInProgress(bytes32 matchId) {
        require(matches[matchId].inProgress, "Match is not in progress");
        _;
    }

    modifier terminationInProgress(bytes32 matchId) {
        require(matches[matchId].termination, "Match is not in termination");
        _;
    }

    modifier matchTerminationNotExpired(bytes32 matchId) {
        require(
            matches[matchId].terminationStartTimestamp + matches[matchId].terminationTimeLimit <= block.timestamp,
            "Time limit to resolve termination expired"
        );
        _;
    }

    modifier matchTerminationExpired(bytes32 matchId) {
        require(
            matches[matchId].terminationStartTimestamp + matches[matchId].terminationTimeLimit > block.timestamp,
            "Time limit to resolve termination has not expired"
        );
        _;
    }

    modifier playerIsPartOfMatch(address player, bytes32 matchId) {
        require(
            matches[matchId].players[0] == player || matches[matchId].players[1] == player,
            "Must be a player in the match"
        );
        _;
    }

    function sendStateUpdate(
        bytes32 matchId,
        uint8[9] memory boardState,
        uint8 gameStatus,
        uint256 stateNonce,
        bytes memory signaturePlayer1,
        bytes memory signaturePlayer2
    )
        public matchInProgress(matchId) playerIsPartOfMatch(msg.sender, matchId)
    {
        Match memory currMatch = matches[matchId];

        // either nonce is bigger, or first state update with nonce 0
        require(
            stateNonce > currMatch.currentStateNonce || (stateNonce == 0 && currMatch.currentStateRoot == 0),
            "Trying to update a state with a nonce smaller than the current one"
        );

        // users should have signed this state root
        bytes32 stateRoot = keccak256(abi.encode(matchId, boardState, gameStatus, stateNonce));
        // messages signed are prepended with "\x19Ethereum Signed Message:\n32" for safety
        // stateRoot = stateRoot.toEthSignedMessageHash();

        // get address used to sign state root
        address[2] memory players = [
            stateRoot.recover(signaturePlayer1),
            stateRoot.recover(signaturePlayer2)
        ];

        // we assume the first signature is from player 1, the player that called startMatch(...)
        require(players[0] == currMatch.players[0], "Wrong signature for player 1");
        require(players[1] == currMatch.players[1], "Wrong signature for player 2");

        updateMatchState(matchId, gameStatus, stateNonce, stateRoot);
    }

    function updateMatchState(
        bytes32 matchId,
        uint8 gameStatus,
        uint256 stateNonce,
        bytes32 stateRoot
    )
        internal
    {
        Match memory currMatch = matches[matchId];

        if(gameStatus == 0) {
            // if game in progress, gameStatus == 0
            if(currMatch.termination){
                currMatch.termination = false;
                emit TerminationCancelled(matchId);
            }
            currMatch.currentStateRoot = stateRoot;
            currMatch.currentStateNonce = stateNonce;
        } else if(gameStatus == 1 || gameStatus == 2) {
            // if player 1 won, gameStatus == 1
            // if player 2 won, gameStatus == 2
            address winner = gameStatus == 1 ? currMatch.players[0] : currMatch.players[1];

            playerWonMatch(matchId, winner);
        } else if(gameStatus == 3) {
            // if game was a draw, gameStatus == 3
            address[2] memory players = currMatch.players;

            // add a draw for player 1
            playerStats[players[0]].draws = playerStats[players[0]].draws.add(1);
            // add a draw for player 2
            playerStats[players[1]].draws = playerStats[players[1]].draws.add(1);

            // game finished
            currMatch.inProgress = false;
            emit MatchDrawn(matchId);
        } else {
            revert("invalid game status");
        }
    }

    // start termination
    function forceStateUpdate(
        bytes32 matchId,
        uint8[9] memory previousBoardState,
        uint8 move,
        uint8 gameStatus,
        uint256 stateNonce
    )
        public matchInProgress(matchId) playerIsPartOfMatch(msg.sender, matchId)
    {
        // check if transition is valid
        Match memory currMatch = matches[matchId];
        uint8[9] memory newState = previousBoardState;

        // check the game state is valid
        // check it's the player's turn
        if(stateNonce % 2 == 0) {
            require(msg.sender == currMatch.players[0], "Not player 1 turn");
            newState[move] = 1;
        } else {
            require(msg.sender == currMatch.players[0], "Not player 2 turn");
            newState[move] = 2;
        }
        // check that the space isn't already checked
        require(previousBoardState[move] == 0, "Cell already occupied");

        if(currMatch.termination){
            matches[matchId].termination = false;
            emit TerminationCancelled(matchId);
        }

        bytes32 stateRoot = keccak256(abi.encode(matchId, newState, gameStatus, stateNonce));
        // messages signed are prepended with "\x19Ethereum Signed Message:\n32" for safety
        stateRoot = stateRoot.toEthSignedMessageHash();

        if(isWinningState(newState)) {
            playerWonMatch(matchId, msg.sender);
        } else {
            // Update game state
            updateMatchState(matchId, gameStatus, stateNonce, stateRoot);
        }
    }

    function isWinningState(uint8[9] memory state) internal returns (bool) {
        uint8[8] memory rows = [
            state[0] & state[1] & state[2],
            state[3] & state[4] & state[5],
            state[6] & state[7] & state[8],
            state[0] & state[3] & state[6],
            state[1] & state[4] & state[7],
            state[2] & state[5] & state[8],
            state[0] & state[4] & state[8],
            state[2] & state[4] & state[6]
        ];
        // Loop over all of the rows and check if they bitwise and to 0x01 or 0x02
        for (uint8 i = 0; i < rows.length; i++) {
            if (rows[i] == 0x01 || rows[i] == 0x02) {
                return true;
            }
        }

        return false;
    }

    // bob acknowledges and cancels the termination
    function cancelTermination(bytes32 matchId)
        public
        matchInProgress(matchId)
        terminationInProgress(matchId)
        matchTerminationNotExpired(matchId)
        playerIsPartOfMatch(msg.sender, matchId)
    {
        matches[matchId].termination = false;
        emit TerminationCancelled(matchId);
    }

    // open a termination window
    function startTermination(bytes32 matchId)
        public
        matchTerminationExpired(matchId) playerIsPartOfMatch(msg.sender, matchId)
    {
        matches[matchId].termination = true;
        // could use current block number
        matches[matchId].terminationStartTimestamp = block.timestamp;
        emit TerminationStarted(matchId, matches[matchId].terminationTimeLimit);
    }

    function playerWonMatch(bytes32 matchId, address winner) internal {
        // infer the looser based on winner, as its a 2 player game
        address looser = matches[matchId].players[0] == winner ? matches[matchId].players[1] : matches[matchId].players[0];

        playerStats[winner].wins = playerStats[winner].wins.add(1);
        playerStats[looser].losses = playerStats[winner].wins.add(1);

        // game finished
        matches[matchId].inProgress = false;
        emit MatchWon(winner, matchId);
    }
}