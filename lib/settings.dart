import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings(this._box) : haptics = _box.getBool(_hapticsKey) ?? true;

  static const _hapticsKey = 'haptics';

  final SharedPreferences _box;
  bool haptics;

  void setHaptics(bool value) {
    if (value == haptics) return;
    haptics = value;
    _box.setBool(_hapticsKey, value);
    notifyListeners();
    if (value) HapticFeedback.selectionClick();
  }

  void light() {
    if (haptics) HapticFeedback.lightImpact();
  }

  void medium() {
    if (haptics) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (haptics) HapticFeedback.heavyImpact();
  }
}
