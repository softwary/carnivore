import 'package:flutter/material.dart';

class TileWidget extends StatefulWidget {
  final String letter;
  final String tileId;
  final Function(String, String, bool) onClickTile;
  final bool isSelected;

  const TileWidget({
    Key? key,
    required this.letter,
    required this.tileId,
    required this.onClickTile,
    required this.isSelected,
  }) : super(key: key);

  @override
  _TileWidgetState createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        print("TileWidget onTap called: letter=${widget.letter}, tileId=${widget.tileId}, isSelected=${widget.isSelected}");
        widget.onClickTile(widget.letter, widget.tileId, !widget.isSelected);
      },
      child: Container(
        padding: const EdgeInsets.all(1.0), // Reduced padding
        decoration: BoxDecoration(
          color: widget.isSelected ? Colors.purple[700] : Colors.purple[900],
          border: Border.all(
            color: widget.isSelected ? Colors.white : Colors.transparent,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Center(
          child: Text(
            widget.letter,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16, // Reduced font size
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}