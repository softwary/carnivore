const Tile = require("./tile");

class Game {
  constructor(playerIds) {
    this.gameId = this.generateGameId(4);
    this.playerIds = playerIds;
    this.remainingLetters = {
      A: 13,
      B: 3,
      C: 3,
      D: 6,
      E: 18,
      F: 3,
      G: 4,
      H: 3,
      I: 12,
      J: 2,
      K: 2,
      L: 5,
      M: 3,
      N: 8,
      O: 11,
      P: 3,
      Q: 2,
      R: 9,
      S: 6,
      T: 9,
      U: 6,
      V: 3,
      W: 3,
      X: 2,
      Y: 3,
      Z: 2,
    };
    this.tiles = this.generateTiles();
    // this.remainingLetters = this.initializeLetterPool();
    // this.
  }

  getPlayerById(playerId) {
    return this.playerIds.find((player) => player.playerId === playerId);
  }

  generateTiles() {
    // Create tiles with unique IDs
    const tiles = [];
    for (let i = 0; i < this.getTotalTileCount(); i++) {
      tiles.push(new Tile(i));
    }
    return tiles;
  }

  getTotalTileCount() {
    // console.log("in getTotalTileCount()");
    // console.log("in getTotalTileCount(), this.remainingLetters= ", this.remainingLetters);
    // Calculate the total number of tiles based on the letter pool
    return Object.values(this.remainingLetters).reduce(
      (sum, count) => sum + count,
      0
    );
  }

  assignLetterToTile(tile) {
    if (this.isLetterPoolEmpty()) {
      throw new Error("No more letters to assign");
    }

    const letter = this.getRandomLetter();
    tile.letter = letter;
    this.remainingLetters[letter]--;
  }

  isLetterPoolEmpty() {
    return Object.values(this.remainingLetters).every((count) => count === 0);
  }

  getRandomLetter() {
    let availableLetters = Object.entries(this.remainingLetters)
      .filter(([letter, count]) => count > 0)
      .map(([letter]) => letter);
    const randomIndex = Math.floor(Math.random() * availableLetters.length);
    return availableLetters[randomIndex];
  }

  flipTile(tileId) {
    const tile = this.tiles.find((t) => t.tileId === tileId);
    if (tile && !tile.isFlipped) {
      this.assignLetterToTile(tile);
      tile.flip();
      return tile;
    }
  }

  generateGameId(length) {
    let result = "";
    const characters = "abcdefghijklmnopqrstuvwxyz0123456789";
    const charactersLength = characters.length;
    for (let i = 0; i < length; i++) {
      result += characters.charAt(Math.floor(Math.random() * charactersLength));
    }
    return result;
  }
  isWordUsingARemainingTile(word) {
    // Create a copy of remainingLetters to track changes without affecting the original
    const lettersCopy = { ...this.remainingLetters };

    for (let letter of word.toUpperCase()) {
      if (lettersCopy[letter]) {
        // Reduce the count of the letter and return true as it's a valid letter
        lettersCopy[letter]--;
        return true;
      }
    }

    // If no letter from the word is found in remainingLetters, return false
    return false;
  }

  findPossibleInputOptions(word) {
    const lettersCopy = { ...this.remainingLetters };
    const possibleWords = [];

    for (let i = 0; i < word.length; i++) {
      const letter = word[i].toUpperCase();

      if (lettersCopy[letter]) {
        // Potential word variant by removing the current letter
        const wordVariant = word.slice(0, i) + word.slice(i + 1);
        possibleWords.push(wordVariant);
      }
    }

    // Return all possible word variants
    return possibleWords;
  }

  checkWordStealing(playerId, word) {
    const possibleWords = this.findPossibleInputOptions(word);

    possibleWords.forEach((possibleWord) => {
      this.playerIds.forEach((player) => {
        if (
          player.playerId !== playerId &&
          player.words.includes(possibleWord)
        ) {
          // Remove the word from the other player
          player.words = player.words.filter((w) => w !== possibleWord);

          // Add the new word to the current player's words
          const currentPlayer = this.playerIds.find(
            (p) => p.playerId === playerId
          );
          if (currentPlayer) {
            currentPlayer.words.push(word);
          }

          // Update remainingLetters
          word.split("").forEach((letter) => {
            if (this.remainingLetters[letter.toUpperCase()] > 0) {
              this.remainingLetters[letter.toUpperCase()]--;
            }
          });
        }
      });
    });
  }

  /* 
  * Returns back the updated state of the game, if word was valid. 
  */
  handleWordSubmission(player, word) {
    // Add your word processing logic here
    // This could include validating the word, updating scores, etc.
    console.log("in handleWordSubmission!");
    console.log("in handleWordSubmission! player= ", player, " word= ", word);
    // Word Validation/Attribution Logic
    // First, make sure word incorporates a letter from the center tiles
    if (isWordUsingARemainingTile(word)) {
      console.log("GOOD! word is using a remaining tile!");
      // Check if the word is even valid from dictionary API
      // 
      // Then, find out where the word is coming from
      checkWordStealing(player, word);
      
      if (player) {
        player.attributeWord(word);
        // Process the word submission for the player
      }
      return this;
    }
    console.log("BAD! word is NOT using a remaining tile!");
    return;
    // Optionally, return some result or status
  }
}

module.exports = Game;
