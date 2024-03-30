import { Component, Input } from '@angular/core';
import { Game, Player, Tile } from '../models/game.model';
import { GameService } from '../services/game.service';
import { WebSocketService } from '../services/websocket.service';
import { NgIf, NgFor } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { TileComponent } from '../tile/tile.component';
import { MatInputModule } from '@angular/material/input';
import { AlphaOnlyDirective } from '../alpha-only.directive';
import { MatGridListModule } from '@angular/material/grid-list';
import { MatIconModule } from '@angular/material/icon';
import { WebSocketMessage } from '../models/web-socket-message';

@Component({
  selector: 'app-player-word-board',
  standalone: true,
  imports: [
    NgIf,
    NgFor,
    TileComponent,
    MatCardModule,
    MatButtonModule,
    MatInputModule,
    AlphaOnlyDirective,
    MatGridListModule,
    MatIconModule,
  ],
  templateUrl: './player-word-board.component.html',
  styleUrl: './player-word-board.component.css',
})
export class PlayerWordBoardComponent {
  @Input() player: Player | null = null;

  constructor(
    private gameService: GameService,
    private webSocketService: WebSocketService
  ) {}
  // ngOnInit() {
  //   // console.log("@ in game-board, game = ", this.game)
  //   this.gameService.getGame().subscribe((gameState: Game | null) => {
  //     if (gameState) {
  //       console.log('@ in gameboard, gameState= ', gameState);
  //       this.game = gameState;
  //       // console.log("@ gameState.Tiles= ", gameState.tiles);
  //       // this.game.tiles = gameState.tiles;
  //       // this.gameId = gameState.gameId;
  //       // console.log('@ game-board gameState= ', this.game);
  //     }
  //     // Update component view based on the new game state
  //   });
  // }
}
