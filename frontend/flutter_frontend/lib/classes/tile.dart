class Tile {
  String? letter;
  String? location;
  dynamic tileId;


  Tile({
    required this.letter,
    required this.location,
    required this.tileId,
  });

  factory Tile.fromMap(Map<String, dynamic> map) {
    return Tile(
      letter: map['letter'],
      location: map['location'],
      tileId: map['tileId'],
    );
  }
}