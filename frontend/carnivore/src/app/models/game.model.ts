export interface Tile {
    tileId: number;
    letter: string;
    isFlipped: boolean;
    inMiddle: boolean;
}

export interface Game {
    gameId: string;
    active: boolean;
    flippedLetters: string[];
    players: any[]; // Adjust based on your Player model
    winner: any; // Adjust based on your Player model
    remainingLetters: {};
    tiles: Tile[];
    input: string;
    timer: any; // Adjust based on your Timer model
    minimumWordLength: number;
}

export interface Player {
    playerId: string,
    gameId: string,
    words: string[],
    score: number,
    turn: boolean,
    input: string 
}