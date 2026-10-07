import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turkey_tunnel/offramp/cloak/inset_ledger.dart';

// Exercises the native `drift` geometry ledger end-to-end through the
// FFI bindings. The host library is built by hook/build.dart; the
// cutout is learned once per orientation.
void main() {
  test('ledger learns the cutout once per orientation', () {
    expect(InsetLedger.hasCutout(Orientation.portrait), isFalse);

    InsetLedger.learnCutout(
      Orientation.portrait,
      const EdgeInsets.only(top: 44, left: 0, right: 0),
    );
    expect(InsetLedger.hasCutout(Orientation.portrait), isTrue);
    expect(InsetLedger.cutout(Orientation.portrait).top, 44);

    // A second learn is ignored natively.
    InsetLedger.learnCutout(
      Orientation.portrait,
      const EdgeInsets.only(top: 99, left: 9, right: 9),
    );
    expect(InsetLedger.cutout(Orientation.portrait).top, 44);
    expect(InsetLedger.cutout(Orientation.portrait).left, 0);
  });
}
