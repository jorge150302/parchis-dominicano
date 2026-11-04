// lib/game/models/cell.dart

import 'board_action.dart';

enum CellType { normal, action }

class Cell {
  final int number;
  final CellType type;
  final BoardAction? action;

  Cell({
    required this.number,
    this.type = CellType.normal,
    this.action,
  });

  /// =====================================================
  /// 🔥 HELPERS (limpian el engine/controller)
  /// =====================================================

  bool get hasAction => action != null;

  bool get isStart => number == 0;

  bool get isFinish => number == 100;
}
