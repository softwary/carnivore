import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import { Game, Tile } from '../models/game.model';

@Injectable({
  providedIn: 'root',
})
export class GameService {
  private gameState = new BehaviorSubject<Game | null>(null);

  updateGameState(newGameState: Game) {
    if (newGameState.tiles && typeof newGameState.tiles === 'object') {
      newGameState.tiles = Object.values(newGameState.tiles);
    }
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

  // updateSingleTile(updatedTile: Tile) {
  //   // console.log("BEFORE UPDATE in updateSingleTile, tiles=", this.gameState.getValue().tiles);
  //   console.log('in updateSingleTile, updatedTile =', updatedTile);
  //   const currentGame = this.gameState.getValue();
  //   if (currentGame && currentGame.tiles) {
  //     const tileIndex = currentGame.tiles.findIndex(
  //       (t) => t.tileId === updatedTile.tileId
  //     );
  //     console.log("new tiles =currentGame.tiles=",currentGame.tiles);
  //     if (tileIndex !== -1) {
  //       currentGame.tiles[tileIndex] = updatedTile;
  //       this.gameState.next(currentGame);
  //     }
  //   }
  // }

  // updateSingleTile(updatedTile: Tile) {
  //   console.log('in updateSingleTile, updatedTile =', updatedTile);
  //   const currentGame = this.gameState.getValue();
  //   if (currentGame && currentGame.tiles) {
  //     const tileIndex = currentGame.tiles.findIndex(
  //       (t) => t.tileId === updatedTile.tileId
  //     );

  //     if (tileIndex !== -1) {
  //       // Update existing tile object
  //       currentGame.tiles[tileIndex] = {
  //         ...currentGame.tiles[tileIndex],
  //         ...updatedTile,
  //       };

  //       // Emit the updated game state
  //       this.gameState.next(currentGame);
  //     } else {
  //       console.error(`Tile with tileId ${updatedTile.tileId} not found.`);
  //     }
  //   }
  // }

  updateSingleTile(updatedTile: Tile) {
    console.log('in game.service.ts updateSingleTile, updatedTile =', updatedTile);
    const currentGame = this.gameState.getValue();
    if (currentGame && currentGame.tiles) {
      const tileIndex = currentGame.tiles.findIndex(
        // Backend sends the tileId as a string, frontend stores tileIds as numbers
        (t) => String(t.tileId) === String(updatedTile.tileId)
      );
      console.log("game.service tileIndex = ", tileIndex);
  
      if (tileIndex !== -1) {
        // Create a new tiles array with the updated tile
        const newTiles = [
          ...currentGame.tiles.slice(0, tileIndex),
          { ...currentGame.tiles[tileIndex], ...updatedTile }, // Update tile
          ...currentGame.tiles.slice(tileIndex + 1)
        ];
  
        // Update the game object with the new tiles array
        const updatedGame = { ...currentGame, tiles: newTiles };
  
        // Emit the updated game state
        this.gameState.next(updatedGame);
      } else {
        console.error(`Tile with tileId ${updatedTile.tileId} not found.`);
      }
    }
  }

  getGame() {
    return this.gameState.asObservable();
  }
}
