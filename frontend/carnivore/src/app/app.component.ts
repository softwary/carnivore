import { Component, OnInit } from '@angular/core';
import { Router, RouterOutlet } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { LoginComponent } from './login/login.component';
import { NgIf } from '@angular/common';
import { GameService } from './services/game.service';
import { WebSocketService } from './services/websocket.service';
import { AuthenticationService } from './services/authentication.service';
import { GameBoardComponent } from './game-board/game-board.component';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    RouterOutlet,
    FormsModule,
    LoginComponent,
    GameBoardComponent,
    MatCardModule,
    MatButtonModule,
    MatToolbarModule,
    MatIconModule,
    NgIf
  ],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent implements OnInit {
  title = 'Cannibaletters';
  username = '';
  gameStarted = false;

  constructor(
    private router: Router,
    private gameService: GameService,
    private webSocketService: WebSocketService,
    private authService: AuthenticationService
  ) {}

  isLoggedIn = false; // Store logged in status in app.component

  updateLoginStatus(isLoggedIn: boolean) {
    this.isLoggedIn = isLoggedIn;
  }

  ngOnInit() {
    this.gameService.getGame().subscribe((game) => {
      if (game) {
        console.log("app.component.ts --> game=", game)
        this.gameStarted = true;
        this.navigateToGameScreen();
      }
    });
  }

  navigateToGameScreen() {
    console.log('navigate to /game-board, game=');
    this.router.navigate(['/game-board']);
  }
  startGameOnClick() {
    console.log('navigate to game-board');
    this.startGame();
    this.router.navigate(['/game-board']);
  }
  async startGame() {
    console.log('@ startGame()');

    // Retrieve the Firebase ID token
    const idToken = await this.authService.getIdToken();
    if (idToken) {
      const startMessage = {
        type: 'createGame',
        data: { idToken: idToken },
      };
      this.webSocketService.sendMessage(startMessage);
    } else {
      console.log('User is not logged in');
      // Handle not-logged-in scenario
    }
  }
}
