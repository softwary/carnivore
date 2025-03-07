import 'package:flutter/material.dart';

class HorizontalReorderableListView extends StatefulWidget {
  final List<Map<String, String>> items;
  final Widget Function(Map<String, String>) itemBuilder;
  final Function(List<int>) onReorderFinished; // Callback function

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

            // Extract tileIds before calling the callback
            final List<int> tileIds =
                _items.map((item) => int.parse(item['tileId']!)).toList();
            widget.onReorderFinished(tileIds); // Pass only tileIds
            print("onReorderFinished tileIds= $tileIds");
          });
        },
        children: _items.map((item) {
          return SizedBox(
            key: ValueKey(item['tileId']),
            width: 50,
            child: widget.itemBuilder(item),
          );
        }).toList(),
      ),
    );
  }
}
