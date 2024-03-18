const express = require("express");
const http = require("http");
const WebSocket = require("ws");
const url = require("url");
const firebaseUtils = require("./services/firebase_utils");
var admin = require("firebase-admin");

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const gameLogic = require("./services/gamelogic");
const playerLogic = require("./services/playerlogic");

function cl() {
  console.log(" ..... ");
  console.log(" ..... ");
}

wss.on("connection", (ws, req) => {
  console.log("✅ Connected!");
  // Proceed with handling messages from this authenticated user
  ws.on("message", async (message) => {
    try {
      const { type, data } = JSON.parse(message);
      cl();
      console.log("# Received: %s", message);
      cl();
      console.log(`type = ${type}`);
      console.log(`data = ${data}`);
      cl();

      if (data && data.idToken) {
        const userId = await firebaseUtils.verifyToken(data.idToken);
        cl();
        console.log(`userId = ${userId}`);
        cl();
        ws.userId = userId;
        // Handle all requests since the user is authenticated
        switch (type) {
          // User wants to Create a Game
          case "createGame":
            // Create a new player object
            cl();
            let newPlayer = playerLogic.createPlayer(userId, ws);
            console.log(`in server.js newPlayer =`, newPlayer.userId);
            let newGame = gameLogic.createGame([newPlayer.userId]);
            await firebaseUtils.writeGameData(newGame);
            const newGameCreatedMessage = {
              type: "newGame",
              data: newGame,
            };
            cl();
            ws.send(JSON.stringify(newGameCreatedMessage));
            cl();
            break;
          default:
            console.log("# Error - Check message frontend is sending");
        }
      } else {
        // Handle the case where idToken is missing
        console.error("Missing idToken in the message data");
        ws.send(JSON.stringify({ type: "error", data: "Missing idToken" }));
      }
    } catch (error) {
      console.error("Authentication or message processing failed:", error);
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
