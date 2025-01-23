import 'package:flutter/material.dart';

class HorizontalReorderableListView extends StatefulWidget {
  final List<Map<String, String>> items;
  final Widget Function(Map<String, String>) itemBuilder;
  final Function(List<Map<String, String>>) onReorderFinished; // Callback function

  const HorizontalReorderableListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorderFinished, // Add to constructor
  });

  @override
  State<HorizontalReorderableListView> createState() =>
      _HorizontalReorderableListViewState();
}

class _HorizontalReorderableListViewState
    extends State<HorizontalReorderableListView> {
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  @override
  void didUpdateWidget(covariant HorizontalReorderableListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _items = widget.items;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final Map<String, String> item = _items.removeAt(oldIndex);
            _items.insert(newIndex, item);
            widget.onReorderFinished(_items); // Call the callback here
          });
        },
        children: _items.map((item) {
          return SizedBox(
            key: ValueKey(item['tileId']),
            width: 100,
            child: widget.itemBuilder(item),
          );
        }).toList(),
      ),
    );
  }
}

