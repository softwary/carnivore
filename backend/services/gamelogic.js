const Game = require("../game/game"); 
const Tile = require("../game/tile"); 

const firebaseUtils = require("./firebase_utils");

function createGame(playerData) {
  const newGame = new Game(playerData);
  return newGame;
}

function flipTile(game, tile) {
  if (tile && !tile.isFlipped) {
      game.assignLetterToTile(tile);
      tile.flip();
      return { ...tile};
  } 
}

module.exports = { createGame, flipTile/*... other game functions */ };