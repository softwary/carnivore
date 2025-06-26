import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_frontend/classes/tile.dart';
import 'package:flutter_frontend/widgets/tile_widget.dart';
import 'package:flutter_frontend/screens/game_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

mixin StealAnimationMixin<T extends ConsumerState<GameScreen>> on TickerProvider {
  // Helper getter to access GameScreenState-specific members
  GameScreenState get _gs => (this as T) as GameScreenState;

  void startStealAnimation({
    required String? originalWordId,
    required String newWordId,
    required List<String> tileIds,
    required String fromPlayerId,
    required String toPlayerId,
    Map<String, Offset>? overrideStartPositions,
    Map<String, Size>? overrideStartSizes,
  }) async {
    if (!_gs._gs.mounted) return;
    if (_gs.animatingWordIds.contains(newWordId)) return;
    _gs.animatingWordIds.add(newWordId);

    List<AnimationController> controllers = [];
    List<OverlayEntry> entries = [];
    List<Timer> delayTimers = [];
    bool isAnimationCancelled = false;

    List<ScrollPosition> trackingScrollPositions = [];
    List<Offset> initialScrollOffsets = [];

    void captureScrollPositions() {
      trackingScrollPositions.clear();
      initialScrollOffsets.clear();

      ScrollableState? findScrollableAncestor(BuildContext? context) {
        if (context == null) return null;
        return Scrollable.of(context);
      }

      for (var tileId in tileIds) {
        final sourceKey = _gs.tileGlobalKeys[tileId];
        if (sourceKey?.currentContext != null) {
          final scrollable = findScrollableAncestor(sourceKey!.currentContext);
          if (scrollable != null &&
              !trackingScrollPositions.contains(scrollable.position)) {
            trackingScrollPositions.add(scrollable.position);
            initialScrollOffsets.add(Offset(
              scrollable.position.pixels,
              (scrollable.axisDirection == AxisDirection.down ||
                      scrollable.axisDirection == AxisDirection.up)
                  ? scrollable.position.pixels
                  : 0.0,
            ));
          }
        }

        final destKey = _gs.tileGlobalKeys[tileId]; // Assuming destination uses the same key
        if (destKey?.currentContext != null) {
          final scrollable = findScrollableAncestor(destKey!.currentContext);
          if (scrollable != null &&
              !trackingScrollPositions.contains(scrollable.position)) {
            trackingScrollPositions.add(scrollable.position);
            initialScrollOffsets.add(Offset(
              scrollable.position.pixels,
              (scrollable.axisDirection == AxisDirection.down ||
                      scrollable.axisDirection == AxisDirection.up)
                  ? scrollable.position.pixels
                  : 0.0,
            ));
          }
        }
      }
    }

    Offset getScrollDelta(int index) {
      if (index >= trackingScrollPositions.length) return Offset.zero;
      final scrollPosition = trackingScrollPositions[index];
      final initialOffset = index < initialScrollOffsets.length
          ? initialScrollOffsets[index]
          : Offset.zero;
      final double dx = scrollPosition.axis == Axis.horizontal
          ? scrollPosition.pixels - initialOffset.dx
          : 0.0;
      final double dy = scrollPosition.axis == Axis.vertical
          ? scrollPosition.pixels - initialOffset.dy
          : 0.0;
      return Offset(dx, dy);
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!_gs.mounted) {
      _gs.animatingWordIds.remove(newWordId);
      return;
    }

    captureScrollPositions();

    final overlay = Overlay.of(this._gs.context);
    if (overlay == null) {
      _gs.animatingWordIds.remove(newWordId);
      return;
    }
    final overlayContext = overlay.context;
    final overlayRenderObject = overlayContext.findRenderObject();
    if (overlayRenderObject == null) {
      _gs.animatingWordIds.remove(newWordId);
      return;
    }

    void cleanupAnimations() {
      if (isAnimationCancelled) return;
      isAnimationCancelled = true;
      for (var timer in delayTimers) {
        timer.cancel();
      }
      delayTimers.clear();
      for (var entry in entries) {
        try {
          if (entry.mounted) entry.remove();
        } catch (e) {
          // Handle error if needed
        }
      }
      entries.clear();
      for (var controller in controllers) {
        try {
          if (controller.isAnimating) controller.stop();
          controller.dispose();
        } catch (e) {
          // Handle error if needed
        }
      }
      controllers.clear();
      _gs.animatingWordIds.remove(newWordId);
      if (_gs.mounted) {
        _gs.setState(() {
          _gs.destinationWordIdsForAnimation.remove(newWordId);
          if (originalWordId != null) {
            _gs.sourceWordIdsForAnimation.remove(originalWordId);
          }
        });
      }
    }

    for (int i = 0; i < tileIds.length; i++) {
      final tileId = tileIds[i];
      // Use _gs.allTiles to retrieve the tile
      final tileData = _gs.allTiles.firstWhere(
          (t) => t.tileId.toString() == tileId,
          orElse: () => Tile(letter: '', tileId: '', location: ''));
      if (tileData.tileId == '') continue;

      Offset? startPosition;
      Size? startSize;
      if (overrideStartPositions != null &&
          overrideStartPositions.containsKey(tileId)) {
        startPosition = overrideStartPositions[tileId];
        startSize = overrideStartSizes != null ? overrideStartSizes[tileId] : null;
      }
      startPosition ??= _gs.previousTileGlobalPositions[tileId];
      startSize ??= _gs.previousTileSizes[tileId];
      if (startPosition == null || startSize == null) continue;

      final endKey = _gs.tileGlobalKeys[tileId];
      if (endKey == null || endKey.currentContext == null) continue;

      // Determine the starting color for the animation based on origin
      final Color animationStartColor = (originalWordId == null)
          ? (_gs.playerColorMap[toPlayerId] ?? Colors.purple) // If from middle, start with target player's color
          : (_gs.playerColorMap[fromPlayerId] ?? Colors.grey); // If from a player, start with their color

      final growController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      controllers.add(growController);

      final growAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.5), weight: 50),
        TweenSequenceItem(tween: Tween<double>(begin: 1.5, end: 1.0), weight: 50),
      ]).animate(CurvedAnimation(parent: growController, curve: Curves.easeInOut));

      final moveController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      controllers.add(moveController);

      OverlayEntry? overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) {
          Offset getUpdatedEndPosition() {
            if (endKey.currentContext == null || !_gs.mounted || isAnimationCancelled) {
              return startPosition ?? Offset.zero;
            }
            final RenderBox? endBox =
                endKey.currentContext!.findRenderObject() as RenderBox?;
            if (endBox == null || !endBox.hasSize || !endBox.attached) {
              return startPosition ?? Offset.zero;
            }
            try {
              return endBox.localToGlobal(Offset.zero, ancestor: overlayRenderObject);
            } catch (e) {
              return startPosition ?? Offset.zero;
            }
          }

          Offset adjustForScroll(Offset basePosition) {
            Offset scrollAdjustment = Offset.zero;
            for (int scrollIndex = 0; scrollIndex < trackingScrollPositions.length; scrollIndex++) {
              final delta = getScrollDelta(scrollIndex);
              scrollAdjustment = Offset(scrollAdjustment.dx - delta.dx, scrollAdjustment.dy - delta.dy);
            }
            return Offset(basePosition.dx + scrollAdjustment.dx, basePosition.dy + scrollAdjustment.dy);
          }

          final adjustedStartPosition = adjustForScroll(startPosition ?? Offset.zero);
          final currentEndPosition = getUpdatedEndPosition();
          final moveAnimation = Tween<Offset>(
            begin: adjustedStartPosition,
            end: currentEndPosition,
          ).animate(CurvedAnimation(parent: moveController, curve: Curves.easeInOutCubic));

          return Stack(
            children: [
              AnimatedBuilder(
                animation: growAnimation,
                builder: (context, child) {
                  if (moveController.value > 0.0) return const SizedBox.shrink();
                  return Positioned(
                    left: adjustForScroll(startPosition ?? Offset.zero).dx,
                    top: adjustForScroll(startPosition ?? Offset.zero).dy,
                    child: Transform.scale(
                      scale: growAnimation.value,
                      child: Material(
                        type: MaterialType.transparency,
                        child: TileWidget(
                          tile: tileData,
                          tileSize: startSize?.width ?? 0,
                          onClickTile: (_, __) {},
                          isSelected: false,
                          backgroundColor: animationStartColor, // Use the determined start color
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: moveAnimation,
                builder: (context, child) {
                  if (moveController.value == 0.0) return const SizedBox.shrink();
                  final scale = 1.0 + (0.2 * (1 - (moveController.value - 0.5).abs() * 2));
                  return Positioned(
                    left: moveAnimation.value.dx,
                    top: moveAnimation.value.dy,
                    child: Transform.scale(
                      scale: scale,
                      child: Material(
                        type: MaterialType.transparency,
                        child: TileWidget(
                          tile: tileData,
                          tileSize: startSize?.width ?? 0,
                          onClickTile: (_, __) {},
                          isSelected: false,
                          backgroundColor: Color.lerp(
                            animationStartColor, // Animate from the determined start color
                            _gs.playerColorMap[toPlayerId] ?? Colors.purple,
                            moveController.value,
                          ) ?? Colors.purple,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
      entries.add(overlayEntry);
      overlay.insert(overlayEntry);
      final timer = Timer(Duration(milliseconds: i * 200), () {
        if (isAnimationCancelled || !_gs.mounted) return;
        growController.forward().then((_) {
          if (isAnimationCancelled || !_gs.mounted) return;
          moveController.forward().then((_) {
            if (i == tileIds.length - 1) {
              Timer(const Duration(milliseconds: 200), () {
                if (_gs.mounted && !isAnimationCancelled) cleanupAnimations();
              });
            }
          });
        });
      });
      delayTimers.add(timer);
    }

    Timer(const Duration(seconds: 5), () {
      if (!isAnimationCancelled && _gs.mounted) {
        cleanupAnimations();
      }
    });
  }
}