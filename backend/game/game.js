const Tile = require("./tile");

class Game {
    constructor() {
        this.gameId = this.generateGameId(4);
        this.players = [];
        this.minimumWordLength = 3;
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
        this.flippedLetters = {};
        this.potentialSteals = [];
    }
    
    /**
     * Creates a signature from a given text by counting the occurrences of each letter.
     * Each letter's count is stored in an object where the key is the letter and the value is the count.
     * 
     * @param {string} text The input text from which to create the letter signature.
     * @returns {Object} An object with keys as uppercase letters and values as their counts in the text.
     */
    createSignature(text) {
        const signature = {};
        for (const letter of text.toUpperCase()) {
            signature[letter] = signature[letter] + 1 || 1;
        }
        return signature;
    }

    /**
     * Adds a player to the game if the player ID is valid.
     * Throws an error if the player ID is invalid or not provided.
     * 
     * @param {Object} player An object representing a player, expected to have a `playerId` property.
     */
    addPlayer(player) {
        // Input Validation (optional, but recommended)
        if (!player.playerId || typeof (player.playerId) !== 'string') {
            throw new Error('Invalid playerId. Please provide a valid string.');
        }
        this.players.push(player);
    }

    /**
     * Retrieves a player by their ID.
     * 
     * @param {string} playerId The ID of the player to retrieve.
     * @returns {Object|null} The player object if found, otherwise null.
     */
    getPlayerById(playerId) {
        return this.players.find((player) => player.playerId === playerId);
    }

    /**
     * Generates an array of Tile objects for the game, each identified by a unique tileId.
     * 
     * @returns {Array} An array of Tile objects.
     */
    generateTiles() {
        const tiles = [];
        for (let i = 0; i < this.getTotalTileCount(); i++) {
            tiles[i] = new Tile(i); // Store tiles with their tileId as keys
        }
        return tiles;
    }

    /**
     * Calculates the total count of tiles based on the remaining letters available in the game.
     * 
     * @returns {number} The total number of tiles based on the letters available.
     */
    getTotalTileCount() {
        // Calculate the total number of tiles based on the letter pool
        return Object.values(this.remainingLetters).reduce(
            (sum, count) => sum + count,
            0
        );
    }

    /**
     * Assigns a letter to a tile. If no letters are available, throws an error.
     * After assigning, it decrements the letter count and flips the tile.
     * Updates the count of flipped letters in a Map.
     * 
     * @param {Tile} tile The tile object to which a letter will be assigned.
     * @returns {Tile} The updated tile with a letter assigned.
     */
    assignLetterToTile(tile) {
        if (this.isLetterPoolEmpty()) {
            throw new Error("No more letters to assign");
        }
        const letter = this.getRandomLetter();
        tile.letter = letter;
        this.remainingLetters[letter]--;
        tile.flip();
        if (typeof this.flippedLetters == 'object') {
        }
        if (this.flippedLetters.has(letter)) {
            // Increment the current count
            this.flippedLetters.set(letter, this.flippedLetters.get(letter) + 1);
        } else {
            // Initialize the count to 1 if the letter is not in the map
            this.flippedLetters.set(letter, 1);
        }
        return tile;
    }

    /**
     * Checks if the letter pool is empty.
     * 
     * @returns {boolean} True if all letter counts are zero, otherwise false.
     */
    isLetterPoolEmpty() {
        return Object.values(this.remainingLetters).every((count) => count === 0);
    }

    /**
     * Selects a random letter from the remaining letters that have a count greater than zero.
     * 
     * @returns {string} A randomly chosen available letter.
     */
    getRandomLetter() {
        let availableLetters = Object.entries(this.remainingLetters)
            .filter(([letter, count]) => count > 0)
            .map(([letter]) => letter);
        const randomIndex = Math.floor(Math.random() * availableLetters.length);
        return availableLetters[randomIndex];
    }

