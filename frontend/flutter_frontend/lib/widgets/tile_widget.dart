import 'package:flutter/material.dart';

class TileWidget extends StatefulWidget {
  // Now a StatefulWidget
  final String letter;
  final String tileId;
  final Function(String, String, bool) onClickTile;
  final bool isSelected;

  const TileWidget({
    super.key,
    required this.letter,
    required this.tileId,
    required this.onClickTile,
    this.isSelected = false, // Default value for isSelected
  });

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget> {
  late bool _isSelected; // Use late for initialization in initState

  @override
  void initState() {
    super.initState();
    _isSelected = widget.isSelected; // Initialize from widget's property
  }

  @override
  void didUpdateWidget(covariant TileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected != widget.isSelected) {
      _isSelected = widget.isSelected;
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSelected = !_isSelected;
        });
        widget.onClickTile(
            widget.letter, widget.tileId, _isSelected); // Pass tileId as well
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: _isSelected ? Colors.yellow : Colors.transparent,
            width: 2.0,
          ),
        ),
        child: Center(
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
