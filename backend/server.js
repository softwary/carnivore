const express = require("express");
const http = require("http");
const WebSocket = require("ws");
const firebaseUtils = require("./services/firebase_utils");
var admin = require("firebase-admin");
const Game = require("./game/game");
const Player = require("./game/player");
const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });


const gamePlayerWebSockets = new Map();

/**
 * Broadcasts a message to all connected players of a specific game.
 * This function iterates over WebSocket connections associated with a game ID and sends a message
 * if the WebSocket connection is still open.
 *
 * @param {string} gameId - The ID of the game whose players will receive the message.
 * @param {Object} message - The message object to be sent to all players. This object should be
 *                           serializable to JSON.
 *
 * @description
 * - Retrieves the list of WebSocket connections for the given game ID from `gamePlayerWebSockets`.
 * - Iterates over each WebSocket connection, checks if it's still open (readyState === OPEN),
 *   and sends the serialized message to each connected player.
 * - Logs the message type being broadcasted to help with debugging and monitoring.
 */
function broadcastMessageToPlayers(gameId, message) {
  if (gamePlayerWebSockets.has(gameId)) {
    const playersWebSockets = gamePlayerWebSockets.get(gameId);
    playersWebSockets.forEach((ws) => {
      if (ws.readyState === WebSocket.OPEN) {
        // Check if the WebSocket is still open
        ws.send(JSON.stringify(message));
        console.log("📤 Broadcasted message to all players", message.type);
      }
    });
  }
}

/**
 * Converts a Map of flipped letters with their counts into a flat array where each letter appears
 * as many times as its count. This format is more suitable for frontend usage where a simple list
 * of letters may be needed rather than a count-based map.
 *
 * @param {Map<string, number>} flippedLettersMap - A Map where keys are letters and values are the counts
 *                                                  of how many times these letters have been flipped.
 * @returns {Array<string>} An array of letters, each appearing as many times as it has been flipped.
 *
 * @description
 * This function is particularly useful for preparing data to be sent to a frontend application
 * where the representation of multiple instances of the same data (letters in this case) is required
 * in a simple array format. It iterates over the map entries and populates an array with each letter
 * repeated according to its count in the map.
 */
function prepareFlippedLettersForFrontEnd(flippedLettersMap) {
  const flippedLetters = []; // Use an array directly

  // Iterate directly over map entries:
  for (const [letter, count] of flippedLettersMap.entries()) {
    for (let i = 0; i < count; i++) {
      flippedLetters.push(letter);
    }
  }
  return flippedLetters;
}

/**
 * Retrieves the game ID associated with a user based on the user's ID. This function searches through
 * a map of game IDs to player WebSocket collections, returning the game ID where the user is currently
 * a player.
 *
 * @param {string} userId - The user ID for which the game ID needs to be found.
 * @returns {string|null} The game ID in which the user is a player, or null if the user is not part of any game.
 *
 * @description
 * - Iterates over the `gamePlayerWebSockets` map which associates game IDs with a set of user WebSockets.
 * - Checks each entry to see if the user ID exists in the set of player WebSockets.
 * - Returns the corresponding game ID if found; otherwise, returns null to indicate the user is not part
 *   of any active game.
 */
function getGameIdByUserId(userId) {
  for (const [gameId, playerWebSockets] of gamePlayerWebSockets.entries()) {
    if (playerWebSockets.has(userId)) {
      return gameId;
    }
  }
  return null; // Handle case where the user is not in any active game
}

