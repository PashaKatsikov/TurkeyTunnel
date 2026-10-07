import 'package:flutter/material.dart';

import 'arcade_button.dart';
import 'coin_badge.dart';
import 'format.dart';
import 'look.dart';
import 'odds.dart';
import 'run.dart';
import 'wallet.dart';

class PlayDeck extends StatelessWidget {
  const PlayDeck({
    super.key,
    required this.wallet,
    required this.phase,
    required this.lane,
    required this.payout,
    required this.onStake,
    required this.onDifficulty,
    required this.onPlay,
    required this.onGo,
    required this.onCash,
    required this.onCancel,
    required this.onPocket,
  });

  static const rowHeight = 34.0;
  static const bodyHeight = rowHeight * 2 + 6;

  final Wallet wallet;
  final RoundPhase phase;
  final int lane;
  final int payout;
  final ValueChanged<int> onStake;
  final ValueChanged<Diff> onDifficulty;
  final VoidCallback onPlay;
  final VoidCallback onGo;
  final VoidCallback onCash;
  final VoidCallback onCancel;
  final VoidCallback onPocket;

  @override
  Widget build(BuildContext context) {
    final locked = phase != RoundPhase.betting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Look.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Look.cardLine),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            height: bodyHeight,
            child: Row(
              children: [
                Expanded(flex: 36, child: _lockable(locked, _bet())),
                const SizedBox(width: 14),
                Expanded(flex: 40, child: _lockable(locked, _difficulty())),
                const SizedBox(width: 14),
                Expanded(flex: 30, child: _actions()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockable(bool locked, Widget child) {
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: IgnorePointer(ignoring: locked, child: child),
    );
  }

  Widget _bet() {
    final stake = wallet.stake;
    return Column(
      children: [
        SizedBox(
          height: rowHeight,
          child: Row(
            children: [
              _key('MIN', () => onStake(Wallet.minStake)),
              const SizedBox(width: 4),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Look.field,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _step(Icons.remove, () => onStake(wallet.shifted(-1))),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatCoins(stake),
                              style: const TextStyle(
                                color: Look.cream,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _step(Icons.add, () => onStake(wallet.shifted(1))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _key('MAX', () => onStake(wallet.balance)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: rowHeight,
          child: Row(
            children: [
              for (var i = 0; i < _chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(child: _chip(_chips[i], stake)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static const _chips = <int>[2, 3, 8, 20];

  Widget _key(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Look.key,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Look.cream,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _step(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 30,
        height: double.infinity,
        child: Icon(icon, size: 16, color: Look.dim),
      ),
    );
  }

  Widget _chip(int value, int stake) {
    final picked = stake == value;
    return GestureDetector(
      onTap: wallet.balance >= value ? () => onStake(value) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Look.field,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: picked ? Look.gold : Colors.transparent),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Look.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const CoinBadge(size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _difficulty() {
    final spec = wallet.spec;
    final color = switch (spec.diff) {
      Diff.easy => const Color(0xFF7DDE8A),
      Diff.medium => Look.gold,
      Diff.hard => const Color(0xFFFF8A3D),
      Diff.hardcore => Look.danger,
    };
    return Column(
      children: [
        SizedBox(
          height: rowHeight - 14,
          child: Row(
            children: [
              const Text(
                'Difficulty',
                style: TextStyle(
                  color: Look.cream,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Chance of being hit ',
                            style: TextStyle(color: Look.dim, fontSize: 11),
                          ),
                          TextSpan(
                            text: '${(spec.hitChance * 100).round()}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Look.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  for (final item in DiffSpec.all) Expanded(child: _tab(item)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tab(DiffSpec item) {
    final picked = wallet.difficulty == item.diff;
    return GestureDetector(
      onTap: () => onDifficulty(item.diff),
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: picked ? Look.key : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            item.label,
            style: TextStyle(
              color: picked ? Look.cream : Look.dim,
              fontSize: 13,
              fontWeight: picked ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    final betting = phase == RoundPhase.betting;
    if (betting || phase == RoundPhase.wrecked || phase == RoundPhase.cashed) {
      if (betting && wallet.broke) {
        return ArcadeButton(
          label: 'GET ${Wallet.pocket}',
          color: Look.gold,
          foreground: Look.goldInk,
          height: bodyHeight,
          onTap: onPocket,
        );
      }
      final canPlay = betting && wallet.balance >= wallet.stake;
      return ArcadeButton(
        label: 'Play',
        color: Look.green,
        height: bodyHeight,
        onTap: canPlay ? onPlay : null,
      );
    }

    final canAct = phase == RoundPhase.waiting;
    return Row(
      children: [
        Expanded(
          child: lane < 0
              ? ArcadeButton(
                  label: 'CANCEL',
                  color: Look.key,
                  height: bodyHeight,
                  onTap: canAct ? onCancel : null,
                )
              : ArcadeButton(
                  label: 'CASH OUT',
                  detail: formatCoins(payout),
                  color: Look.gold,
                  foreground: Look.goldInk,
                  height: bodyHeight,
                  onTap: canAct ? onCash : null,
                ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ArcadeButton(
            label: 'GO',
            color: Look.green,
            height: bodyHeight,
            onTap: canAct ? onGo : null,
          ),
        ),
      ],
    );
  }
}
