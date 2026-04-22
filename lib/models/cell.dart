/// 连连看格子模型
class Cell {
  final int id;
  final int row;
  final int col;
  final String emoji;
  final String ttsLabel;
  final bool isEliminated;

  const Cell({
    required this.id,
    required this.row,
    required this.col,
    required this.emoji,
    required this.ttsLabel,
    this.isEliminated = false,
  });

  Cell copyWith({
    int? id,
    int? row,
    int? col,
    String? emoji,
    String? ttsLabel,
    bool? isEliminated,
  }) {
    return Cell(
      id: id ?? this.id,
      row: row ?? this.row,
      col: col ?? this.col,
      emoji: emoji ?? this.emoji,
      ttsLabel: ttsLabel ?? this.ttsLabel,
      isEliminated: isEliminated ?? this.isEliminated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cell &&
        other.id == id &&
        other.row == row &&
        other.col == col &&
        other.emoji == emoji &&
        other.ttsLabel == ttsLabel &&
        other.isEliminated == isEliminated;
  }

  @override
  int get hashCode {
    return Object.hash(id, row, col, emoji, ttsLabel, isEliminated);
  }

  @override
  String toString() {
    return 'Cell(id:$id, row:$row, col:$col, emoji:$emoji, ttsLabel:$ttsLabel, eliminated:$isEliminated)';
  }
}
