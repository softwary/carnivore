const Player = require("../game/player");
const { writeToFirebase } = require("./firebase_utils");

function createPlayer(username, ws, uid) {
  const newPlayer = new Player(username, ws, uid);
  //   writeToFirebase(`player/${newGame.gameId}`, newGame.toFirebaseData());
  return newPlayer;
}

// Other game related functions (joinGame, flipTile, submitWord)

module.exports = { createPlayer /*... other game functions */ };