wss.on("connection", (ws, req) => {
  console.log("✅ Connected!");
  ws.on("message", async (message) => {
    try {
      const { type, data } = JSON.parse(message);
      console.log("# Received: %s", message);
      console.log(`type = ${type}`);
      console.log(`data =`, data);
      if (data && data.idToken) {
        const userId = await firebaseUtils.verifyToken(data.idToken);
        console.log(`userId = ${userId}`);
        ws.userId = userId;
        // Handle all requests since the user is authenticated
        switch (type) {
          // User wants to Create a Game
          case "createGame":
            let newGame = new Game();
            // Create a new player object
            let newPlayer = new Player(userId, newGame.gameId);
            // Add the first player to the gamer(newPlayer);
            newGame.addPlayer(newPlayer);
            // Make it this player's turn
            newGame.setTurnToPlayer(newPlayer);
            await firebaseUtils.writeGameData(newGame);
            // Add WebSocket to the map
            if (!gamePlayerWebSockets.has(newGame.gameId)) {
              gamePlayerWebSockets.set(newGame.gameId, new Map());
            }
            gamePlayerWebSockets.get(newGame.gameId).set(userId, ws);
            const newGameCreatedMessage = {
              type: "newGame",
              data: newGame,
            };
            ws.send(JSON.stringify(newGameCreatedMessage));
            break;
          case "joinGame":
            try {
              const gameId = data.gameId;
              // 1. Validate Game
              const game = await firebaseUtils.getGame(gameId);
              if (!game) {
                const gameToJoinDoesNotExistMessage = {
                  type: "doesNotExist",
                  data: "",
                };
                broadcastMessageToPlayers(
                  gameId,
                  gameToJoinDoesNotExistMessage
                );
                throw new Error(`❌ Game with ID ${gameId} does not exist.`);
              }
              // Create a new player object since game exists
              let joiningPlayer = new Player(userId, gameId);
              // Update game object to have the user in this game now
              game.addPlayer(joiningPlayer);
              // Add WebSocket to the map
              if (!gamePlayerWebSockets.has(gameId)) {
                gamePlayerWebSockets.set(gameId, new Map());
              }
              gamePlayerWebSockets.get(gameId).set(userId, ws);
              // Update game in firebase
              await firebaseUtils.writeGameData(game);
              // Retrieve updated game data
              const updatedGame = await firebaseUtils.getGame(gameId);

              updatedGame.flippedLetters = prepareFlippedLettersForFrontEnd(updatedGame.flippedLetters);
              const gameJoinedInfoMessage = {
                type: "gameJoined",
                data: updatedGame,
              };
              broadcastMessageToPlayers(gameId, gameJoinedInfoMessage);
            } catch (error) {
              console.log("❌ Some kind of error?", error);
            }
            break;
          case "flipTile":
            let flipTileGameId = data.gameId;
            if (flipTileGameId) {
              const gameToUpdateTileIn = await firebaseUtils.getGame(flipTileGameId);
              if (!gameToUpdateTileIn) {
                throw new Error(`❌ Game with ID ${flipTileGameId} does not exist.`);
              }

              // Check if it is this player's turn
              else if (gameToUpdateTileIn.isItThisPlayersTurn(userId)) {
                try {
                  const tileToUpdate = gameToUpdateTileIn.flipTile();
                  // Make it the next player's turn
                  gameToUpdateTileIn.advanceTurnToNextPlayer();
                  if (!tileToUpdate) {
                    throw new Error(
                      `❌ Tile ${tileToUpdate.tileId} is invalid. tile=${tileToUpdate}`
                    );
                  }
                  await firebaseUtils.updateTile(
                    flipTileGameId,
                    tileToUpdate
                  );
                  await firebaseUtils.updateFlippedLetters(
                    flipTileGameId,
                    tileToUpdate
                  );
                  await firebaseUtils.updateRemainingLetters(flipTileGameId, gameToUpdateTileIn.remainingLetters);
                  await firebaseUtils.writeGameData(gameToUpdateTileIn);
                  const gameWithUpdatedTile = await firebaseUtils.getGame(flipTileGameId);
                  gameWithUpdatedTile.flippedLetters = prepareFlippedLettersForFrontEnd(gameWithUpdatedTile.flippedLetters);
                  const tileUpdateMessage = {
                    type: "tileUpdate",
                    data: gameWithUpdatedTile,
                  }
                  broadcastMessageToPlayers(flipTileGameId, tileUpdateMessage);
                } catch (error) {
                  console.error(`❌ Error flipping tile: ${error.message}`);
                  ws.send(JSON.stringify({ type: "error", data: error.message }));
                }
              } else {
                throw new Error(
                  `❌ it is not this player's turn, so they cannot flip a tile!`
                )
              }
            }
            break;
          case "submitWord":
            if (data.word) {
              var word = data.word.toUpperCase();
            } else {
              throw new Error(
                `❌ Word was not submitted in the data object.`
              );
            }
            const gameId = getGameIdByUserId(userId);
            const gameToSubmitWord = await firebaseUtils.getGame(gameId);

            if (!gameToSubmitWord) {
              throw new Error(
                `❌ Game with ID ${gameToSubmitWord.gameId} does not exist.`
              );
            }

            const playerThatSubmittedWord = gameToSubmitWord.getPlayerById(userId);

            if (!playerThatSubmittedWord) {
              throw new Error(
                `❌ Player with ID ${userId} does not exist.`
              );
            }

            let gameWithWordSubmitted = gameToSubmitWord.handleWordSubmission(
              playerThatSubmittedWord,
              word
            );
            if (gameWithWordSubmitted) {
              await firebaseUtils.writeGameData(gameWithWordSubmitted);
              // Retrieve updated game data
              const gameWithWordSubmittedInFirebase = await firebaseUtils.getGame(
                gameId
              );

              gameWithWordSubmittedInFirebase.flippedLetters = prepareFlippedLettersForFrontEnd(gameWithWordSubmittedInFirebase.flippedLetters);
              const gameUpdatedWordsMessage = {
                type: "gameWithWord",
                data: gameWithWordSubmittedInFirebase,
              };
              broadcastMessageToPlayers(gameId, gameUpdatedWordsMessage);
            }
            break;
          default:
            console.log("❌ # Error - Check message frontend is sending");
        }
      } else {
        // Handle the case where idToken is missing
        console.error("❌ Missing idToken in the message data");
        ws.send(JSON.stringify({ type: "error", data: "Missing idToken" }));
      }
    } catch (error) {
      console.error("❌ Authentication or message processing failed:", error);
      ws.send(JSON.stringify({ type: "error", data: "Authentication error" }));
    }
  });
});

const PORT = 3000;
// Example for an Express server
server.listen(PORT, "0.0.0.0", () => {
  console.log(`Server is running on http://0.0.0.0:${PORT}`);
});