    /**
     * Generates a game ID of specified length using alphanumeric characters.
     * 
     * @param {number} length The length of the game ID to generate.
     * @returns {string} A randomly generated game ID.
     */
    generateGameId(length) {
        let result = "";
        const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        const charactersLength = characters.length;
        for (let i = 0; i < length; i++) {
            result += characters.charAt(Math.floor(Math.random() * charactersLength));
        }
        return result;
    }

    /**
     * Checks if the submitted word meets the minimum length requirement.
     * 
     * @param {string} word The word to check against the minimum length.
     * @returns {boolean} True if the word meets the minimum length, otherwise false.
     */
    doesWordMeetMinimum(word) {
        if (word.length >= this.minimumWordLength) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * Dummy function to simulate checking a word in a dictionary.
     * Currently always returns true.
     * 
     * @param {string} word The word to check.
     * @returns {boolean} Always returns true in this dummy implementation.
     */
    checkWordInDictionary(word) {
        // We do not have a dictionary API set up yet, so always say "yes".
        return true;
    }

    /**
     * Determines if the given word uses at least one letter marked as being in the game (stored in the map).
     *
     * @param {string} word - The word to check against the flipped letters.
     * @returns {boolean} True if any letter from the map is used in the word, otherwise false.
     */
    doesWordUseTileFromMiddle(word) {
        for (let letter of this.flippedLetters.keys()) {
            if (word.includes(letter)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Identifies potential words that can be stolen from other players based on the submitted word.
     * Adjusts the signature of the submitted word by removing or decrementing letters already flipped
     * and checks if the remaining can form a valid anagram with any words of other players.
     *
     * @param {Object} player - The player attempting to steal a word.
     * @param {string} submittedWord - The word submitted by the player.
     * @returns {Array} A list of potential steal options, each being an object detailing the steal opportunity.
     */
    canStealFrom(player, submittedWord) {
        const submittedWordSignature = this.createSignature(submittedWord);
        const possibleWordSignatures = [];
        // Adjust signature based on flipped letters
        this.flippedLetters.forEach((count, letter) => {
            const submittedWordAdjustedSignature = { ...submittedWordSignature };
            if (submittedWordAdjustedSignature[letter]) {
                submittedWordAdjustedSignature[letter] -= count;
                if (submittedWordAdjustedSignature[letter] <= 0) {
                    delete submittedWordAdjustedSignature[letter];
                }
                possibleWordSignatures.push(submittedWordAdjustedSignature);
            }

        });

        const potentialSteals = [];
        // Check against other players' words
        for (const player of this.players) {
            // if (otherPlayer !== player) {
            for (let i = 0; i < player.wordSignatures.length; i++) {
                const playersWordSignature = player.wordSignatures[i];
                const playersWord = player.words[i];
                // check array of possible word signatures against every other player's words
                possibleWordSignatures.forEach((possibleWordSignature) => {
                    // Check if combined signatures can match the word to be stolen
                    if (this.canFormWordFromSignature(possibleWordSignature, playersWordSignature)) {
                        const flippedLettersUsed = this.getFlippedLettersUsed(submittedWord, playersWord, this.flippedLetters);
                        potentialSteals.push({
                            playerToStealFrom: player,
                            wordToSteal: playersWord,
                            flippedLettersUsed
                        });
                    }
                });
            }
            // }
        }

        return potentialSteals;
    }

    /**
     * Checks if the first signature can form a word from the second signature.
     * Essentially checking if all letters in signatureB can be accounted for by letters in signatureA.
     */
    canFormWordFromSignature(signatureA, signatureB) {
        for (const [letter, count] of Object.entries(signatureB)) {
            if (!signatureA[letter] || signatureA[letter] < count) {
                return false; // Not enough letters available
            }
        }
        return true; // All letters accounted for
    }

    /**
     * Calculates which flipped letters are used to form the word to be stolen based on the remaining signature
     * of the submitted word after attempting to steal. This function now handles flipped letters stored in a Map.
     *
     * @param {string} submittedWord - The word submitted for stealing.
     * @param {string} wordToSteal - The target word to steal.
     * @param {Map<string, number>} flippedLetters - Map of letters and their counts that have been flipped in the game.
     * @returns {Array<string>} An array of letters that have been used from the flipped pool.
     */
    getFlippedLettersUsed(submittedWord, wordToSteal, flippedLetters) {
        const flippedLettersUsed = [];
        const signatureToSteal = this.createSignature(wordToSteal);

        // 1. Create a copy of the submitted word signature
        const signatureCopy = this.createSignature(submittedWord);

        // 2. Remove letters from the stolen word
        for (const letter of wordToSteal) {
            signatureCopy[letter]--;
            if (signatureCopy[letter] === 0) {
                delete signatureCopy[letter];
            }
        }

        // 3. Check flipped letters, prioritizing those 'inMiddle' if necessary
        for (const letter in signatureCopy) {
            while (signatureCopy[letter] > 0 && flippedLetters.has(letter) && flippedLetters.get(letter) > 0) {
                // Deduct the count of the letter in the flipped letters Map
                flippedLetters.set(letter, flippedLetters.get(letter) - 1);
                flippedLettersUsed.push(letter);
                signatureCopy[letter]--;

                // If the count reaches zero, consider removing it from map if needed
                if (flippedLetters.get(letter) === 0) {
                    flippedLetters.delete(letter);
                }
            }
        }

        return flippedLettersUsed;
    }

    /**
     * Determines if two signatures are anagrams of each other by comparing letter counts.
     *
     * @param {Object} signatureA - The first signature to compare.
     * @param {Object} signatureB - The second signature to compare.
     * @returns {boolean} True if both signatures match exactly (i.e., are anagrams), otherwise false.
     */
    isAnagram(signatureA, signatureB) {
        // 1. Check if lengths match (quick optimization)
        if (Object.keys(signatureA).length !== Object.keys(signatureB).length) {
            return false;
        }

        // 2. Compare letter counts
        for (const letter in signatureA) {
            if (signatureA[letter] !== signatureB[letter]) {
                return false;
            }
        }
        // If all letter counts match, it's an anagram
        return true;
    }

    /**
     * Checks if all letters in a given word are present in an array of tile objects.
     *
     * @param {string} word - The word to be checked.
     * @returns {boolean} True if all letters of the word are represented in the tiles, otherwise false.
     */
    doesWordUseOnlyTilesInGame(word) {
        // Extract letters from tile objects
        const tileLetters = this.tiles.map(tile => tile.letter);

        // Create a Set from the tileLetters array for quick lookup
        const tileSet = new Set(tileLetters);

        // Convert the word to an array of letters
        const wordLetters = Array.from(word);

        // Check each letter in the word to see if it's in the tiles set
        return wordLetters.every(letter => tileSet.has(letter));
    }

    /**
     * Conducts a word steal operation. Removes the word from the robbed player's list and adds it to the stealing player's list.
     * Also, updates the signatures accordingly.
     *
     * @param {Object} playerThatIsStealing - The player who is attempting to steal a word.
     * @param {Object} stealOption - Details of the steal, including the target player, word, and used letters.
     * @param {string} word - The word to steal.
     */
    stealWord(playerThatIsStealing, stealOption, word) {
        const { playerToStealFrom, wordToSteal, flippedLettersUsed } = stealOption;
        // 1. Remove the word from the 'robbed' player
        const wordIndex = playerToStealFrom.words.indexOf(wordToSteal);
        if (wordIndex !== -1) {
            playerToStealFrom.words.splice(wordIndex, 1);
            playerToStealFrom.wordSignatures.splice(wordIndex, 1); // Update signatures
        }
        // 2. Add the word to the stealing player
        playerThatIsStealing.words.push(word);
        playerThatIsStealing.wordSignatures.push(this.createSignature(word)); // Update signatures
    }

    /**
     * Subtracts the counts of letters used from the flippedLetters map.
     * If a letter's count reaches zero after subtraction, it is removed from the map.
     *
     * @param {Map} flippedLetters - A map of letters to their counts representing flipped letters.
     * @param {Array} lettersUsed - An array of letters that have been used.
     * @returns {Map} A new map with updated counts after subtracting the letters used.
     */
    subtractLetterArrays(flippedLetters, lettersUsed) {
        // Create a shallow copy of the map to avoid mutating the original map
        const updatedFlippedLetters = new Map(flippedLetters);

        // Iterate over each letter used and adjust the count in the flipped letters map
        lettersUsed.forEach(letter => {
            if (updatedFlippedLetters.has(letter)) {
                const newCount = updatedFlippedLetters.get(letter) - 1;
                if (newCount > 0) {
                    updatedFlippedLetters.set(letter, newCount);
                } else {
                    updatedFlippedLetters.delete(letter);
                }
            }
        });

        return updatedFlippedLetters;
    }

    /**
     * Resets the flipped and inMiddle status of tiles that match the letters in the given word.
     * This method modifies the tiles directly based on the letters of the word.
     *
     * @param {string} word - The word whose letters correspond to tiles to be unflipped.
     * @param {Array} tileArray - The array of tiles containing tile objects.
     */
    unflipTilesForWord(word, tileArray) {
        // Create a Set of letters from the word for efficient lookups
        const wordLetters = new Set(word.toUpperCase());

        // Update the tile array (modifies the original array)
        tileArray.forEach(tile => {
            if (wordLetters.has(tile.letter.toUpperCase())) {
                tile.isFlipped = false;
                tile.inMiddle = false;
            }
        });
    }

    /**
 * Checks if every letter in the given word exists in the provided map of flipped letters.
 *
 * @param {string} word - The word to check.
 * @returns {boolean} True if every letter in the word is found in the map, false otherwise.
 */
    areAllLettersInWordFromMiddle(word) {
        // Convert the word to uppercase if the map's keys are in uppercase
        word = word.toUpperCase();

        for (let i = 0; i < word.length; i++) {
            const letter = word[i];
            // Check if the letter exists in the map and there is at least one occurrence left
            if (!this.flippedLetters.has(letter) || this.flippedLetters.get(letter) === 0) {
                return false;  // Early exit if any letter is not found or has zero occurrences
            }
        }
        return true;  // All letters were found in the map
    }

    /**
     * Flips a random unflipped tile in the game. This function chooses a tile, flips it,
     * and potentially assigns a new letter to it based on the game's logic.
     *
     * @returns {Object} The tile that was flipped, containing the new state and any other relevant information.
     * @throws {Error} If there are no unflipped tiles left to flip.
     */
    flipTile() {
        const unflippedTiles = this.tiles.filter((tile) => !tile.isFlipped);
        if (unflippedTiles.length > 0) {
            const randomIndex = Math.floor(Math.random() * unflippedTiles.length);
            const tileToFlip = unflippedTiles[randomIndex];
            const flippedTile = this.assignLetterToTile(tileToFlip);
            this.tiles[flippedTile.tileId] = flippedTile;
            return flippedTile;
        }
        else {
            // Handle the case where all tiles are already flipped (optional)
            throw new Error(
                `There are no more tiles to flip.`
            );
        }
    }

    /**
     * Finds the steal opportunity with the highest scoring player.
     * This function iterates over an array of potential steals, each containing a player and other details about the steal.
     * It returns the object where the `playerToStealFrom` has the highest score.
     *
     * @param {Array} potentialSteals - An array of objects, each representing a potential steal opportunity.
     * @returns {Object} The steal opportunity with the highest scoring player.
     */
    findHighestScoringSteal(potentialSteals) {
        if (!potentialSteals.length) {
            throw new Error("The array of potential steals is empty.");
        }

        return potentialSteals.reduce((acc, current) => {
            return (acc.playerToStealFrom.score > current.playerToStealFrom.score) ? acc : current;
        });
    }

    /**
     * Processes a word submission during gameplay. Validates the word against several criteria:
     * meets minimum length, uses a middle tile, uses only tiles in the game, and checks the dictionary.
     * Depending on these validations, the word might be stolen from another player, or various game states are updated.
     *
     * @param {Object} player - The player object submitting the word.
     * @param {string} word - The word being submitted.
     * @returns {Object} The updated game state or potential steal options if the word passes all checks.
     * @throws {Error} If the word fails any of the game's validation rules.
     */
    handleWordSubmission(player, word) {
        let wordMeetsMinimum = this.doesWordMeetMinimum(word);
        if (wordMeetsMinimum) {
            // Check now if the word is even using a letter from the middle
            let wordUsesTileFromMiddle = this.doesWordUseTileFromMiddle(word);
            // Check now if the word is even using a letter from the middle
            let wordIsUsingOnlyTilesInGame = this.doesWordUseOnlyTilesInGame(word);
            if (wordUsesTileFromMiddle && wordIsUsingOnlyTilesInGame) {
                // Check now if word is in dictionary
                let wordIsInDictionary = this.checkWordInDictionary(word);
                if (wordIsInDictionary) {
                    // Stealing Logic
                    const potentialSteals = this.canStealFrom(player, word);
                    if (potentialSteals.length) {
                        if (potentialSteals.length == 1) {
                            // There is only one option, so steal it!
                            const chosenStealOption = potentialSteals[0];
                            this.stealWord(player, chosenStealOption, word);
                            this.flippedLetters = this.subtractLetterArrays(this.flippedLetters, chosenStealOption.flippedLettersUsed);

                            this.unflipTilesForWord(word, this.tiles);
                        }
                        else if (potentialSteals.length > 1) {
                            // Going to set this but also ignore it, and take the word from whoever has the highest score.
                            this.potentialSteals = potentialSteals;
                            console.log("There are multiple options from where to steal the word!")
                            console.log("But going to just take it from the player with the highest score:",)
                            const chosenStealOption = this.findHighestScoringSteal(potentialSteals);

                            this.stealWord(player, chosenStealOption, word);
                            this.flippedLetters = this.subtractLetterArrays(this.flippedLetters, chosenStealOption.flippedLettersUsed);

                            this.unflipTilesForWord(word, this.tiles);
                            return this;
                        }
                        return this;
                        // No potential steals exist
                    } else {
                        // Word is not a steal (from the player submitting OR any other players' words),
                        // so it needs to be a word made up ENTIRELY of the middle tiles.
                        if (this.areAllLettersInWordFromMiddle(word)) {
                            console.log("Word is using all its letters from the middle!");
                            player.attributeWord(word);
                            this.flippedLetters = this.subtractLetterArrays(this.flippedLetters, word.split(''));
                            this.unflipTilesForWord(word, this.tiles);
                            return this;
                        } else {
                            console.log("Word is neither a steal nor the word be made from the letters in the middle.");
                            // Create Error class for custom game/word errors.
                            throw new Error(
                                `❌ Word is NOT an anagram of any other word in the game, nor can it be made from the middle letters.`
                            );

                        }

                    }
                } else {
                    console.log("Word is NOT in the dictionary!");
                    // Create Error class for custom game/word errors.
                    throw new Error(
                        `❌ Word is NOT in the dictionary.`
                    );
                }
            } else {
                console.log("Word is NOT using a letter from the middle! Or is using a letter not in the game right now.");
                throw new Error(
                    `❌ Word is NOT using a letter from the middle.`
                );
            }
            // Check now if word is in dictionary
        } else {
            // Word does not meet minimum length
            console.log(`Word does NOT meet minimum length: ${this.minimumLength}.`);
            // Create Error class for custom game/word errors.
            throw new Error(
                `❌ Word does NOT meet minimum length: ${this.minimumWordLength}.`
            );
        }
    }
}

module.exports = Game;
