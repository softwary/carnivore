class Tile {
  String? letter;
  String? location;
  dynamic tileId;
  int? flippedTimestamp;


  Tile({
    required this.letter,
    required this.location,
    required this.tileId,
    this.flippedTimestamp,
  });

  factory Tile.fromMap(Map<String, dynamic> map) {
    return Tile(
      letter: map['letter'],
      location: map['location'],
      tileId: map['tileId'],
      flippedTimestamp: map['flippedTimestamp'],
    );
  }
}