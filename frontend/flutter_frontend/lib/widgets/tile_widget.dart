import 'package:flutter/material.dart';

class TileWidget extends StatefulWidget {
  final String letter;
  final String tileId;
  final Function(String, String, bool) onClickTile;
  final bool isSelected;
  final Color backgroundColor; // Background color property
  final double tileSize;

  const TileWidget({
    Key? key,
    required this.letter,
    required this.tileId,
    required this.onClickTile,
    required this.tileSize,
    this.isSelected = false,
    this.backgroundColor = Colors.purple, // Default background color
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
        width: widget.tileSize,
        height: widget.tileSize,
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          color: widget.isSelected ? Color(0xFF4A148C) : widget.backgroundColor,
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
              fontSize: widget.tileSize * 0.5,
              color: Colors.white, // Always white text
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}