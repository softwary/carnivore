
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries
// const Game = require("../game/game"); 
// import Game from '../game/game';

require('firebase/analytics');
require('firebase/database');

// Initialize Firebase
var admin = require("firebase-admin");

var serviceAccount = require("/Users/dominiqueadevai/Desktop/carnivore-5397b-066c626789eb.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://carnivore-5397b-default-rtdb.firebaseio.com"
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
  measurementId: "G-MT1L5MR87P"
};

async function verifyToken(token) {
  console.log(`In firebaseUtils.verifyToken(), token=' ${token}`);
  return admin.auth().verifyIdToken(token)
    .then((decodedToken) => {
      const userId = decodedToken.uid;
      return userId; 
    })
    .catch((error) => {
      throw error; // Allow the caller to handle the error 
    });
}

async function writeToDatabase(table, dataToWrite) {
  console.log("in writeToDatabase typeOf table= ", typeof(table));
  console.log("in writeToDatabase typeOf dataToWrite= ", typeof(dataToWrite));
  const ref = db.ref(table);
  ref.set(dataToWrite).then(() => {
    console.log(`in writeToDatabase - Data created successfully in realtime db!' ${dataToWrite}`);
    return;
  }).catch((error) => {
    console.log("in writeToDatabase, there was an error trying to write to a new game table = ");
    throw new Error
});
}

async function writeGameData(gameObject) {
  // console.log(`in writeGameData() gameObject=`, gameObject.gameId, gameObject.playerIds, gameObject.remainingLetters.length,gameObject.tiles.length);
  const gameId = gameObject.gameId;
  const table = "games/" + gameId
  await writeToDatabase(table, gameObject);
}

// async function createNodeIfNeeded(table) {
//   console.log("in createNodeIfNeeded")
//   const gamesRef = db.ref(table);

//   try {
//     const snapshot = await gamesRef.once('value'); // Read data from 'games' node
//     if (!snapshot.exists()) {
//       console.log(`${table} node does not exist. Creating it...`);
//       await gamesRef.set({ test: "hi" });
//       console.log(`${table} node created!`);
//     } else {
//       console.log(`${table} node already exists.`);
//     }
//   } catch (error) {
//     console.error(`Error checking for ${table} node existence:`, error);
//   }
// }


module.exports = { writeGameData, writeToDatabase, verifyToken }