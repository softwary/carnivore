require("firebase/analytics");
require("firebase/database");
const Game = require("../game/game");
const Tile = require("../game/tile");
const Player = require("../game/player");

// Initialize Firebase
var admin = require("firebase-admin");

var serviceAccount = require("/Users/nikki/Documents/carnivore-5397b-066c626789eb.json");
// var serviceAccount = require("/Users/dominiqueadevai/Desktop/carnivore-5397b-066c626789eb.json");


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

/**
 * Verifies a Firebase ID token and returns the associated user's UID.
 * 
 * @param {string} token - The Firebase ID token to verify.
 * @returns {Promise<string>} A promise that resolves with the user's UID if verification is successful.
 * @throws Will throw an error if the token verification fails.
 */
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

/**
 * Writes player data to Firebase Realtime Database under the specific game ID and player ID.
 * Updates only the fields that are not undefined in the player object.
 *
 * @param {Player} player - The player object containing data to write to Firebase.
 * @returns {Promise<void>} A promise that resolves when the data has been successfully written.
 */
async function writePlayerData(player) {
  const playerRef = admin
    .database()
    .ref(`games/${player.gameId}/players/${player.playerId}`);

  const updateData = {}; // Object to hold properties to update
  if (player.gameId !== undefined) {
    updateData.gameId = player.gameId;
  }
  if (player.wordSignatures !== undefined) {
    updateData.wordSignatures = player.wordSignatures;
  }
  if (player.words !== undefined) {
    updateData.words = player.words;
  }
  if (player.score !== undefined) {
    updateData.score = player.score;
  }
  if (player.turn !== undefined) {
    updateData.turn = player.turn;
  }

  await playerRef.update(updateData);
}

/**
 * Writes game data to Firebase Realtime Database, including player data, flipped letters,
 * remaining letters, and tiles for a specified game.
 *
 * @param {Game} game - The game object containing all game data to write.
 * @returns {Promise<void>} A promise that resolves when the data has been successfully updated.
 */
async function writeGameData(game) {
  const updates = {};
  if (game.players != null) {
    // Players
    game.players.forEach(async (player) => {
      await writePlayerData(player);
    });
  }

  // Convert flippedLetters Map to an object correctly
  const flippedLettersObject = {};
  if (game.flippedLetters instanceof Map) {
    game.flippedLetters.forEach((value, key) => {
      flippedLettersObject[key] = value;
    });
  }
  updates[`games/${game.gameId}/flippedLetters`] = flippedLettersObject;

  // Remaining Letters and Tiles
  updates[`games/${game.gameId}/remainingLetters`] = game.remainingLetters;
  // Tiles
  updates[`games/${game.gameId}/tiles`] = game.tiles;

  await admin
    .database()
    .ref()
    .update(updates) // Perform all updates in one transaction
    .then(() => {
      console.log("🔥🔥🔥🔥🔥🔥Data created successfully in realtime db!🔥🔥🔥🔥🔥🔥 flippedLettersObject= ", flippedLettersObject);
    })
    .catch((error) => {
      console.log("Error trying to write to a new game table = ", error);
      throw new Error();
    });
}

/**
 * Retrieves a player object from Firebase Realtime Database using the provided game ID and player ID.
 *
 * @param {string} gameId - The ID of the game.
 * @param {string} playerId - The ID of the player to retrieve.
 * @returns {Promise<Player>} A promise that resolves with the player object retrieved from Firebase.
 */
async function getPlayer(gameId, playerId) {
  const firebaseGamePull = await admin
    .database()
    .ref(`games/${gameId}/players/${playerId}`)
    .once("value");
  const firebasePlayer = firebaseGamePull.val();
  // Create a Player object directly
  const playerObj = createPlayerFromFirebaseData(firebasePlayer);
  return playerObj;
}

/**
 * Creates a Player object from a Firebase data snapshot of a player.
 * This function assumes that the Firebase data object contains a single key-value pair
 * where the key is the playerId and the value is an object with the player's properties.
 *
 * @param {Object} firebasePlayerObj - The object containing the Firebase data for the player.
 * @returns {Player} A new Player object created from the Firebase data.
 *
 * @description
 * The function extracts the playerId from the object's keys and then accesses the player's properties:
 * - gameId: The ID of the game the player is participating in.
 * - score: The current score of the player.
 * - turn: Boolean indicating if it is the player's turn.
 * - words: Array of words currently held by the player.
 * - wordSignatures: Array of signatures corresponding to each word.
 * It then creates a new Player instance with these properties and any additional default settings,
 * returning the fully initialized player.
 */
function createPlayerFromFirebaseData(firebasePlayerObj) {
  // Extract the playerId from the Firebase object's key
  const playerId = Object.keys(firebasePlayerObj)[0];

  // Destructure the data from the nested object
  const { gameId, score, turn, words, wordSignatures } = firebasePlayerObj[playerId];

  // Create a new Player object
  const player = new Player(playerId, gameId);

  // Assign the properties from the Firebase data
  player.score = score;
  player.turn = turn;
  player.words = words || [];
  player.wordSignatures = wordSignatures || [];

  return player;
}

/**
 * Generates an array of Player objects from a collection of Firebase player data.
 * Iterates over each key-value pair in the provided data object, converting each to a Player object.
 *
 * @param {Object} data - The object containing multiple Firebase player data entries. 
 *                        Each entry's key is assumed to be the playerId and the value is the player's properties.
 * @returns {Array<Player>} An array of Player objects created from the Firebase data.
 *
 * @description
 * This function goes through each entry in the provided object, which should represent all players
 * within a specific game or context. It utilizes `createPlayerFromFirebaseData` to convert each
 * data entry into a Player object and accumulates them into an array. This ensures that each player's
 * properties are accurately transferred from the Firebase format to the Player object format.
 * It is particularly useful for initializing game states where multiple players need to be generated
 * from persistent storage data.
 */
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

