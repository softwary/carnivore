/*const express = require("express");
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

// GameId: websockets (which have userIds)
const gamePlayerWebSockets = new Map();

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
function getPlayerIdByWebSocket(ws) {
  for (const [gameId, playerWebSockets] of gamePlayerWebSockets.entries()) {
    if (playerWebSockets.has(ws)) {
      // Note: We compare the websockets directly
      for (const [userId, storedWs] of playerWebSockets.entries()) {
        if (ws === storedWs) {
          // Check for WebSocket object equality
          return userId;
        }
      }
    }
  }
  return null; // Player not found
}

function updateWebSocketForUser(userId, newWebSocket) {
  // Iterate over all games
  for (const [gameId, playerWebSockets] of gamePlayerWebSockets.entries()) {
    // Check if this user is part of the current game
    if (playerWebSockets.has(userId)) {
      // Update the WebSocket for this user
      playerWebSockets.set(userId, newWebSocket);
      console.log(`WebSocket updated for user: ${userId}`);
      console.log("gamePlayerWebSockets=", gamePlayerWebSockets);
      return;
    }
  }
  // If the user is not part of any game, we might add them to a game later
}

function getGameIdByUserId(userId) {
  for (const [gameId, playerWebSockets] of gamePlayerWebSockets.entries()) {
    if (playerWebSockets.has(userId)) {
      return gameId;
    }
  }
  // Handle case where the user is not in any active game
  return null;
}

// wss.on("connection", (ws, req) => {
//   console.log("✅ Connected!");
//   // Proceed with handling messages from this authenticated user
//   // ws.on("message", async (message) => {
//   //   try {
//   //     const { type, data } = JSON.parse(message);
//   //     console.log("# Received: %s", message);
//   //     cl();
//   //     console.log(`type = ${type}`);
//   //     console.log(`data =`, data);
//   //     if (data && data.idToken) {
//   //       const userId = await firebaseUtils.verifyToken(data.idToken);
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

        // Update the WebSocket reference for the user
        updateWebSocketForUser(userId, ws);

        cl();
        console.log(`userId = ${userId}`);
        cl();
        ws.userId = userId;
        */
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

// GameId: websockets (which have userIds)
const gamePlayerWebSockets = new Map();

function broadcastMessageToPlayers(gameId, message) {
  // console.log("📤 broadcasted this message:", message);
  if (gamePlayerWebSockets.has(gameId)) {
    const playersWebSockets = gamePlayerWebSockets.get(gameId);
    playersWebSockets.forEach((ws) => {
      if (ws.readyState === WebSocket.OPEN) {
        // Check if the WebSocket is still open
        ws.send(JSON.stringify(message));
        console.log("📤 broadcasted message to all players", message.type);
      }
    });
  }
}

function getPlayerIdByWebSocket(ws) {
  for (const [gameId, playerWebSockets] of gamePlayerWebSockets.entries()) {
    for (const [userId, storedWs] of playerWebSockets.entries()) {
      if (ws === storedWs) {
        // Check for WebSocket object equality
        return userId;
      }
    }
  }
  return null; // Player not found
}

function updateWebSocketForUser(userId, newWebSocket) {
  for (const [gameId, playerWebSockets] of gamePlayerWebSockets.entries()) {
    if (playerWebSockets.has(userId)) {
      playerWebSockets.set(userId, newWebSocket);
      console.log(`WebSocket updated for user: ${userId}`);
      return;
    }
  }
}

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
      cl();
      console.log(`type = ${type}`);
      console.log(`data =`, data);
      if (data && data.idToken) {
        const userId = await firebaseUtils.verifyToken(data.idToken);
        updateWebSocketForUser(userId, ws); // Update WebSocket reference for the user
        cl();
        console.log(`userId = ${userId}`);
        cl();
        ws.userId = userId;
        // Handle all requests since the user is authenticated
        switch (type) {
          // User wants to Create a Game
          case "createGame":
            let newGame = gameLogic.createGame();
            // Create a new player object
            let newPlayer = playerLogic.createPlayer(userId, newGame.gameId);
            // Add the first player to the gamer(newPlayer);
            newGame.addPlayer(newPlayer);
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
            // console.log(
            //   "📤 sent this message to frontend, newGameCreated=",
            //   newGameCreatedMessage
            // );
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
              let joiningPlayer = playerLogic.createPlayer(userId, gameId);
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
              const gameId = getGameIdByUserId(userId);
              // 1. Validate Game and Tile Existence
              const gameToUpdateTileIn = await firebaseUtils.getGame(gameId);
              if (!gameToUpdateTileIn) {
                throw new Error(`❌ Game with ID ${gameId} does not exist.`);
              }
              const tileToUpdate = new Tile(
                tileId,
                gameToUpdateTileIn.tiles[tileId].isFlipped,
                gameToUpdateTileIn.tiles[tileId].inMiddle
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
          case "submitWord":
            cl();
            const gameId = getGameIdByUserId(userId);
            // 1. Validate Game and Player Existence
            const gameToSubmitWord = await firebaseUtils.getGame(gameId);
            if (!gameToSubmitWord) {
              throw new Error(
                `❌ Game with ID ${gameToSubmitWord.gameId} does not exist.`
              );
            }
            cl();
            const playerIdThatSubmittedWord = getPlayerIdByWebSocket(ws);
            cl();
            console.log("Searching for player ID:", playerIdThatSubmittedWord);
            const playerThatSubmittedWord = gameToSubmitWord.players.find(
              (player) => player.playerId === playerIdThatSubmittedWord
            );
            console.log(
              "Found playerThatSubmittedWord:",
              playerThatSubmittedWord
            );
            cl();
            if (!playerThatSubmittedWord) {
              throw new Error(
                `❌ Player with ID ${playerIdThatSubmittedWord} does not exist.`
              );
            }
            const word = data.word;
            console.log("{server} submitting Word=", word);
            cl();
            let gameWithWordSubmitted = gameToSubmitWord.handleWordSubmission(
              playerThatSubmittedWord,
              word
            );
            console.log(
              "{server} gameWithWordSubmitted.players[0].words=",
              gameWithWordSubmitted.players[0].words
            );
            await firebaseUtils.writeGameData(gameWithWordSubmitted);
            // Retrieve updated game data
            const gameWithWordSubmittedInFirebase = await firebaseUtils.getGame(
              gameId
            );
            console.log(
              "{server} gameWithWordSubmittedInFirebase.players=",
              gameWithWordSubmittedInFirebase.players
            );
            const gameUpdatedWordsMessage = {
              type: "gameWithWord",
              data: gameWithWordSubmittedInFirebase,
            };
            broadcastMessageToPlayers(gameId, gameUpdatedWordsMessage);
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
