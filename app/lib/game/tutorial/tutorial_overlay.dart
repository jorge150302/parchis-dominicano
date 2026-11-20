import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/language_provider.dart';
import '../../service/audio_service.dart';
import 'tutorial_director.dart';
import 'tutorial_script.dart';

/// Keys of what the tutorial can point at: dice and home zones by player
/// id, board cells by number. GameScreen hands them to those widgets.
class TutorialAnchors {
  final Map<String, GlobalKey> _dice = {};
  final Map<String, GlobalKey> _home = {};
  final Map<int, GlobalKey> cells = {};

  GlobalKey diceOf(String playerId) =>
      _dice.putIfAbsent(playerId, GlobalKey.new);
  GlobalKey homeOf(String playerId) =>
      _home.putIfAbsent(playerId, GlobalKey.new);

  List<GlobalKey> keysFor(TutorialTarget target) => [
    if (target.diceOf != null) diceOf(target.diceOf!),
    if (target.homeOf != null) homeOf(target.homeOf!),
    for (final c in target.cells)
      if (cells[c] != null) cells[c]!,
  ];
}

/// The tutorial layer over the match: dims the screen except what the step
/// points at, rings it, and shows the step's card on the opposite side.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.director,
    required this.anchors,
    required this.onSkip,
    required this.onMenu,
    required this.onPlayAi,
  });

  final TutorialDirector director;
  final TutorialAnchors anchors;
  final VoidCallback onSkip;
  final VoidCallback onMenu;
  final VoidCallback onPlayAi;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  List<Rect> _rects = const [];

  @override
  void initState() {
    super.initState();
    widget.director.addListener(_changed);
  }

  @override
  void dispose() {
    widget.director.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Target rects in this overlay's coordinates, measured after layout.
  void _measure() {
    if (!mounted) return;
    final self = context.findRenderObject() as RenderBox?;
    if (self == null || !self.hasSize) return;
    final rects = <Rect>[];
    for (final key in widget.anchors.keysFor(widget.director.target)) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: self);
      rects.add(topLeft & box.size);
    }
    if (!_sameRects(rects, _rects)) setState(() => _rects = rects);
  }

  static bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].topLeft - b[i].topLeft).distance > 0.5 ||
          a[i].size != b[i].size) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final director = widget.director;
    if (director.isDone) {
      return _FinishCard(onMenu: widget.onMenu, onPlayAi: widget.onPlayAi);
    }

    final step = director.step;
    final textKey = director.textKey;
    if (step == null || textKey == null) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final reading = director.waitingForTap;
    final rings = [for (final r in _rects) r.inflate(5)];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Reading: the whole screen continues. Acting: taps reach the game.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !reading,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _next,
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      rings,
                      dim: reading ? 0.6 : 0.35,
                    ),
                  ),
                ),
              ),
            ),
            for (final r in rings)
              Positioned.fromRect(
                rect: r,
                child: IgnorePointer(
                  child:
                      DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.orangeAccent,
                                width: 3,
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(
                            begin: 1,
                            end: 1.12,
                            duration: 600.ms,
                            curve: Curves.easeInOut,
                          ),
                ),
              ),
            if (rings.isNotEmpty)
              _arrowAt(
                rings.first,
                below: rings.first.center.dy < constraints.maxHeight / 2,
              ),
            // Placed at layout time, knowing the card's real size.
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _CardSpot(rings),
                // While the learner acts, taps go through the card to the game.
                child: IgnorePointer(
                  ignoring: !reading,
                  child: _StepCard(
                    key: ValueKey(
                      'tutorial_card_${director.stepIndex}_$textKey',
                    ),
                    text: context.translate(textKey),
                    scene: step.scene,
                    sceneCount: director.sceneCount,
                    reading: reading,
                    acting: director.waitingForUser,
                    onNext: _next,
                    onSkip: widget.onSkip,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A bouncing arrow beside [r], on the side with more room.
  Widget _arrowAt(Rect r, {required bool below}) {
    const size = 34.0;
    return Positioned(
      left: r.center.dx - size / 2,
      top: below ? r.bottom + 2 : r.top - size - 2,
      child: IgnorePointer(
        child:
            Icon(
                  below
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: size,
                  color: Colors.orangeAccent,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                  begin: 0,
                  end: below ? 6 : -6,
                  duration: 450.ms,
                  curve: Curves.easeInOut,
                ),
      ),
    );
  }

  void _next() {
    if (!widget.director.waitingForTap) return;
    AudioService.playClick();
    widget.director.next();
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.text,
    required this.scene,
    required this.sceneCount,
    required this.reading,
    required this.acting,
    required this.onNext,
    required this.onSkip,
  });

  final String text;
  final int scene;
  final int sceneCount;
  final bool reading;
  final bool acting;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Small screens: a tighter card, so it never covers half the board.
    final compact = MediaQuery.sizeOf(context).height < 700;
    const smallButton = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('tutorial_card'),
        padding: EdgeInsets.fromLTRB(14, compact ? 4 : 8, 6, compact ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.brown.shade900,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.orange, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.translate(
                    'tut_progress',
                    args: {'n': '$scene', 'total': '$sceneCount'},
                  ),
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!reading) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      context.translate(acting ? 'tut_your_move' : 'tut_watch'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  key: const Key('tutorial_skip'),
                  style: smallButton,
                  onPressed: () {
                    AudioService.playClick();
                    onSkip();
                  },
                  child: Text(
                    context.translate('tut_skip'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                text,
                key: const Key('tutorial_text'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
            ),
            if (reading) ...[
              SizedBox(height: compact ? 4 : 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  key: const Key('tutorial_next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    visualDensity: compact ? VisualDensity.compact : null,
                  ),
                  onPressed: onNext,
                  child: Text(
                    context.translate('tut_next'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 200.ms),
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({required this.onMenu, required this.onPlayAi});

  final VoidCallback onMenu;
  final VoidCallback onPlayAi;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: const Key('tutorial_finish'),
          padding: EdgeInsets.all(compact ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.brown.shade900,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.orange, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎉', style: TextStyle(fontSize: compact ? 30 : 40)),
                SizedBox(height: compact ? 4 : 8),
                Text(
                  context.translate('tut_done_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: compact ? 19 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  context.translate('tut_done_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 14 : 15,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: compact ? 12 : 20),
                ElevatedButton(
                  key: const Key('tutorial_play_ai'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    AudioService.playClick();
                    onPlayAi();
                  },
                  child: Text(
                    context.translate('tut_play_ai'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('tutorial_menu'),
                  onPressed: () {
                    AudioService.playClick();
                    onMenu();
                  },
                  child: Text(
                    context.translate('tut_menu'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }
}

/// Where the step card goes: of bottom, top and middle, the spot covering
/// the least of [rings] (a token to tap must stay visible), then the one
/// farthest from them. Always fully on screen.
class _CardSpot extends SingleChildLayoutDelegate {
  _CardSpot(this.rings);

  final List<Rect> rings;
  static const _margin = 8.0, _side = 12.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(
        width: constraints.maxWidth - 2 * _side,
      ).copyWith(maxHeight: constraints.maxHeight - 2 * _margin);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final lowest = (size.height - childSize.height - _margin).clamp(
      _margin,
      double.infinity,
    );
    final spots = [lowest, _margin, (lowest + _margin) / 2];
    if (rings.isEmpty) return Offset(_side, spots.first);
    final focus =
        rings.map((r) => r.center).reduce((a, b) => a + b) /
        rings.length.toDouble();
    var bestTop = spots.first;
    var bestScore = double.infinity;
    for (final top in spots) {
      final card = Offset(_side, top) & childSize;
      var covered = 0.0;
      for (final r in rings) {
        final i = r.intersect(card);
        if (i.width > 0 && i.height > 0) covered += i.width * i.height;
      }
      final score = covered * 1000 - (card.center - focus).distance;
      if (score < bestScore) {
        bestScore = score;
        bestTop = top;
      }
    }
    return Offset(_side, bestTop);
  }

  @override
  bool shouldRelayout(_CardSpot old) => !listEquals(old.rings, rings);
}

/// Dims everything but rounded holes over [holes].
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.holes, {required this.dim});

  final List<Rect> holes;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRect(Offset.zero & size);
    for (final h in holes) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addRRect(RRect.fromRectAndRadius(h, const Radius.circular(10))),
      );
    }
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: dim));
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.dim != dim || old.holes != holes;
}
