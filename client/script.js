// window.onload = function() {
//   const url = window.location.origin;
//   let socket = io.connect(url);
// };

import {sign} from "./state-channel.js"

const url = window.location.origin;
let socket = io.connect(url);
let board = [0,0,0,0,0,0,0,0,0]
let nonce = 0;
let contractAddress = "0x2dFc473b8305445eb44d3538Bf286460d18Df071";
let contractAbi;
let TicTacToe;

let signatures = {}

import "./web3.min.js";
let newWeb3 = new Web3(window.ethereum);

let account;
// set account
newWeb3.eth.getAccounts( (err, accounts) => {
  if(err) alert(err)
  account = accounts[0]
})

var myTurn = true,
  symbol;

function getBoardState() {
  var obj = {};

  // We will compose an object of all of the Xs and Ox
  // that are on the board
  $(".board button").each(function() {
    obj[$(this).attr("id")] = $(this).text() || "";
  });

  return obj;
}

function isGameOver() {
  var state = getBoardState(),
    // One of the rows must be equal to either of these
    // value for
    // the game to be over
    matches = ["XXX", "OOO"],
    // These are all of the possible combinations
    // that would win the game
    rows = [
      state.a0 + state.a1 + state.a2,
      state.b0 + state.b1 + state.b2,
      state.c0 + state.c1 + state.c2,
      state.a0 + state.b1 + state.c2,
      state.a2 + state.b1 + state.c0,
      state.a0 + state.b0 + state.c0,
      state.a1 + state.b1 + state.c1,
      state.a2 + state.b2 + state.c2
    ];

  // Loop over all of the rows and check if any of them compare
  // to either 'XXX' or 'OOO'
  for (var i = 0; i < rows.length; i++) {
    if (rows[i] === matches[0] || rows[i] === matches[1]) {
      return true;
    }
  }
}

function renderTurnMessage() {
  // Disable the board if it is the opponents turn
  if (!myTurn) {
    $("#messages").text("Your opponent's turn");
    $(".board button").attr("disabled", true);

    // Enable the board if it is your turn
  } else {
    $("#messages").text("Your turn.");
    $(".board button").removeAttr("disabled");
  }
}

function makeMove(e) {

  e.preventDefault();
  
  // It's not your turn
  if (!myTurn) {
    return;
  }
  
  // The space is already checked
  if ($(this).text().length) {
    return;
  }
  

  let position = $(this).attr("id")
  
  let index;
  if(position == "a0") {
    index = 0
  } else if(position == "a1") {
    index = 1
  } else if(position == "a2") {
    index = 2
  } else if(position == "b0") {
    index = 3
  } else if(position == "b1") {
    index = 4
  } else if(position == "b2") {
    index = 5
  } else if(position == "c0") {
    index = 6
  } else if(position == "c1") {
    index = 7
  } else if(position == "c2") {
    index = 8
  } else {
    alert("can't recognise move position")
  }

  let player = symbol == "X" ? 1 : 2
  board[index] = player

  // TODO: add matchId to stateroot
  let gameStatus = 0
  let stateRoot = newWeb3.utils.sha3(newWeb3.eth.abi.encodeParameters(
    ["uint8[9]", "uint8", "uint256"], [board, gameStatus, nonce]
  ))
  
  signState(stateRoot, account, function(signature){
    // Emit the move to the server
    socket.emit("make.move", {
      symbol: symbol,
      position: position
    });
    // send signature of state
    socket.emit("send.signature", {
      sender: account,
      signature: signature,
      nonce: nonce
    });
  })
}

function signState(stateRoot, signer, callback) {
  newWeb3.eth.sign(stateRoot, signer, function(err, signature) {
    if(err) alert(err)
    else {
      callback(signature)
    }
  })
}

function countMovesMade() {
  let moves = 0
  for(let cell of board) if(cell != 0) moves++
  return moves
}

// Event is called when either player makes a move
socket.on("move.made", function(data) {
  // Render the move
  $("#" + data.position).text(data.symbol);
  nonce = countMovesMade()

  // if player 1 or 2
  let player = data.symbol == "X" ? 1 : 2

  let index;
  if(data.position == "a0") {
    index = 0
  } else if(data.position == "a1") {
    index = 1
  } else if(data.position == "a2") {
    index = 2
  } else if(data.position == "b0") {
    index = 3
  } else if(data.position == "b1") {
    index = 4
  } else if(data.position == "b2") {
    index = 5
  } else if(data.position == "c0") {
    index = 6
  } else if(data.position == "c1") {
    index = 7
  } else if(data.position == "c2") {
    index = 8
  } else {
    alert("can't recognise move position")
  }

  board[index] = player

  // If the symbol is the same as the player's symbol,
  // we can assume it is their turn
  myTurn = data.symbol !== symbol;

  // if it is my turn, opponent just moved
  if(myTurn) {
    let gameStatus = 0

    // state root of nonce-1 because you are signing the previous move
    let stateRoot = newWeb3.utils.sha3(newWeb3.eth.abi.encodeParameters(
      ["uint8[9]", "uint8", "uint256"], [board, gameStatus, nonce-1]
    ))

    signState(stateRoot, account, function(signature){
      // Emit the move to the server
      socket.emit("send.signature", {
        sender: account,
        signature: signature,
        nonce: nonce
      });
    })
  }

  // If the game is still going, show who's turn it is
  if (!isGameOver()) {
    renderTurnMessage();

    // If the game is over
  } else {
    // Show the message for the loser
    if (myTurn) {
      $("#messages").text("Game over. You lost.");

      // Show the message for the winner
    } else {
      $("#messages").text("Game over. You won!");
    }

    // Disable the board
    $(".board button").attr("disabled", true);
  }
});

// Set up the initial state when the game begins
socket.on("game.begin", function(data) {
  // The server will asign X or O to the player
  symbol = data.symbol;

  // Give X the first turn
  myTurn = symbol === "X";

  if(myTurn) {
    $.getJSON("TicTacToe.json", function(json) {
      contractAbi = json.abi
      TicTacToe = new newWeb3.eth.Contract(contractAbi, contractAddress);

      // TicTacToe.methods.startMatch("0xb286B84be7B9A04027a145B3A7e455D850a75884", 2000).send(
      //   {from: "0x24cDb6A9b504EC3E1394a0b0c2c751D28959bA29"}
      // ).then(
      //   function(receipt) {
      //     console.log(receipt)
      //   }
      // )

    });

    $("#messages").text("Waiting for state channel to be created");
    $(".board button").attr("disabled", true);
    
    // start match on chain
    $(".board button").removeAttr("disabled");

  } else {
    $("#messages").text("Waiting for opponent to initiate state channel");
    $(".board button").attr("disabled", true);
  }

  // renderTurnMessage();
});

socket.on("send.signature", function(data) {
  // save other parties signature together with your own
  // signatures[data.nonce] = [data.signature]
  console.log("heeere")
  console.log(data)
})

// Disable the board if the opponent leaves
socket.on("opponent.left", function() {
  $("#messages").text("Your opponent left the game.");
  $(".board button").attr("disabled", true);
});

$(function() {
  $(".board button").attr("disabled", true);
  $(".board> button").on("click", makeMove);
});
