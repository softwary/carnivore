import 'package:flutter/material.dart';

class TileWidget extends StatefulWidget {
  final String letter;
  final String tileId;
  final Function(String) onClickTile;

  const TileWidget({
    super.key,
    required this.letter,
    required this.tileId,
    required this.onClickTile,
  });

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget> {
  bool _isSelected = false;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSelected = !_isSelected;
        });
        widget.onClickTile(widget.tileId);
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: _isSelected ? Colors.yellow : Colors.transparent, // Conditional border color
            width: 2.0,
          ),
        ),
        child: Center( // Center the Text widget
          child: Text(
            widget.letter.isNotEmpty ? widget.letter.trim() : '?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium!.copyWith(
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}