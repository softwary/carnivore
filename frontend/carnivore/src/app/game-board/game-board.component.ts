import { Component, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { NgIf, NgFor } from '@angular/common';
import { GameService } from '../services/game.service';
import { WebSocketService } from '../services/websocket.service';
import { Game, Tile } from '../models/game.model';

@Component({
  standalone: true,
  imports: [NgIf, NgFor, FormsModule], // Import RouterModule
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
}
