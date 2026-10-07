import 'package:flutter/foundation.dart';

class Clock extends ChangeNotifier {
  double now = 0;

  void notify() {
    notifyListeners();
  }
}
