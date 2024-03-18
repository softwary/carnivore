import { Injectable } from '@angular/core';
import { GameService } from './game.service';
import { Game, Tile } from '../models/game.model';
import { AuthenticationService } from './authentication.service';

@Injectable({
  providedIn: 'root',
})
export class WebSocketService {
  private webSocket!: WebSocket;

  constructor(
    private gameService: GameService,
    private authService: AuthenticationService
  ) {
    this.connect();
  }
  private connect() {
    this.webSocket = new WebSocket('ws://192.168.1.170:3000');
    this.webSocket.onopen = () => {
      console.log('@!WebSocket connection established');
    };

    this.webSocket.onmessage = (messageEvent) => {
      console.log('@ RECEIVED: ', JSON.stringify(messageEvent.data));
      const { type, data } = JSON.parse(messageEvent.data);
      switch (type) {
        // Game Started
        case 'newGame':
          let newGame = data as Game;
          console.log("What is newGame set to?newGame=", newGame)
          this.gameService.updateGameState(newGame);
          break;
        // Game Joined
        // case "gameToJoin":
        //     let joinedGame = data as Game;
        //     this.gameService.updateGameState(joinedGame);
        //     break;
        // // If a tile is flipped
        // case "tileUpdate":
        //     console.log("need to update tile!", data);
        //     let tileToUpdate = data as Tile;
        //     this.gameService.updateSingleTile(tileToUpdate);
        //     // this.gameService.updateGameAttribute(tiles, tileInfo);
        //     break;
        // If server responds back with an error
        default:
          console.log('@ Check message backend is sending');

        // Handle other message types as needed
      }
    };

    this.webSocket.onerror = (error) => {
      console.error('WebSocket Error:', error);
    };

    this.webSocket.onclose = (event) => {
      console.log('❌WebSocket connection closed:', event.code, event.reason);
    };
  }

  sendMessage(message: Object) {
    if (this.webSocket.readyState === WebSocket.OPEN) {
      console.log('@ Sending via WebSocket this object: ', message);
      // console.log("@ Sending via WebSocket this stringified object: ", JSON.stringify(message));
      this.webSocket.send(JSON.stringify(message));
    } else {
      console.error('WebSocket is not open. Message not sent:', message);
    }
  }

  //   async authenticate() {
  //       console.log('There was no idToken, trying to retrieve it.')
  //       // Retrieve the Firebase ID token
  //       const idToken = await this.authService.getIdToken();
  //       if (idToken) {
  //         console.log("in webSocketService, authenticate()", idToken)
  //         const authenticationMessage = { type: 'authenticate', data: {idToken: idToken}}
  //         this.sendMessage(authenticationMessage);
  //       } else {
  //         console.log('User is not logged in');
  //         // Handle not-logged-in scenario
  //       }
  //     }
}
