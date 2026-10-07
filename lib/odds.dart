import 'core/turkey_core.dart';

enum Diff { easy, medium, hard, hardcore }

class DiffSpec {
  const DiffSpec({required this.diff, required this.label});

  final Diff diff;
  final String label;

  double get hitChance => ttHitChance(diff.index);

  int get lanes => ttLanes(diff.index);

  double stepAt(int index) => ttStep(diff.index, index);

  static const easy = DiffSpec(diff: Diff.easy, label: 'Easy');

  static const medium = DiffSpec(diff: Diff.medium, label: 'Medium');

  static const hard = DiffSpec(diff: Diff.hard, label: 'Hard');

  static const hardcore = DiffSpec(diff: Diff.hardcore, label: 'Hardcore');

  static const all = <DiffSpec>[easy, medium, hard, hardcore];

  static DiffSpec of(Diff diff) {
    return switch (diff) {
      Diff.easy => easy,
      Diff.medium => medium,
      Diff.hard => hard,
      Diff.hardcore => hardcore,
    };
  }
}
