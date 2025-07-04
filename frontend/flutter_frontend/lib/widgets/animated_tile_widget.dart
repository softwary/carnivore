import 'package:flutter/material.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/widgets/tile_widget.dart';

class AnimatedTileWidget extends StatefulWidget {
  final Tile tile;
  final double tileSize;
  final Function(Tile, bool) onClickTile;
  final bool isSelected;
  final Color selectingPlayerColor;
  final GlobalKey? globalKey;

  const AnimatedTileWidget({
    Key? key,
    required this.tile,
    required this.tileSize,
    required this.onClickTile,
    required this.isSelected,
    required this.selectingPlayerColor,
    this.globalKey,
  }) : super(key: key);

  @override
  _AnimatedTileWidgetState createState() => _AnimatedTileWidgetState();
}

class _AnimatedTileWidgetState extends State<AnimatedTileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  final Color _startColor = const Color(0xFFAB47BC); // A lighter purple
  final Color _endColor = const Color(0xFF4A148C);   // The standard middle tile purple

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _colorAnimation = ColorTween(begin: _startColor, end: _endColor).animate(_controller)
      ..addListener(() {
        setState(() {});
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color tileColor = widget.isSelected ? widget.selectingPlayerColor : _colorAnimation.value ?? _endColor;
    
    return TileWidget(
      key: ValueKey(widget.tile.tileId),
      tile: widget.tile,
      globalKey: widget.globalKey,
      tileSize: widget.tileSize,
      onClickTile: widget.onClickTile,
      isSelected: widget.isSelected,
      backgroundColor: tileColor,
    );
  }
}
