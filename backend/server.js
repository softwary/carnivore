const express = require("express");
const http = require("http");
const WebSocket = require("ws");
const url = require("url");
const firebaseUtils = require("./services/firebase_utils");
var admin = require("firebase-admin");
const Game = require("./game/game");
const Tile = require("./game/tile");
const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const gameLogic = require("./services/gamelogic");
const playerLogic = require("./services/playerlogic");

function cl() {
  console.log(" ..... ");
  console.log(" ..... ");
}
function broadcastMessageToPlayers(gameId, message) {
  console.log("📤 broadcasted this message:", message);
  if (gamePlayerWebSockets.has(gameId)) {
    const playersWebSockets = gamePlayerWebSockets.get(gameId);
    playersWebSockets.forEach((ws) => {
      if (ws.readyState === WebSocket.OPEN) {
        // Check if the WebSocket is still open
        ws.send(JSON.stringify(message));
      }
    });
  }
}
const gamePlayerWebSockets = new Map();

let wsConnections = [];

wss.on("connection", (ws, req) => {
  console.log("✅ Connected!");
  // Proceed with handling messages from this authenticated user
  ws.on("message", async (message) => {
    try {
      const { type, data } = JSON.parse(message);
      console.log("# Received: %s", message);
      cl();
      console.log(`type = ${type}`);
      console.log(`data =`, data);
      if (data && data.idToken) {
        const userId = await firebaseUtils.verifyToken(data.idToken);
        cl();
        console.log(`userId = ${userId}`);
        cl();
        ws.userId = userId;
        wsConnections.push(ws);
        // Handle all requests since the user is authenticated
        switch (type) {
          // User wants to Create a Game
          case "createGame":
            // Create a new player object
            let newPlayer = playerLogic.createPlayer(userId, ws);
            let newGame = gameLogic.createGame([newPlayer.userId]);
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
            console.log(
              "📤 sent this message to frontend, newGameCreated=",
              newGameCreatedMessage
            );
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
              // Add WebSocket to the map
              if (!gamePlayerWebSockets.has(gameId)) {
                gamePlayerWebSockets.set(gameId, new Map());
              }
              gamePlayerWebSockets.get(gameId).set(userId, ws);
              // Update game object to have the user in this game now
              game.addPlayer(userId);
              // Update game in firebase
              await firebaseUtils.writeGameData(game);
              // Retrieve updated game data
              const updatedGame = await firebaseUtils.getGame(gameId);
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
            try {
              const tileId = parseInt(data.tileId);
              const gameId = data.gameId;
              // 1. Validate Game and Tile Existence
              const gameToUpdateTileIn = await firebaseUtils.getGame(gameId);
              if (!gameToUpdateTileIn) {
                throw new Error(`❌ Game with ID ${gameId} does not exist.`);
              }
              // PROBLEM: game's objects are coming not as Tiles...
              console.log(
                "game's tiles should be tile objs...",
                gameToUpdateTileIn.tiles[0]
              ); // this is NOT the case
              // Check state of tile in this game
              const tileToUpdate = new Tile(
                tileId,
                gameToUpdateTileIn.tiles[tileId].isFlipped
              );
              if (!tileToUpdate || tileToUpdate.isFlipped) {
                throw new Error(
                  `❌ Tile ${tileId} is invalid or already flipped.`
                );
              }
              // 2. Update Tile Logic
              const tileWithUpdatedFlipAndLetter = gameLogic.flipTile(
                gameToUpdateTileIn,
                tileToUpdate
              );
              // 3. Update Firebase
              await firebaseUtils.updateTile(
                gameId,
                tileWithUpdatedFlipAndLetter
              );
              const gameWithUpdatedTile = await firebaseUtils.getGame(gameId); // 5. Send Success Response to Client
              const tileUpdateMessage = {
                type: "tileUpdate",
                data: gameWithUpdatedTile,
              };
              broadcastMessageToPlayers(gameId, tileUpdateMessage);
            } catch (error) {
              console.error(`❌ Error flipping tile: ${error.message}`);
              ws.send(JSON.stringify({ type: "error", data: error.message }));
            }
            break;
          default:
            console.log("❌ # Error - Check message frontend is sending");
          // broadcastMessageToPlayers()
        }
      } else {
        // Handle the case where idToken is missing
        console.error("❌ Missing idToken in the message data");
        ws.send(JSON.stringify({ type: "error", data: "Missing idToken" }));
      }
    } catch (error) {
      console.error("❌ Authentication or message processing failed:", error);
      ws.send(JSON.stringify({ type: "error", data: "Authentication error" }));
      // You might consider terminating the connection here: ws.terminate();
    }
  });
});

const PORT = 3000;
// Example for an Express server
server.listen(PORT, "0.0.0.0", () => {
  console.log(`Server is running on http://0.0.0.0:${PORT}`);
});
