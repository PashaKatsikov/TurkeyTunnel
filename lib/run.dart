import 'dart:ffi';

import 'core/turkey_core.dart';
import 'odds.dart';

enum RoundPhase { betting, hopping, waiting, wrecked, cashed }

class Hop {
  Hop({
    required this.from,
    required this.to,
    required this.dies,
    required this.victory,
    required this.startedAt,
    required this.duration,
  });

  final int from;
  final int to;
  final bool dies;
  final bool victory;
  final double startedAt;
  final double duration;

  double progress(double now) {
    if (duration <= 0) return 1;
    final t = (now - startedAt) / duration;
    if (t < 0) return 0;
    if (t > 1) return 1;
    return t;
  }

  double eased(double now) {
    final t = progress(now);
    return 1 - (1 - t) * (1 - t);
  }
}

class TunnelRun {
  TunnelRun._(this.spec, this.stake, Pointer<Void> handle) : _handle = handle;

  final DiffSpec spec;
  final int stake;
  Pointer<Void>? _handle;

  int get lane {
    final handle = _handle;
    if (handle == null) return -1;
    return ttRoundLane(handle);
  }

  double get multiplier {
    final handle = _handle;
    if (handle == null) return 1;
    return ttRoundMultiplier(handle);
  }

  int get payout {
    final handle = _handle;
    if (handle == null) return 0;
    return ttRoundPayout(handle);
  }

  bool diesOnNext() {
    final handle = _handle;
    if (handle == null) return false;
    return ttRoundDiesNext(handle);
  }

  void land(int index) {
    final handle = _handle;
    if (handle == null) return;
    ttRoundSetLane(handle, index);
  }

  void release() {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;
    ttCloseRound(handle);
  }

  static TunnelRun deal(DiffSpec spec, int stake, {int? seed}) {
    final chosen = seed ?? DateTime.now().microsecondsSinceEpoch;
    return TunnelRun._(
      spec,
      stake,
      ttOpenRound(spec.diff.index, stake.toDouble(), chosen),
    );
  }
}
