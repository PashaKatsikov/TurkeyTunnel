import 'package:flutter/material.dart';

import 'offramp_buttons.dart';

// ============================================================
// NO SIGNAL — no-connection screen (Nowifi screen)
// ============================================================
// Shown whenever the pipeline concludes "no network". Retry rebuilds
// the caller-supplied route via pushReplacement; the dispatcher is
// idempotent so a retry runs the whole boot flow fresh.
//
// Background is a flat fill (no artwork). Per the brief: NO SafeArea
// — content and the Retry button are centred manually so a landscape
// cutout never shifts the horizontal centre.
// ============================================================

class NoSignalScreen extends StatefulWidget {
  const NoSignalScreen({super.key, required this.onRetry});

  final WidgetBuilder onRetry;

  @override
  State<NoSignalScreen> createState() => _NoSignalScreenState();
}

class _NoSignalScreenState extends State<NoSignalScreen> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double contentWidth =
        landscape ? size.width * 0.6 : size.width * 0.84;
    final double buttonWidth =
        landscape ? size.width * 0.34 : size.width * 0.66;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF0E1620),
              Color(0xFF1B2735),
              Color(0xFF070B10),
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
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x22FFFFFF),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFBFD0E2),
                    size: 44,
                  ),
                ),
                SizedBox(height: landscape ? 14 : 26),
                const Text(
                  'NO INTERNET CONNECTION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF2F6FB),
                    fontSize: 21,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Check your connection and try again',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9FB1C4),
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: landscape ? 18 : 30),
                _busy
                    ? const SizedBox(
                        height: 34,
                        width: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFFF2BE35)),
                        ),
                      )
                    : RampButton(
                        label: 'Retry',
                        width: buttonWidth,
                        onTap: _retry,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
