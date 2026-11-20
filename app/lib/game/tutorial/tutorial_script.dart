// The first-run tutorial as data: short scenes on the medium board (the
// one online matches use), each played with the real rules. A scene places
// the tokens where it needs them, then the player acts or watches.
//
// Player '1' is the learner (red), player '2' the rival (blue). Positions
// are cells of the medium board: 13 go to start, 15 extra turn, 19 skip a
// turn, 24 jumps to 63, 100 is home. The dice are scripted, so every scene
// lands where its text says; test/tutorial_test.dart walks the whole script.

/// Learner and rival ids, as GameScreen creates the players.
const tutorialYou = '1';
const tutorialRival = '2';

enum TutorialStepKind {
  /// Text only; the player taps "Next".
  read,

  /// The learner rolls (and moves, when a token can).
  userTurn,

  /// The rival plays [TutorialStep.dice] by itself.
  rival,
}

/// What a step points at. Empty points at nothing.
class TutorialTarget {
  const TutorialTarget({this.diceOf, this.homeOf, this.cells = const []});

  final String? diceOf;
  final String? homeOf;
  final List<int> cells;

  bool get isEmpty => diceOf == null && homeOf == null && cells.isEmpty;
}

/// Token positions per player id (0 = at home, -1 = finished) and who plays.
class TutorialSetup {
  const TutorialSetup(this.positions, {this.current = tutorialYou});

  final Map<String, List<int>> positions;
  final String current;
}

class TutorialStep {
  const TutorialStep.read(
    this.textKey, {
    required this.scene,
    this.target = const TutorialTarget(),
    this.setup,
  }) : kind = TutorialStepKind.read,
       die = null,
       rivalDice = const [],
       onlyTokens = null,
       moveTextKey = null,
       moveTarget = null,
       rivalTokens = const [];

  const TutorialStep.userTurn(
    this.textKey, {
    required this.scene,
    required int this.die,
    this.moveTextKey,
    this.moveTarget,
    this.onlyTokens,
    this.setup,
  }) : kind = TutorialStepKind.userTurn,
       rivalDice = const [],
       target = const TutorialTarget(diceOf: tutorialYou),
       rivalTokens = const [];

  const TutorialStep.rival(
    this.textKey, {
    required this.scene,
    required List<int> dice,
    this.rivalTokens = const [],
    this.setup,
  }) : kind = TutorialStepKind.rival,
       die = null,
       rivalDice = dice,
       target = const TutorialTarget(diceOf: tutorialRival),
       onlyTokens = null,
       moveTextKey = null,
       moveTarget = null;

  final TutorialStepKind kind;

  /// Progress shown as "Step [scene] of N".
  final int scene;

  final String textKey;
  final TutorialTarget target;

  /// Applied before the step, once the board is still.
  final TutorialSetup? setup;

  /// userTurn: the learner's roll.
  final int? die;

  /// rival: the rival's rolls, in order.
  final List<int> rivalDice;

  /// The dice this step rolls, in order.
  List<int> get dice => die != null ? [die!] : rivalDice;

  /// userTurn: the text and target once the dice show a movable token.
  final String? moveTextKey;
  final TutorialTarget? moveTarget;

  /// userTurn: the only tokens the learner may move (null: any legal one).
  final Set<int>? onlyTokens;

  /// rival: the token to move after each roll (falls back to any legal one).
  final List<int> rivalTokens;
}

const _yourHome = TutorialTarget(homeOf: tutorialYou);

