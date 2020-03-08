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
        uint256 currentStateRootNonce;
        bool dispute;
        uint256 disputeStartTimestamp;
        uint256 disputeTimeLimit;
    }

    // map from player address to his stats
    mapping(address => Player) playerStats;
    // map from matchId to current state of that match
    mapping(bytes32 => Match) matches;

    event MatchStarted(address player1, address player2, bytes32 matchId);
    event MatchWon(address winner, bytes32 matchId);
    event MatchDrawn(bytes32 matchId);
    event DisputeStarted(bytes32 matchId, uint256 disputeTimeLimit);
    event DisputeResolved(bytes32 matchId);

    function startMatch(address opponent, uint256 disputeTimeLimit)
        public
        returns (bytes32 matchId)
    {
        playerStats[msg.sender].opponentNonce[opponent] = playerStats[msg.sender].opponentNonce[opponent].add(1);
        uint256 nonce = playerStats[msg.sender].opponentNonce[opponent];

        // no need to verify if matchId is unique, if we assume the hash function is collision resistant
        matchId = keccak256(abi.encode(msg.sender, opponent, nonce));
        matches[matchId].inProgress = true;
        // dispute time limit in seconds
        matches[matchId].disputeTimeLimit = disputeTimeLimit;
        matches[matchId].players = [msg.sender, opponent];

        // TODO: does the opponent need to accept the challenge?

        emit MatchStarted(msg.sender, opponent, matchId);
        return matchId;
    }

    modifier matchInProgress(bytes32 matchId) {
        require(matches[matchId].inProgress, "Match is not in progress");
        _;
    }

    modifier matchInDispute(bytes32 matchId) {
        require(matches[matchId].dispute, "Match is not in dispute");
        _;
    }

    modifier matchDisputeNotExpired(bytes32 matchId) {
        require(
            matches[matchId].disputeStartTimestamp + matches[matchId].disputeTimeLimit <= block.timestamp,
            "Time limit to resolve dispute expired"
        );
        _;
    }

    modifier matchDisputeExpired(bytes32 matchId) {
        require(
            matches[matchId].disputeStartTimestamp + matches[matchId].disputeTimeLimit > block.timestamp,
            "Time limit to resolve dispute has not expired"
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

    function updateMatchState(
        bytes32 matchId,
        uint8[9] memory boardState,
        uint8 gameStatus,
        uint256 stateRootNonce,
        bytes memory rlpEncodedSignatures
    )
        public matchInProgress(matchId) playerIsPartOfMatch(msg.sender, matchId)
    {
        Match memory currMatch = matches[matchId];

        require(
            stateRootNonce > currMatch.currentStateRootNonce,
            "Trying to update a state with a nonce smaller than the current one"
        );

        // users should have signed this state root
        bytes32 stateRoot = keccak256(abi.encode(boardState, gameStatus, stateRootNonce));
        // messages signed are prepended with "\x19Ethereum Signed Message:\n32" for safety
        stateRoot = stateRoot.toEthSignedMessageHash();

        RLPReader.RLPItem[] memory signatures = rlpEncodedSignatures.toRlpItem().toList();
        address[2] memory players = [
            stateRoot.recover(signatures[0].toBytes()),
            stateRoot.recover(signatures[1].toBytes())
        ];
        // we assume the first signature is from player 1, the player that called startMatch(...)
        require(players[0] == currMatch.players[0], "Wrong signature for player 1");
        require(players[1] == currMatch.players[1], "Wrong signature for player 2");

        if(gameStatus == 0) {
            // if game in progress, gameStatus == 0
            matches[matchId].currentStateRoot = stateRoot;
            matches[matchId].currentStateRootNonce = stateRootNonce;
            matches[matchId].dispute = false;
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
            matches[matchId].inProgress = false;
            emit MatchDrawn(matchId);
        } else {
            revert("invalid game status");
        }
    }


    // start dispute stating state transition you wish
    function startDispute(bytes32 matchId) public matchInProgress(matchId) playerIsPartOfMatch(msg.sender, matchId) {
        // check if transition is valid
        // if transition valid, start dispute timer for opponent to answer
        Match memory currMatch = matches[matchId];

        // TODO: add the state to validation
        require(validGameState(), "The state you are trying to submit is not valid");

        matches[matchId].dispute = true;
        // could use current block number
        matches[matchId].disputeStartTimestamp = block.timestamp;
        emit DisputeStarted(matchId, currMatch.disputeTimeLimit);
    }

    // bob accepts the state and sends his next move
    function resolveDispute(bytes32 matchId)
        public
        matchInProgress(matchId)
        matchInDispute(matchId)
        matchDisputeNotExpired(matchId)
        playerIsPartOfMatch(msg.sender, matchId)
    {
        // Match memory currMatch = matches[matchId];

        // TODO: add the state to validation
        require(validGameState(), "The state you are trying to submit is not valid");

        matches[matchId].dispute = false;
        emit DisputeResolved(matchId);
    }

    // bob did not answer the dispute, so alice forces a win
    function terminateDispute(bytes32 matchId)
        public
        matchDisputeExpired(matchId) playerIsPartOfMatch(msg.sender, matchId)
    {
        // player has won the game
        matches[matchId].dispute = false;
        playerWonMatch(matchId, msg.sender);
    }

    function validGameState() internal returns (bool) {
        // what happens if this valid game state wins the game? trigger win function
        return true;
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