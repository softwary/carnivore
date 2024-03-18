import { Component, HostListener, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { NgIf, NgFor } from '@angular/common';
import { GameService } from '../services/game.service';
import { WebSocketService } from '../services/websocket.service';
import { Game, Tile } from '../models/game.model';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { TileComponent } from '../tile/tile.component';
import { MatInputModule } from '@angular/material/input';
import { AlphaOnlyDirective } from '../alpha-only.directive';
import { MatGridListModule } from '@angular/material/grid-list';
import { MatIconModule } from '@angular/material/icon';
import { WebSocketMessage } from '../models/web-socket-message';

@Component({
  standalone: true,
  imports: [
    NgIf,
    NgFor,
    FormsModule,
    TileComponent,
    MatCardModule,
    MatButtonModule,
    MatInputModule,
    AlphaOnlyDirective,
    MatGridListModule,
    MatButtonModule,
    MatIconModule,
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
  @HostListener('window:keydown', ['$event'])
  handleKeyDown(event: KeyboardEvent) {
    if (event.ctrlKey || event.metaKey) {
      // Check for Command/Ctrl
      if (event.key === 'Enter') {
        this.flipRandomTile(); // Implement this function to handle the flip
      }
    }
  }
  ngOnInit() {
    // console.log("@ in game-board, game = ", this.game)
    this.gameService.getGame().subscribe((gameState: Game | null) => {
      if (gameState) {
        console.log('@ in gameboard, gameState= ', gameState);
        this.game = gameState;
        // console.log("@ gameState.Tiles= ", gameState.tiles);
        this.tiles = gameState.tiles;
        this.gameId = gameState.gameId;
        console.log('@ game-board gameState= ', this.game);
      }
      // Update component view based on the new game state
    });
  }

  submitWord() {
    const type = 'submitWord';
    const data = {
      word: this.currentWord
    };
    // Include any other relevant information, like playerId or gameId

    const submitWordMessage = new WebSocketMessage(type, '', data);
    // Send the message via WebSocket
    this.webSocketService.sendMessage(submitWordMessage);

    // Clear the input field
    this.currentWord = '';
  }

  flipRandomTile() {
    const unflippedTiles = this.tiles.filter((tile) => !tile.isFlipped);

    if (unflippedTiles.length > 0) {
      const randomIndex = Math.floor(Math.random() * unflippedTiles.length);
      const tileToFlip = unflippedTiles[randomIndex];

      // Update isFlipped. (Ideally, also send this flip action to your backend)
      tileToFlip.isFlipped = true;
      let type = 'flipTile';
      let stringifiedTileId = tileToFlip.tileId.toString();
      let data = {
        gameId: this.gameId,
        tileId: stringifiedTileId,
      };
      const flipTileMessage = new WebSocketMessage(type, '', data);
      this.webSocketService.sendMessage(flipTileMessage);
    } else {
      // Handle the case where all tiles are already flipped (optional)
      console.log('All tiles are flipped!');
    }
  }
}
