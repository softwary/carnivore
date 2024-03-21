// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries
// const Game = require("../game/game");
// import Game from '../game/game';

require("firebase/analytics");
require("firebase/database");
const Game = require("../game/game");

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
  // console.log(`In firebaseUtils.verifyToken(), token=' ${token}`);
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

async function writeGameData(game) {
  await admin
    .database()
    .ref(`games/${game.gameId}`)
    .set({
      playerIds: game.playerIds,
      remainingLetters: game.remainingLetters,
      tiles: game.tiles,
    })
    .then(() => {
      console.log(
        "in firebase_utils(game) - Data created successfully in realtime db!",
        game
      );
      return;
    })
    .catch((error) => {
      console.log(
        "in firebase_utils(game), there was an error trying to write to a new game table = ",
        error
      );
      throw new Error();
    });
}

async function getGame(gameId) {
  const firebaseGamePull = await admin
    .database()
    .ref(`games/${gameId}`)
    .once("value");
  const firebaseGame = firebaseGamePull.val();
  const gameObj = new Game(firebaseGame.playerIds);
  gameObj.gameId = gameId;
  gameObj.remainingLetters = firebaseGame.remainingLetters;
  gameObj.tiles = firebaseGame.tiles;
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
