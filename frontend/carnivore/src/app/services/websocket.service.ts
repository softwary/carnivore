import { Injectable } from '@angular/core';
import { GameService } from './game.service';
import { Game, Tile } from '../models/game.model';
import { AuthenticationService } from './authentication.service';
import { WebSocketMessage } from '../models/web-socket-message';
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
    // this.webSocket = new WebSocket('ws://localhost:3000');
    this.webSocket = new WebSocket('ws://192.168.1.154:3000');
    this.webSocket.onopen = () => {
      console.log('✅ WebSocket connection established');
    };

    this.webSocket.onmessage = (messageEvent) => {
      console.log('⬅️ RECEIVED: ', JSON.parse(messageEvent.data));
      const { type, data } = JSON.parse(messageEvent.data);
      switch (type) {
        // Game Started
        case 'newGame':
          let newGame = data as Game;
          this.gameService.updateGameState(newGame);
          break;
        // Game Joined
        case 'gameJoined':
          let joinedGame = data as Game;
          this.gameService.updateGameState(joinedGame);
          break;
        // If a tile is flipped
        case 'tileUpdate':
          let gameWithUpdatedTile = data as Game;
          this.gameService.updateGameState(gameWithUpdatedTile);
          break;
        // If a word is submitted
        case 'gameWithWord':
          let gameWithWord = data as Game;
          this.gameService.updateGameState(gameWithWord);
          break;
        // If server responds back with an error
        default:
          console.log('❌ @ Check message backend is sending');
      }
    };

    this.webSocket.onerror = (error) => {
      console.error('❌ WebSocket Error:', error);
    };

    this.webSocket.onclose = (event) => {
      console.log('❌ WebSocket connection closed:', event.code, event.reason);
    };
  }

  async sendMessage(message: WebSocketMessage) {
    // Function now accepts WebSocketMessage directly
    if (this.webSocket.readyState === WebSocket.OPEN) {
      // Always send the firebase idToken with all messages
      const idToken = await this.authService.getIdToken();
      if (idToken) {
        message.data.idToken = idToken; // Add idToken to the message
        console.log('📤 ➡️ Sending via WebSocket this object: ', message);
        this.webSocket.send(JSON.stringify(message));
      } else {
        console.log('❌ User is not logged in, websocket message was not sent');
      }
    }
  }
}
