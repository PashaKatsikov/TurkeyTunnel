import 'package:flutter/material.dart';

import '../vault/junction_env.dart';
import '../vault/stowed_bytes.dart';
import '../signal/pushwatch.dart';
import '../signal/stash.dart';
import 'offramp_buttons.dart';
import 'web_hall.dart';

// ============================================================
// OPT-IN GATE — push permission promo (Notifications screen)
// ============================================================
// Shown once before the WebView (first entry, or after the snooze
// window). Background is a flat fill (no artwork). Per the brief:
// NO SafeArea here — in landscape a safe-area inset shifts the
// horizontal centre and the buttons drift; content and buttons are
// centred manually instead.
// ============================================================

class OptinGate extends StatefulWidget {
  const OptinGate({
    super.key,
    required this.stash,
    required this.push,
    required this.targetUrl,
  });

  final Stash stash;
  final PushWatch push;
  final String targetUrl;

  @override
  State<OptinGate> createState() => _OptinGateState();
}

class _OptinGateState extends State<OptinGate> {
  Future<void> _accept() async {
    final bool granted = await widget.push.requestPermission();
    if (!granted) {
      await widget.stash.writeOptinSnoozeUntil(_snoozeUntil());
    }
    if (mounted) _forward();
  }

  Future<void> _skip() async {
    await widget.stash.writeOptinSnoozeUntil(_snoozeUntil());
    if (mounted) _forward();
  }

  int _snoozeUntil() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      JunctionEnv.optinSnoozeSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WebHall(
          url: widget.targetUrl,
          stash: widget.stash,
          push: widget.push,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double contentWidth =
        landscape ? size.width * 0.62 : size.width * 0.84;
    final double buttonWidth =
        landscape ? size.width * 0.4 : size.width * 0.72;

    // Copy comes from the native guard; fall back to plain strings only
    // if the vault is not wired (QA / template state).
    final String title = pullOptinTitle().isNotEmpty
        ? pullOptinTitle()
        : 'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS';
    final String body = pullOptinBody().isNotEmpty
        ? pullOptinBody()
        : 'Stay tuned for special offers and rewards';

    // No SafeArea — centre everything manually so landscape cutouts
    // never shift the horizontal centre.
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF241403),
              Color(0xFF3A2208),
              Color(0xFF120B04),
            ],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _FlameBadge(),
                SizedBox(height: landscape ? 14 : 26),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFF8EC),
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFCBB89B),
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: landscape ? 18 : 30),
                RampButton(
                  label: 'Accept',
                  width: buttonWidth,
                  onTap: _accept,
                ),
                const SizedBox(height: 12),
                RampGhostButton(
                  label: 'Skip',
                  width: buttonWidth,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlameBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF2BE35), Color(0xFFE2550F)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFE2550F).withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.local_fire_department,
        color: Colors.white,
        size: 46,
      ),
    );
  }
}
