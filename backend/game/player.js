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
        console.log("{player.js} attributing word to this player...player=", this);
        console.log("this player's score before increasing it..", this.playerId, " | ", this.score)
        this.score += word.length;
        console.log("AFTER INCREASING this player's score to add the word (",word," [",word.length,"]) before increasing it..", this.playerId, " | ", this.score)
    }
    
    createSignature(text) {
        const signature = {};
        for (const letter of text.toUpperCase()) {
            signature[letter] = signature[letter] + 1 || 1;
        }
        return signature;
    }

    endTurn() {
        // Ask Game object whose turn is next
        // Set current Player.turn = false
        // Set next Player.turn = true
        // This method will likely need to interact with the 'Game' class
    }
}

module.exports = Player;