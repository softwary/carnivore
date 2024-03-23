require("firebase/analytics");
require("firebase/database");
const Game = require("../game/game");
const Tile = require("../game/tile");
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

async function writeTileData(gameId, tile) {
  const playerRef = admin
    .database()
    .ref(`games/${gameId}/tiles/${tile.tileId}`);
  await playerRef.set({
    inMiddle: tile.inMiddle,
    isFlipped: tile.isFlipped,
    letter: tile.letter,
  });
}
async function writePlayerData(player) {
  const playerRef = admin
    .database()
    .ref(`games/${player.gameId}/players/${player.playerId}`);
  await playerRef.set({
    gameId: player.gameId,
    words: player.words,
    score: player.score,
    turn: player.turn,
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
  // Tiles
  game.tiles.forEach(async (tile) => {
    await writeTileData(game.gameId, tile);
  });

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
  console.log(
    "{firebaseUtils} in getPlayer gameId=",
    gameId,
    " playerId=",
    playerId
  );
  const firebaseGamePull = await admin
    .database()
    .ref(`games/${gameId}/players/${playerId}`)
    .once("value");
  const firebasePlayer = firebaseGamePull.val();
  // console.log("{firebaseUtils} in getPlayer() firebasePlayer=", firebasePlayer);
  // Create a Player object directly
  const playerObj = createPlayerFromFirebaseData(firebasePlayer);
  return playerObj;
}

function createPlayerFromFirebaseData(firebasePlayerObj) {
  // Extract the playerId from the Firebase object's key
  const playerId = Object.keys(firebasePlayerObj)[0];

  // Destructure the data from the nested object
  const { gameId, score, turn, words } = firebasePlayerObj[playerId];

  // Create a new Player object
  const player = new Player(playerId, gameId);

  // Assign the properties from the Firebase data
  player.score = score;
  player.turn = turn;
  player.words = words || [];

  return player;
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

// Tiles
function createTileFromFirebaseData(firebaseTileObj) {
  // Extract the tileId from the Firebase object's key
  const tileId = Object.keys(firebaseTileObj)[0];

  // Destructure the data from the nested object
  const { letter, isFlipped, inMiddle } = firebaseTileObj[tileId];

  // Create a new Tile object
  const tile = new Tile(tileId, isFlipped, inMiddle);

  // Assign the properties from the Firebase data
  tile.letter = letter;
  tile.isFlipped = isFlipped;
  tile.inMiddle = inMiddle;

  return tile;
}

function createTilesFromFirebaseData(data) {
  const tiles = [];
  for (const tileId in data) {
    if (data.hasOwnProperty(tileId)) {
      const tileData = { [tileId]: data[tileId] };
      const tile = createTileFromFirebaseData(tileData);
      tiles.push(tile);
    }
  }
  return tiles;
}

// Get Game from Firebase and return it as a Game object
async function getGame(gameId) {
  const firebaseGamePull = await admin
    .database()
    .ref(`games/${gameId}`)
    .once("value");
  const firebaseGame = firebaseGamePull.val();
  const gameObj = new Game();
  gameObj.gameId = gameId;
  gameObj.remainingLetters = firebaseGame.remainingLetters;
  let tileObjs = createTilesFromFirebaseData(firebaseGame.tiles);
  gameObj.tiles = tileObjs;
  let playerObjs = createPlayersFromFirebaseData(firebaseGame.players);
  gameObj.players = playerObjs;
  return gameObj;
}

// Get Tile from Firebase and return it as a Tile object
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
  getPlayer,
  getGame,
};
