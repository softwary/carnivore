export interface Tile {
    tileId: number;
    letter: string;
    isFlipped: boolean;
}

export interface Game {
    gameId: string;
    active: boolean;
    players: any[]; // Adjust based on your Player model
    winner: any; // Adjust based on your Player model
    remainingLetters: [];
    tiles: Tile[];
    input: string;
    timer: any; // Adjust based on your Timer model
}