import 'package:flutter/material.dart';

import 'look.dart';

/// The small round "$" next to every amount.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Look.cream,
        shape: BoxShape.circle,
      ),
      child: Text(
        r'$',
        style: TextStyle(
          color: Look.field,
          fontSize: size * 0.68,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
