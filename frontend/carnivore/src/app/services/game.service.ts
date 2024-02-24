import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import { Game, Tile } from '../models/game.model';

@Injectable({
  providedIn: 'root'
})
export class GameService {
  private gameState = new BehaviorSubject<Game | null>(null);

  updateGameState(newGameState: Game) {
    this.gameState.next(newGameState);
    // Additional logic to communicate with the backend, if necessary
  }

  updateGameAttribute<K extends keyof Game>(key: K, value: Game[K]) {
    const currentGame = this.gameState.getValue();
    if (currentGame) {
      // Update specific attribute of the game
      currentGame[key] = value as any;
      // Emit the updated game state
      this.gameState.next(currentGame);
    }
  }

  updateTiles(tiles: Tile[]) {
    const currentGame = this.gameState.getValue();
    if (currentGame) {
      currentGame.tiles = tiles;
      this.gameState.next(currentGame);
    }
  }

  updateSingleTile(updatedTile: Tile) {
    console.log("in updateSingleTile");
    const currentGame = this.gameState.getValue();
    if (currentGame && currentGame.tiles) {
      const tileIndex = currentGame.tiles.findIndex(t => t.tileId === updatedTile.tileId);
      if (tileIndex !== -1) {
        currentGame.tiles[tileIndex] = updatedTile;
        this.gameState.next(currentGame);
      }
    }
  }


  getGame() {
    return this.gameState.asObservable();
  }

}
