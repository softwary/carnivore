class Player {
    constructor(userId, gameId) {
        // super(username);
        this.playerId = userId;
        this.gameId = gameId;
        this.wordSignatures = [];
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
        this.wordSignatures.push(this.createSignature(word));
        this.score += word.length;
    }
    
    createSignature(text) {
        const signature = {};
        for (const letter of text.toUpperCase()) {
            signature[letter] = signature[letter] + 1 || 1;
        }
        return signature;
    }
    
    startTurn() {
        this.turn = true;
    }

    endTurn() {
        this.turn = false;
    }
}

module.exports = Player;