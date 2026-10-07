import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'arcade_button.dart';
import 'art.dart';
import 'atlas.dart';
import 'look.dart';
import 'menu_page.dart';
import 'offramp/dispatcher.dart';
import 'offramp/signal/outcome.dart';
import 'offramp/signal/pushwatch.dart';
import 'offramp/signal/reach_scout.dart';
import 'offramp/signal/stash.dart';
import 'offramp/view/no_signal.dart';
import 'offramp/view/optin_gate.dart';
import 'offramp/view/web_hall.dart';
import 'settings.dart';
import 'wallet.dart';

// ============================================================
// BOOT PAGE — loading surface + route decision
// ============================================================
// Shows the loading art + a progress bar while the off-ramp
// Dispatcher resolves (in parallel with the game-atlas load), then
// pushes exactly one route:
//   GameExit    → MenuPage (native game, landscape locked)
//   WebExit     → OptinGate (push promo) or WebHall (WebView)
//   DeadAirExit → NoSignalScreen
//
// Progress bar contract (see the loading-bar notes below):
//   • eases smoothly toward the latest dispatcher stage, always
//     creeping so it never stalls on a fixed percentage;
//   • is capped below 100 % until the destination is actually ready
//     (for the game, that means the atlas has decoded);
//   • only then fills to 100 %, held for ~0.5 s before the route is
//     pushed, so the user always sees a full bar before launch.
//
// Fast-offline shortcut: when the lane is already `webBound` and the
// device is offline, the No-Signal screen is shown immediately —
// no loading art, no progress bar — because there is nothing to load.
// ============================================================

class BootPage extends StatefulWidget {
  const BootPage({
    super.key,
    required this.wallet,
    required this.settings,
    required this.dispatcher,
    required this.stash,
    required this.push,
  });

  final Wallet wallet;
  final Settings settings;
  final Dispatcher dispatcher;
  final Stash stash;
  final PushWatch push;

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _shown = ValueNotifier<double>(0);
  final ValueNotifier<int> _dots = ValueNotifier<int>(0);

  Atlas? _atlas;
  Exit? _exit;
  bool _atlasFailed = false;
  bool _left = false;
  int _ticket = 0;

  // Latest stage fraction reported by the dispatcher. The bar eases
  // toward this but is clamped below the finish line until the route
  // is actually ready.
  double _target = 0.06;
  // The route is resolved and its assets (if any) are ready: let the
  // bar run all the way to 100 %.
  bool _finishing = false;
  bool _holdScheduled = false;
  // Showing the bare No-Signal path for an offline web lane — no
  // loading art while the quick reachability probe runs.
  bool _bareOffline = false;

