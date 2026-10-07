import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turkey_tunnel/deck.dart';
import 'package:turkey_tunnel/odds.dart';
import 'package:turkey_tunnel/run.dart';
import 'package:turkey_tunnel/wallet.dart';

void main() {
  for (final width in [520.0, 600.0, 700.0, 780.0, 851.0, 960.0]) {
    for (final phase in [RoundPhase.betting, RoundPhase.waiting]) {
      for (final diff in Diff.values) {
        testWidgets('deck fits at $width ${phase.name} ${diff.name}', (
          tester,
        ) async {
          SharedPreferences.setMockInitialValues({'difficulty': diff.index});
          final wallet = Wallet(await SharedPreferences.getInstance());
          tester.view.physicalSize = Size(width, 392);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: PlayDeck(
                    wallet: wallet,
                    phase: phase,
                    lane: 0,
                    payout: 1234567,
                    onStake: (_) {},
                    onDifficulty: (_) {},
                    onPlay: () {},
                    onGo: () {},
                    onCash: () {},
                    onCancel: () {},
                    onPocket: () {},
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
