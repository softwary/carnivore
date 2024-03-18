const Game = require("../game/game"); 
// const { writeToFirebase, updateFirebase, writeGameData } = require("./firebase_utils");

const firebaseUtils = require("./firebase_utils");

function createGame(playerData) {
  const newGame = new Game(playerData);
  // console.log("in gameLogic, what is newGame?=", newGame);
  return newGame;
}

// Other game related functions (joinGame, flipTile, submitWord)

module.exports = { createGame, /*... other game functions */ };