  // Below this the bar never climbs until [_finishing] flips.
  static const double _ceiling = 0.92;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
    _begin();
  }

  Future<void> _begin() async {
    final int ticket = ++_ticket;

    // An already-decided web lane with no connectivity goes straight
    // to the No-Signal screen: no loading surface, no bar.
    if (widget.stash.lane == LaneMemory.webBound) {
      setState(() => _bareOffline = true);
      final bool online = await ReachScout().hasLink();
      if (!mounted || ticket != _ticket) return;
      if (!online) {
        _toDeadAir();
        return;
      }
      setState(() => _bareOffline = false);
    }

    _loadAtlas();
    _decide();
  }

  Future<void> _decide() async {
    final int ticket = _ticket;
    final Exit exit = await widget.dispatcher.resolve(onProgress: _onProgress);
    if (!mounted || ticket != _ticket) return;
    _exit = exit;
    _settleOrFinish();
  }

  Future<void> _loadAtlas() async {
    final int ticket = _ticket;
    try {
      final Atlas atlas = await Atlas.load();
      if (!mounted || ticket != _ticket) return;
      _atlas = atlas;
      _settleOrFinish();
    } catch (_) {
      if (!mounted || ticket != _ticket) return;
      setState(() => _atlasFailed = true);
    }
  }

  void _onProgress(double value) {
    if (value > _target) _target = value;
  }

  // Drives the displayed bar value every frame: an eased approach to
  // the goal plus a constant creep so it is never frozen in place.
  void _onFrame(Duration elapsed) {
    if (_left) return;
    // Animated "LOADING" dots: cycle 0..3 a few times a second.
    final int phase = (elapsed.inMilliseconds ~/ 350) % 4;
    if (phase != _dots.value) _dots.value = phase;

    final double goal = _finishing ? 1.0 : (_target > _ceiling ? _ceiling : _target);
    final double v = _shown.value;
    if (v < goal) {
      double next = v + (goal - v) * 0.07 + 0.0035;
      if (next > goal) next = goal;
      _shown.value = next;
    }
    if (_finishing && _shown.value >= 0.999 && !_holdScheduled) {
      _holdScheduled = true;
      // Let the full bar breathe for half a second before leaving.
      Future<void>.delayed(const Duration(milliseconds: 520), _navigate);
    }
  }

  // Decide whether we can begin the final fill. The game path waits
  // for its atlas; web and offline do not.
  void _settleOrFinish() {
    if (_left || _finishing) return;
    final Exit? exit = _exit;
    if (exit == null) return;

    switch (exit) {
      case GameExit():
        if (_atlasFailed || _atlas == null) return;
        _finishing = true;
      case WebExit():
        _finishing = true;
      case DeadAirExit():
        // No 100 % fill for a dead end — show No-Signal right away.
        _left = true;
        _toDeadAir();
    }
  }

  void _navigate() {
    if (_left) return;
    final Exit? exit = _exit;
    if (exit == null) return;
    _left = true;
    switch (exit) {
      case GameExit():
        _toGame(_atlas!);
      case WebExit(url: final String url):
        _toWeb(url);
      case DeadAirExit():
        _toDeadAir();
    }
  }

  Future<void> _toGame(Atlas atlas) async {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MenuPage(
          wallet: widget.wallet,
          settings: widget.settings,
          atlas: atlas,
        ),
      ),
    );
  }

  void _toWeb(String url) {
    final Widget next = widget.stash.shouldOfferOptin
        ? OptinGate(stash: widget.stash, push: widget.push, targetUrl: url)
        : WebHall(url: url, stash: widget.stash, push: widget.push);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => next),
    );
  }

  void _toDeadAir() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalScreen(
          onRetry: (_) => BootPage(
            wallet: widget.wallet,
            settings: widget.settings,
            dispatcher: widget.dispatcher,
            stash: widget.stash,
            push: widget.push,
          ),
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _atlasFailed = false;
      _finishing = false;
      _holdScheduled = false;
      _left = false;
      _bareOffline = false;
      _exit = null;
      _atlas = null;
      _target = 0.06;
      _shown.value = 0;
    });
    _begin();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shown.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bare offline probe for the web lane: plain dark fill, no art,
    // no bar — we are about to show No-Signal.
    if (_bareOffline) {
      return const Scaffold(backgroundColor: Color(0xFF1A140C));
    }

    final bool land =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      backgroundColor: const Color(0xFF1A140C),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            land ? Art.loadLand : Art.loadPort,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
          if (_atlasFailed)
            Center(
              child: SizedBox(
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      "Couldn't load the game.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ArcadeButton(
                      label: 'RETRY',
                      color: Look.gold,
                      foreground: Look.goldInk,
                      onTap: _retry,
                    ),
                  ],
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: SizedBox(
                    width: land ? 280 : 220,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ValueListenableBuilder<int>(
                          valueListenable: _dots,
                          builder: (BuildContext context, int n, _) {
                            return Text(
                              'LOADING${'.' * n}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 2,
                                shadows: <Shadow>[
                                  Shadow(color: Colors.black54, blurRadius: 8),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ValueListenableBuilder<double>(
                            valueListenable: _shown,
                            builder: (BuildContext context, double value, _) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 8,
                                color: Look.gold,
                                backgroundColor: const Color(0x66000000),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
