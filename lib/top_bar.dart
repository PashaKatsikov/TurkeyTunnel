import 'package:flutter/material.dart';

import 'art.dart';
import 'coin_badge.dart';
import 'format.dart';
import 'look.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.balance,
    required this.onGuide,
    required this.onMenu,
    this.inset = EdgeInsets.zero,
  });

  static const height = 40.0;

  final int balance;
  final VoidCallback onGuide;
  final VoidCallback onMenu;
  final EdgeInsets inset;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Look.bar,
      child: Padding(
        padding: EdgeInsets.only(
          left: inset.left + 12,
          right: inset.right + 8,
          top: inset.top,
        ),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              Image.asset(
                Art.logo,
                height: 22,
                filterQuality: FilterQuality.medium,
              ),
              const Spacer(),
              _pill(
                onTap: onGuide,
                color: Look.key,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Look.cream),
                    SizedBox(width: 5),
                    Text('How to play?', style: _pillText),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _pill(
                color: Look.field,
                minWidth: 96,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(formatCoins(balance), style: _pillText),
                    const SizedBox(width: 6),
                    const CoinBadge(),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onMenu,
                tooltip: 'Menu',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.menu, color: Look.cream, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required Widget child,
    required Color color,
    VoidCallback? onTap,
    double minWidth = 0,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

const _pillText = TextStyle(
  color: Look.cream,
  fontSize: 12,
  fontWeight: FontWeight.w700,
);
