import 'package:flutter_test/flutter_test.dart';
import 'package:turkey_tunnel/core/turkey_core.dart';
import 'package:turkey_tunnel/format.dart';
import 'package:turkey_tunnel/odds.dart';
import 'package:turkey_tunnel/road_geom.dart';
import 'package:turkey_tunnel/run.dart';

void main() {
  test('ladders climb and start above even money', () {
    for (final spec in DiffSpec.all) {
      expect(spec.stepAt(0), greaterThan(1));
      for (var i = 1; i < spec.lanes; i++) {
        expect(spec.stepAt(i), greaterThan(spec.stepAt(i - 1)));
      }
    }
  });

  test('a flat first step still pays a coin', () {
    final spec = DiffSpec.of(Diff.easy);
    expect(ttPayout(10, spec.stepAt(0), 0), 11);
    final run = TunnelRun.deal(spec, 10, seed: 1);
    expect(run.payout, 10);
    run.land(0);
    expect(run.payout, 11);
    run.release();
  });

  test('deal builds one trap roll per lane', () {
    final spec = DiffSpec.of(Diff.hardcore);
    final run = TunnelRun.deal(spec, 20, seed: 4);
    final again = TunnelRun.deal(spec, 20, seed: 4);
    expect(spec.lanes, 10);
    expect(run.lane, -1);
    expect(again.diesOnNext(), run.diesOnNext());
    run.release();
    again.release();
  });

  test('the carpet sits past the last manhole', () {
    expect(anchorX(-1, 8), sidewalkX);
    expect(anchorX(8, 8), greaterThan(laneCenter(7)));
    expect(worldWidth(12), greaterThan(worldWidth(4)));
  });

  test('the camera never scrolls into empty space', () {
    expect(cameraFor(viewWidth: 800, scale: 0.2, focus: 40, lanes: 4), 0);
    final far = cameraFor(viewWidth: 400, scale: 0.25, focus: 9000, lanes: 12);
    final limit = worldWidth(12) - 400 / 0.25;
    expect(far, inInclusiveRange(0, limit));
  });

  test('coins and multipliers read the way the board does', () {
    expect(formatCoins(1000), '1,000');
    expect(formatCoins(-20), '-20');
    expect(formatMult(1.1), '1.10x');
    expect(formatMult(15.3), '15.30x');
    expect(formatMult(185.08), '185x');
    expect(formatMult(2400.0), '2.4kx');
  });
}
