import { Component, Input } from '@angular/core';
import { Player } from '../models/game.model';
import { GameService } from '../services/game.service';
import { WebSocketService } from '../services/websocket.service';
import { NgIf, NgFor } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { AlphaOnlyDirective } from '../alpha-only.directive';
import { MatGridListModule } from '@angular/material/grid-list';
import { MatIconModule } from '@angular/material/icon';
import { SplitLettersPipe } from '../split-letters.pipe';

@Component({
  selector: 'app-player-word-board',
  standalone: true,
  imports: [
    NgIf,
    NgFor,
    MatCardModule,
    MatButtonModule,
    MatInputModule,
    AlphaOnlyDirective,
    MatGridListModule,
    MatIconModule,
    SplitLettersPipe
  ],
  templateUrl: './player-word-board.component.html',
  styleUrl: './player-word-board.component.css',
})
export class PlayerWordBoardComponent {
  @Input() player: Player | null = null;

  constructor(
  ) { }
}
