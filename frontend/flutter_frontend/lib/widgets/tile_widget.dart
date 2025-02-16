import 'package:flutter/material.dart';

class TileWidget extends StatefulWidget {
  final String letter;
  final String tileId;
  final Function(String, String, bool) onClickTile;
  final bool isSelected;
  final Color textColor;
  final double tileSize; // NEW: Tile size parameter

  const TileWidget({
    Key? key,
    required this.letter,
    required this.tileId,
    required this.onClickTile,
    this.isSelected = false,
    this.textColor = Colors.black,
    this.tileSize = 40, // Default size
  }) : super(key: key);

  @override
  _TileWidgetState createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onClickTile(widget.letter, widget.tileId, !widget.isSelected);
      },
      child: Container(
        width: widget.tileSize, // Use dynamic size
        height: widget.tileSize, // Use dynamic size
        padding: const EdgeInsets.all(2.0), // Reduce padding for compact fit
        decoration: BoxDecoration(
          color: widget.isSelected ? Colors.purple[700] : Colors.purple[900],
          border: Border.all(
            color: widget.isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Center(
          child: Text(
            widget.letter,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.tileSize * 0.5, // Scale text to fit smaller tiles
              color: widget.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