/**
 * Constructs a Tile object from a Firebase data snapshot of a tile.
 * This function assumes that the Firebase data object contains a single key-value pair
 * where the key is the tileId and the value is an object with the tile's properties.
 *
 * @param {Object} firebaseTileObj - The object containing the Firebase data for the tile.
 * @returns {Tile} A new Tile object created from the Firebase data.
 *
 * @description
 * The function extracts the tileId from the object's keys and then accesses the tile's properties:
 * - letter: The character on the tile.
 * - isFlipped: Boolean indicating if the tile is flipped.
 * - inMiddle: Boolean indicating if the tile is placed in the middle of the game area.
 * It then creates a new Tile instance with these properties, returning the fully initialized tile.
 */
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

/**
 * Converts a raw data object from Firebase into an array of Tile objects.
 * This function iterates over each key-value pair in the provided data object,
 * where each key is assumed to be a tileId and the value contains properties of the tile.
 *
 * @param {Object} data - The object containing key-value pairs of tile data retrieved from Firebase.
 *                        Each key is a tileId with its value being an object containing the tile's properties.
 * @returns {Array<Tile>} An array of Tile objects, each constructed from the Firebase data.
 *
 * @description
 * The function traverses each entry in the provided data object, assumed to represent tiles
 * in a game or other application context. For each entry, it uses `createTileFromFirebaseData`
 * to transform the key-value pair into a Tile object, which is then added to the resultant array.
 * This approach is useful for initializing or updating game states where tile data is stored
 * in a backend database and needs to be instantiated into game entities.
 */
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

/**
 * Retrieves game data from Firebase Realtime Database and constructs a game object with that data.
 *
 * @param {string} gameId - The ID of the game to retrieve.
 * @returns {Promise<Game>} A promise that resolves with the fully constructed game object.
 */
async function getGame(gameId) {
  const firebaseGamePull = await admin
    .database()
    .ref(`games/${gameId}`)
    .once("value");
  const firebaseGame = firebaseGamePull.val();
  const gameObj = new Game();
  gameObj.gameId = gameId;
  gameObj.remainingLetters = firebaseGame.remainingLetters;
  // Correcting the way flippedLetters are reconstituted from Firebase
  if (firebaseGame.flippedLetters) {
    gameObj.flippedLetters = new Map();
    Object.entries(firebaseGame.flippedLetters).forEach(([key, value]) => {
      gameObj.flippedLetters.set(key, Number(value)); // Ensure the value is treated as a number
    });
  } else {
    gameObj.flippedLetters = new Map(); // Ensure flippedLetters is always a Map even if empty
  }
  let tileObjs = createTilesFromFirebaseData(firebaseGame.tiles);
  gameObj.tiles = tileObjs;
  let playerObjs = createPlayersFromFirebaseData(firebaseGame.players);
  gameObj.players = playerObjs;

  return gameObj;
}

/**
 * Retrieves a tile object from Firebase Realtime Database using the game ID and tile ID.
 *
 * @param {string} gameId - The ID of the game containing the tile.
 * @param {string} tileId - The ID of the tile to retrieve.
 * @returns {Promise<Tile>} A promise that resolves with the tile object retrieved from Firebase.
 */
async function getTile(gameId, tileId) {
  const gameSnapshot = await admin
    .database()
    .ref(`games/${gameId}`)
    .once("value");
  return gameSnapshot.val().tiles[tileId];
}

/**
 * Updates tile data in Firebase Realtime Database for a specified tile within a game.
 *
 * @param {string} gameId - The ID of the game containing the tile.
 * @param {Tile} tile - The tile object containing updated data.
 * @returns {Promise<void>} A promise that resolves when the tile data has been successfully updated.
 */
async function updateTile(gameId, tile) {
  const updateData = { ...tile };
  return admin
    .database()
    .ref(`games/${gameId}/tiles/${tile.tileId}`)
    .update(updateData);
}

/**
 * Updates the remaining letters data in Firebase Realtime Database for a specified game.
 *
 * @param {string} gameId - The ID of the game for which to update remaining letters.
 * @param {Object} remainingLetters - An object containing the counts of remaining letters to update.
 * @returns {Promise<void>} A promise that resolves when the remaining letters data has been successfully updated.
 */
async function updateRemainingLetters(gameId, remainingLetters) {
  updates = {};
  updates[`games/${gameId}/remainingLetters`] = remainingLetters;

  await admin
    .database()
    .ref()
    .update(updates) // Perform all updates in one transaction
    .then(() => {
    })
    .catch((error) => {
      throw new Error();
    });
}

/**
 * Updates flipped letters data in Firebase Realtime Database for a specified game.
 *
 * @param {string} gameId - The ID of the game.
 * @param {Tile} tile - The tile object from which to derive the flipped letter update.
 * @returns {Promise<void>} A promise that resolves when the flipped letters data has been successfully updated.
 */
async function updateFlippedLetters(gameId, tile) {
  const updateData = { ...tile.letter };

  return admin
    .database()
    .ref(`games/${gameId}/flippedLetters/${tile.letter}`)
    .update(updateData);
}

module.exports = {
  writeGameData,
  updateFlippedLetters,
  updateRemainingLetters,
  verifyToken,
  updateTile,
  getTile,
  getPlayer,
  getGame,
};