const tutorialSteps = <TutorialStep>[
  // 1. The goal.
  TutorialStep.read(
    'tut_goal',
    scene: 1,
    target: TutorialTarget(cells: [100]),
    setup: TutorialSetup({
      tutorialYou: [0, 0],
      tutorialRival: [0, 0],
    }),
  ),

  // 2. Leaving home takes any number.
  TutorialStep.userTurn(
    'tut_leave_roll',
    scene: 2,
    die: 3,
    moveTextKey: 'tut_leave_move',
    moveTarget: _yourHome,
  ),

  // 3. A 6 rolls again.
  TutorialStep.userTurn(
    'tut_six_roll',
    scene: 3,
    die: 6,
    moveTextKey: 'tut_six_move',
    setup: TutorialSetup({
      tutorialYou: [3, 0],
      tutorialRival: [0, 0],
    }),
  ),
  TutorialStep.userTurn(
    'tut_six_again',
    scene: 3,
    die: 2,
    moveTextKey: 'tut_move_any',
  ),

  // 4. Capturing sends the rival home and earns a roll.
  TutorialStep.read(
    'tut_capture_intro',
    scene: 4,
    target: TutorialTarget(cells: [20, 23]),
    setup: TutorialSetup({
      tutorialYou: [20, 0],
      tutorialRival: [23, 0],
    }),
  ),
  TutorialStep.userTurn(
    'tut_roll',
    scene: 4,
    die: 3,
    onlyTokens: {0},
    moveTextKey: 'tut_capture_move',
    moveTarget: TutorialTarget(cells: [20]),
  ),
  TutorialStep.read(
    'tut_capture_done',
    scene: 4,
    target: TutorialTarget(homeOf: tutorialRival),
  ),

  // 5. Special cells.
  TutorialStep.read(
    'tut_cells_intro',
    scene: 5,
    target: TutorialTarget(cells: [13, 15, 19, 24]),
    setup: TutorialSetup({
      tutorialYou: [12, 0],
      tutorialRival: [0, 0],
    }),
  ),
  TutorialStep.userTurn(
    'tut_cells_roll',
    scene: 5,
    die: 3,
    onlyTokens: {0},
    moveTextKey: 'tut_cells_move',
    moveTarget: TutorialTarget(cells: [12, 15]),
  ),
  TutorialStep.read(
    'tut_cell_extra',
    scene: 5,
    target: TutorialTarget(cells: [15]),
  ),
  TutorialStep.read(
    'tut_cell_skip',
    scene: 5,
    target: TutorialTarget(cells: [19]),
  ),
  TutorialStep.read(
    'tut_cell_start',
    scene: 5,
    target: TutorialTarget(cells: [13]),
  ),
  TutorialStep.read(
    'tut_cell_jump',
    scene: 5,
    target: TutorialTarget(cells: [24, 63]),
  ),

  // 6. Bridges block everyone.
  TutorialStep.read(
    'tut_bridge_intro',
    scene: 6,
    target: TutorialTarget(cells: [26, 30]),
    setup: TutorialSetup({
      tutorialYou: [30, 26],
      tutorialRival: [28, 27],
    }),
  ),
  TutorialStep.userTurn(
    'tut_roll',
    scene: 6,
    die: 4,
    onlyTokens: {1},
    moveTextKey: 'tut_bridge_move',
    moveTarget: TutorialTarget(cells: [26]),
  ),
  TutorialStep.read(
    'tut_bridge_done',
    scene: 6,
    target: TutorialTarget(cells: [30]),
  ),
  TutorialStep.rival('tut_bridge_rival', scene: 6, dice: [4]),
  TutorialStep.read(
    'tut_bridge_blocked',
    scene: 6,
    target: TutorialTarget(cells: [27, 28, 30]),
  ),

  // 7. The third 6 in a row is a penalty.
  TutorialStep.read(
    'tut_sixes_intro',
    scene: 7,
    target: TutorialTarget(diceOf: tutorialRival),
    setup: TutorialSetup({
      tutorialYou: [0, 0],
      tutorialRival: [40, 0],
    }, current: tutorialRival),
  ),
  TutorialStep.rival(
    'tut_sixes_rival',
    scene: 7,
    dice: [6, 6, 6],
    rivalTokens: [0, 0],
  ),
  TutorialStep.read(
    'tut_sixes_done',
    scene: 7,
    target: TutorialTarget(homeOf: tutorialRival),
  ),

  // 8. Home takes the exact number; the last token wins.
  TutorialStep.read(
    'tut_exact_intro',
    scene: 8,
    target: TutorialTarget(cells: [98, 99, 100]),
    setup: TutorialSetup({
      tutorialYou: [98, 99],
      tutorialRival: [0, 0],
    }),
  ),
  TutorialStep.userTurn('tut_exact_roll_over', scene: 8, die: 6),
  TutorialStep.read(
    'tut_exact_over',
    scene: 8,
    target: TutorialTarget(cells: [98, 99, 100]),
  ),
  TutorialStep.userTurn(
    'tut_exact_roll',
    scene: 8,
    die: 2,
    moveTextKey: 'tut_exact_move',
    moveTarget: TutorialTarget(cells: [98, 100]),
  ),
  TutorialStep.read(
    'tut_finish_bonus',
    scene: 8,
    target: TutorialTarget(cells: [100]),
  ),
  TutorialStep.userTurn(
    'tut_exact_last',
    scene: 8,
    die: 1,
    moveTextKey: 'tut_move_any',
    moveTarget: TutorialTarget(cells: [99, 100]),
  ),
];
