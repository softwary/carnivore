class Player {
    constructor(userId, ws) {
        // super(username);
        this.userId = userId;
        this.ws = ws;
        this.gameId = null;
        this.words = []; // Array of Word objects
        this.score = 0; // Player's score
        this.turn = false; // Indicates if it's the player's turn
        this.input = ''; // Last input from the player
    }

    assignToGame(gameId) {
        this.gameId = gameId;
    }
    attributeWord(word) {
        this.words.push(word);
    }
    
    startGame() {
        // Instantiate Game Object
        // Note: This method might need to interact with a separate 'Game' class
    }

    endGame() {
        // Handle end of game logic
    }

    endTurn() {
        // Ask Game object whose turn is next
        // Set current Player.turn = false
        // Set next Player.turn = true
        // This method will likely need to interact with the 'Game' class
    }

    flipTile(game) {
        // Randomly chooses a Tile from the game's Tiles and flips it
        const randomIndex = Math.floor(Math.random() * game.tiles.length);
        const tile = game.tiles[randomIndex];
        tile.flipUp();
    }

    createWord(tiles, playerStealingFrom) {
        // Method takes Tile objects and groups them into a Word
        // If 'playerStealingFrom' is provided, handle logic for stealing words
    }

    identifyOwnerOfWord(wordInput) {
        // Method spits out the players that have this word in their 'words' array
    }

    attemptWord(playerWordInput) {
        // Logic for player attempting to create a word
    }
}

module.exports = Player;