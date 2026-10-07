import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/turkey_core.dart';
import 'odds.dart';

class Wallet extends ChangeNotifier {
  Wallet(this._box)
    : balance = _storedBalance(_box),
      stake = _fitStored(_box),
      difficulty = _storedDiff(_box);

  static int get minStake => ttMinStake();

  static int get opening => ttOpening();

  static int get pocket => ttPocket();

  static const _balanceKey = 'balance';
  static const _stakeKey = 'stake';
  static const _diffKey = 'difficulty';

  final SharedPreferences _box;
  int balance;
  int stake;
  Diff difficulty;

  DiffSpec get spec => DiffSpec.of(difficulty);

  bool get broke => ttBroke(balance.toDouble());

  void setStake(int value) {
    final next = ttFitStake(value.toDouble(), balance.toDouble());
    if (next == stake) return;
    stake = next;
    _box.setInt(_stakeKey, stake);
    notifyListeners();
  }

  int shifted(int direction) {
    return ttNudge(stake.toDouble(), direction.toDouble(), balance.toDouble());
  }

  void setDifficulty(Diff value) {
    if (value == difficulty) return;
    difficulty = value;
    _box.setInt(_diffKey, value.index);
    notifyListeners();
  }

  bool spend(int amount) {
    if (!ttCanSpend(amount.toDouble(), balance.toDouble())) return false;
    balance = ttDebit(balance.toDouble(), amount.toDouble());
    stake = ttStakeAfterSpend(stake.toDouble(), balance.toDouble());
    _box.setInt(_balanceKey, balance);
    _box.setInt(_stakeKey, stake);
    notifyListeners();
    return true;
  }

  void credit(int amount) {
    final next = ttCredit(balance.toDouble(), amount.toDouble());
    if (next == balance) return;
    balance = next;
    _box.setInt(_balanceKey, balance);
    notifyListeners();
  }

  static int _storedBalance(SharedPreferences box) {
    final stored = box.getInt(_balanceKey);
    final raw = stored?.toDouble() ?? ttOpening().toDouble();
    return ttNonNegative(raw);
  }

  static int _fitStored(SharedPreferences box) {
    final balance = _storedBalance(box);
    final raw = box.getInt(_stakeKey) ?? ttStartingStake();
    return ttFitStake(raw.toDouble(), balance.toDouble());
  }

  static Diff _storedDiff(SharedPreferences box) {
    final index = box.getInt(_diffKey) ?? 0;
    if (index < 0 || index >= Diff.values.length) return Diff.easy;
    return Diff.values[index];
  }
}
