// Bindings for native/drift, the gray-part geometry ledger bundled by
// hook/build.dart. It caches, per orientation, the camera-cutout inset
// in native memory, so a rotation can apply its final geometry in one
// frame instead of chasing the system animation.
//
// The state lives in the `.so`, so it survives WebHall re-creation
// (e.g. an offline retry): the geometry stays warm across rebuilds.
@DefaultAsset('package:turkey_tunnel/drift')
library;

import 'dart:ffi';

import 'package:flutter/widgets.dart';

@Native<Void Function(Uint32, Double, Double, Double)>(
    symbol: 'df_learn', isLeaf: true)
external void _dfLearn(int orient, double top, double left, double right);

@Native<Int32 Function(Uint32)>(symbol: 'df_known', isLeaf: true)
external int _dfKnown(int orient);

@Native<Double Function(Uint32, Uint32)>(symbol: 'df_cut', isLeaf: true)
external double _dfCut(int orient, int field);

/// Per-orientation cutout cache backed by native/drift.
abstract final class InsetLedger {
  static int _o(Orientation o) => o == Orientation.landscape ? 1 : 0;

  /// Records the cutout for [o] the first time; later calls are ignored
  /// natively, so a transient nav bar can never churn it.
  static void learnCutout(Orientation o, EdgeInsets cutout) =>
      _dfLearn(_o(o), cutout.top, cutout.left, cutout.right);

  /// Whether the cutout for [o] has been learned.
  static bool hasCutout(Orientation o) => _dfKnown(_o(o)) != 0;

  /// The cached top/left/right cutout for [o] (bottom is always 0 — the
  /// hidden navigation bar never contributes a safe area).
  static EdgeInsets cutout(Orientation o) {
    final int i = _o(o);
    return EdgeInsets.only(
      top: _dfCut(i, 0),
      left: _dfCut(i, 1),
      right: _dfCut(i, 2),
    );
  }
}
