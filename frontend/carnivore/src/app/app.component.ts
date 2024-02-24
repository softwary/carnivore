import { Component, OnInit } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { LoginComponent } from './login/login.component';
import { GameService } from './services/game.service';
import { WebSocketService } from './services/websocket.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, FormsModule, LoginComponent], // Add AngularFireAuthModule
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent implements OnInit {
  title = 'carnivore';
  username = '';
  gameStarted = false;

  constructor(
    private gameService: GameService,
    private webSocketService: WebSocketService
  ) {}

  ngOnInit() {
    this.gameService.getGame().subscribe((game) => {
      if (game) {
        this.gameStarted = true;
        // this.navigateToGameScreen();
      }
    });
  }

  startGame() {
    console.log('startGame()');
    const startMessage = {
      type: 'createGame',
      data: { players: this.username },
    };
    this.webSocketService.sendMessage(startMessage);
  }
}
