class Tile {
    constructor(tileId, isFlipped = false) {
        this.tileId = tileId;
        this.letter = ''; // Initially empty, to be assigned by the Game class
        this.isFlipped = isFlipped;
    }

    flip() {
        this.isFlipped = true;
    }
}

module.exports = Tile;
