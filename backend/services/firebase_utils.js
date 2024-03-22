require("firebase/analytics");
require("firebase/database");
const Game = require("../game/game");
const Player = require("../game/player");

// Initialize Firebase
var admin = require("firebase-admin");

var serviceAccount = require("/Users/dominiqueadevai/Desktop/carnivore-5397b-066c626789eb.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://carnivore-5397b-default-rtdb.firebaseio.com",
});
const db = admin.database();

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyCMNh6bt6575uIlVDE9mhThk7Jlw9rtYs8",
  authDomain: "carnivore-5397b.firebaseapp.com",
  projectId: "carnivore-5397b",
  storageBucket: "carnivore-5397b.appspot.com",
  messagingSenderId: "133326456900",
  appId: "1:133326456900:web:7e530dcfbea2922c5f5411",
  measurementId: "G-MT1L5MR87P",
};

async function verifyToken(token) {
  return admin
    .auth()
    .verifyIdToken(token)
    .then((decodedToken) => {
      const userId = decodedToken.uid;
      return userId;
    })
    .catch((error) => {
      throw error; // Allow the caller to handle the error
    });
}

async function writePlayerData(player) {
  // Update game in firebase (add the new player specifically)
  const playerRef = admin
    .database()
    .ref(`games/${player.gameId}/players/${player.playerId}`);
  await playerRef.set({
    gameId: player.gameId,
    words: [""],
    score: 0,
    turn: false,
  });
}

async function writeGameData(game) {
  const updates = {};
  if (game.players != null) {
    // Players
    game.players.forEach(async (player) => {
      await writePlayerData(player);
    });
  }

  // Remaining Letters and Tiles
  updates[`games/${game.gameId}/remainingLetters`] = game.remainingLetters;
  updates[`games/${game.gameId}/tiles`] = game.tiles;

  await admin
    .database()
    .ref()
    .update(updates) // Perform all updates in one transaction
    .then(() => {
      console.log("Data created successfully in realtime db!");
    })
    .catch((error) => {
      console.log("Error trying to write to a new game table = ", error);
      throw new Error();
    });
}

async function getPlayer(gameId, playerId) {
  const firebaseGamePull = await admin
    .database()
    .ref(`games/${gameId}/players/${playerId}`)
    .once("value");
  const firebasePlayer = firebaseGamePull.val().players[playerId];
  console.log("{firebaseUtils} firebasePlayer=", firebasePlayer);
  const playerObj = new Player(playerId, gameId);
  return playerObj;
}

function createPlayersFromFirebaseData(data) {
  const players = [];
  for (const playerId in data) {
    if (data.hasOwnProperty(playerId)) {
      const playerData = { [playerId]: data[playerId] };
      const player = createPlayerFromFirebaseData(playerData);
      players.push(player);
    }
  }
  return players;
}

async function getGame(gameId) {
  const firebaseGamePull = await admin
    .database()
    .ref(`games/${gameId}`)
    .once("value");
  const firebaseGame = firebaseGamePull.val();
  let playerObjs = createPlayersFromFirebaseData(firebaseGame.players);
  const gameObj = new Game();
  gameObj.gameId = gameId;
  gameObj.remainingLetters = firebaseGame.remainingLetters;
  gameObj.tiles = firebaseGame.tiles;
  gameObj.players = playerObjs;
  return gameObj;
}

async function getTile(gameId, tileId) {
  const gameSnapshot = await admin
    .database()
    .ref(`games/${gameId}`)
    .once("value");
  return gameSnapshot.val().tiles[tileId];
}

async function updateTile(gameId, tile) {
  const updateData = { ...tile };
  return admin
    .database()
    .ref(`games/${gameId}/tiles/${tile.tileId}`)
    .update(updateData);
}

async function updateGameData(gameId, gameDataUpdates) {
  return admin.database().ref(`games/${gameId}`).update(gameDataUpdates);
}

module.exports = {
  writeGameData,
  updateGameData,
  verifyToken,
  updateTile,
  getTile,
  getGame,
};
