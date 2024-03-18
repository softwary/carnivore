import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { NgIf, NgFor } from '@angular/common';
import { GameService } from '../services/game.service';
import { WebSocketService } from '../services/websocket.service';
import { Game, Tile } from '../models/game.model';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { TileComponent } from '../tile/tile.component';
import { MatInputModule } from '@angular/material/input';

@Component({
  standalone: true,
  imports: [
    NgIf,
    NgFor,
    FormsModule,
    TileComponent,
    MatCardModule,
    MatButtonModule,
    MatInputModule
  ],
  selector: 'app-game-board',
  templateUrl: './game-board.component.html',
  styleUrls: ['./game-board.component.css'],
})
export class GameBoardComponent {
  // ... your component's logic
  game!: Game | null;
  tiles: Tile[] = [];
  gameId: string = '';
  currentWord: string = '';

  constructor(
    private gameService: GameService,
    private webSocketService: WebSocketService
  ) {}

  ngOnInit() {
    // console.log("@ in game-board, game = ", this.game)
    this.gameService.getGame().subscribe((gameState: Game | null) => {
      if (gameState) {
        console.log('@ in gameboard, gameState= ', gameState);
        this.game = gameState;
        // console.log("@ gameState.Tiles= ", gameState.tiles);
        this.tiles = gameState.tiles;
        this.gameId = gameState.gameId;
        console.log('@ game-board gameId= ', this.gameId);
        console.log('@ in gameboard, what are tiles? ', this.tiles);
        // this.tiles.forEach(tile => {
        //     console.log(tile.tileId);
        // })
      }
      // Update component view based on the new game state
    });
  }

  submitWord() {
    // Construct the message object
    const message = {
      type: 'submitWord',
      data: {
        word: this.currentWord,
      },
      // Include any other relevant information, like playerId or gameId
    };

    // Send the message via WebSocket
    this.webSocketService.sendMessage(message);

    // Clear the input field
    this.currentWord = '';
  }

  handleTileFlipped(tileId: number) {
    console.log('@ made it to handletileFlipped!, tileId= ', tileId);
    // Send a message to the backend to flip the tile
    console.log('@ handleTileFlipped gameId= ', this.gameId);
    let type = 'flipTile';
    let data = {
      gameId: this.gameId,
      tileId: tileId,
    };

    this.webSocketService.sendMessage({ type, data });
  }
}
