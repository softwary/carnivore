import 'package:flutter/material.dart';
import 'package:flutter_frontend/classes/tile.dart';

class SelectedLetterTile extends StatefulWidget {
  final Tile tile;
  final VoidCallback onRemove;
  final Color textColor;
  final Color backgroundColor;
  final double tileSize;

  const SelectedLetterTile({
    Key? key,
    required this.tile,
    required this.onRemove,
    required this.tileSize,
    this.textColor = Colors.white,
    this.backgroundColor = const Color(0xFF4A148C),
  }) : super(key: key);

  @override
  _TileWidgetState createState() => _TileWidgetState();
}

class _TileWidgetState extends State<SelectedLetterTile> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: widget.tileSize,
          height: widget.tileSize,
          padding: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Center(
            child: Text(
              widget.tile.letter ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.tileSize * 0.5,
                color: widget.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              padding: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
