import 'package:flutter/material.dart';

import 'look.dart';
import 'wallet.dart';

Future<void> showGuide(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Look.panel,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        title: const Text(
          'How to play',
          style: TextStyle(color: Look.gold, fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Text(
            _guide(),
            style: const TextStyle(
              color: Look.cream,
              height: 1.25,
              fontSize: 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'GOT IT',
              style: TextStyle(color: Look.gold, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
    },
  );
}

String _guide() {
  return 'Pick a bet and a difficulty, then press Play. Each press of Go sends '
      'the bird to the next lane. A manhole shows what your bet pays if you '
      'cash out there.\n\n'
      'If a barrier drops in front of you the lane is safe and its manhole '
      'turns gold. If a car comes down the lane instead, the run is over.\n\n'
      'Easy pays slowly and is rarely hit. Hardcore pays fast and is hit '
      'often. The percentage is the chance of being hit on each lane.\n\n'
      'Cancel before the first lane and the bet comes back. After that, cash '
      'out whenever you like. Clear every lane and the bird walks the red '
      'carpet for the top prize.\n\n'
      'Run out of coins and you can pick up ${Wallet.pocket} more.';
}
