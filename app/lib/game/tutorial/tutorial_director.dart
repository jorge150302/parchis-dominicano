import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/game_controller.dart';
import '../logic/game_engine.dart';
import 'tutorial_script.dart';

/// Runs [tutorialSteps] on a local match. Each step starts once the board
/// is still (no dice rolling, no token moving), so the text always matches
/// what the player sees; nothing waits on fixed timers except a short beat
/// after an action, to let its animation read before the next text.
class TutorialDirector extends ChangeNotifier {
  TutorialDirector(
    this.controller, {
    this.steps = tutorialSteps,
    this.beat = const Duration(milliseconds: 700),
  });

  final LocalGameController controller;
  final List<TutorialStep> steps;
  final Duration beat;

  int _index = -1;
  bool _waitingForTap = false;
  bool _disposed = false;
  final List<Completer<void>> _waits = [];

  /// The current step; null before [start] and once [isDone].
  TutorialStep? get step =>
      _index >= 0 && _index < steps.length ? steps[_index] : null;
  int get stepIndex => _index;
  bool get isDone => _index >= steps.length;

  /// A read step is showing and waits for [next].
  bool get waitingForTap => _waitingForTap;

  /// The learner may roll or move now.
  bool get waitingForUser => controller.tutorialUserCanAct;

  int get sceneCount => steps.fold(0, (m, s) => s.scene > m ? s.scene : m);

  bool get _showsMove =>
      step?.kind == TutorialStepKind.userTurn &&
      controller.engine.phase == GamePhase.choosing_token;

  String? get textKey {
    final s = step;
    if (s == null) return null;
    return _showsMove ? (s.moveTextKey ?? s.textKey) : s.textKey;
  }

  /// What the card points at. While the learner picks a token, that is the
  /// step's move target plus every token they may move (on its cell, or
  /// their home zone), so the card never hides one.
  TutorialTarget get target {
    final s = step;
    if (s == null) return const TutorialTarget();
    if (!_showsMove) return s.target;
    final extra = s.moveTarget ?? const TutorialTarget();
    final player = controller.currentPlayer;
    final cells = [...extra.cells];
    var atHome = false;
    for (final id in controller.movableTokenIds) {
      final position = player.tokens[id].position;
      if (position <= 0) {
        atHome = true;
      } else if (!cells.contains(position)) {
        cells.add(position);
      }
    }
    return TutorialTarget(
      homeOf: atHome ? player.id : extra.homeOf,
      cells: cells,
    );
  }

  void start() {
    controller.addListener(_onController);
    _enter(0);
  }

  /// Leaves a read step.
  void next() {
    if (!_waitingForTap) return;
    _waitingForTap = false;
    _enter(_index + 1);
  }

  void _onController() {
    for (final w in List.of(_waits)) {
      if (!w.isCompleted) w.complete();
    }
    _waits.clear();
    // The text follows the dice (roll text -> move text).
    if (!_disposed) notifyListeners();
  }

  bool get _settled {
    if (controller.rollingDice || controller.isFanfarePlaying) return false;
    final phase = controller.engine.phase;
    if (phase == GamePhase.finished) return true;
    return phase == GamePhase.idle && !controller.inputLocked;
  }

  /// Completes once [test] holds, re-checking on every controller change.
  Future<void> _until(bool Function() test) async {
    while (!_disposed && !test()) {
      final w = Completer<void>();
      _waits.add(w);
      await w.future;
    }
  }

  Future<void> _beat() => Future.delayed(beat);

  Future<void> _enter(int i) async {
    if (_disposed) return;
    _index = i;
    controller.tutorialUserCanAct = false;
    controller.tutorialMovable = null;
    if (isDone) {
      if (!_disposed) notifyListeners();
      return;
    }
    final s = steps[i];
    notifyListeners();
    await _until(() => _settled);
    if (_disposed) return;

    final setup = s.setup;
    if (setup != null) controller.tutorialSetup(setup.positions, setup.current);
    controller.scriptedDice
      ..clear()
      ..addAll(s.dice);

    switch (s.kind) {
      case TutorialStepKind.read:
        _waitingForTap = true;
        notifyListeners();

      case TutorialStepKind.userTurn:
        final serial = controller.turnSerial;
        controller.tutorialMovable = s.onlyTokens;
        controller.tutorialUserCanAct = true;
        notifyListeners();
        await _until(() => controller.turnSerial > serial && _settled);
        if (_disposed) return;
        controller.tutorialUserCanAct = false;
        await _beat();
        if (!_disposed) _enter(i + 1);

      case TutorialStepKind.rival:
        for (var r = 0; r < s.dice.length; r++) {
          await _until(() => _settled);
          await _beat();
          if (_disposed) return;
          final serial = controller.turnSerial;
          await controller.rollDice();
          if (_disposed) return;
          if (controller.engine.phase == GamePhase.choosing_token) {
            await _beat();
            if (_disposed) return;
            final want = r < s.rivalTokens.length ? s.rivalTokens[r] : null;
            final movable = controller.movableTokenIds;
            await controller.selectToken(
              want != null && movable.contains(want) ? want : movable.first,
            );
          }
          await _until(() => controller.turnSerial > serial && _settled);
        }
        if (_disposed) return;
        await _beat();
        if (!_disposed) _enter(i + 1);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_onController);
    for (final w in _waits) {
      if (!w.isCompleted) w.complete();
    }
    super.dispose();
  }
}
