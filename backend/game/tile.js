class Tile {
    constructor(tileId, isFlipped = false, inMiddle = false) {
        this.tileId = tileId;
        this.letter = ''; // Initially empty, to be assigned by the Game class
        this.isFlipped = isFlipped;
        this.inMiddle = inMiddle;
    }

    flip() {
        this.isFlipped = true;
        this.inMiddle = true;
    }
}

module.exports = Tile;
