const Player = require("../game/player");
const { writeToFirebase } = require("./firebase_utils");

function createPlayer(userId, gameId) {
  const newPlayer = new Player(userId, gameId);
  //   writeToFirebase(`player/${newGame.gameId}`, newGame.toFirebaseData());
  return newPlayer;
}

// Other game related functions (joinGame, flipTile, submitWord)

module.exports = { createPlayer /*... other game functions */ };
