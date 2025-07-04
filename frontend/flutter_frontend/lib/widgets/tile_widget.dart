import 'package:flutter/material.dart';
import 'package:flutter_frontend/classes/tile.dart';

class TileWidget extends StatefulWidget {
  final Tile tile;
  final Function(Tile, bool) onClickTile;
  final bool isSelected;
  final Color backgroundColor; // Background color property
  final double tileSize;
  final GlobalKey? globalKey;

  const TileWidget({
    Key? key,
    required this.tile,
    required this.onClickTile,
    required this.tileSize,
    this.isSelected = false,
    this.backgroundColor = const Color(0xFF4A148C), // Default background color
    this.globalKey,
  }) : super(key: key);

  @override
  _TileWidgetState createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget> {
  @override
  Widget build(BuildContext context) {
    // debugPrint('💜TileWidget: ${widget.tile.letter} (ID: ${widget.tile.tileId?.toString()}) - isSelected: ${widget.isSelected}, backgroundColor: ${widget.backgroundColor}');
     
    return GestureDetector(
      key: widget.globalKey, 
      onTap: () {
        widget.onClickTile(widget.tile, !widget.isSelected);
      },
      child: Container(
        width: widget.tileSize,
        height: widget.tileSize,
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          border: Border.all(
            color: widget.isSelected ? Colors.white : Colors.transparent,
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
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}