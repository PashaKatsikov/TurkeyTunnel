import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'atlas.dart';
import 'clock.dart';
import 'deck.dart';
import 'format.dart';
import 'guide.dart';
import 'look.dart';
import 'road_geom.dart';
import 'run.dart';
import 'scene.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'top_bar.dart';
import 'traffic.dart';
import 'wallet.dart';
import 'world_painter.dart';

class PlayPage extends StatefulWidget {
  const PlayPage({
    super.key,
    required this.wallet,
    required this.settings,
    required this.atlas,
  });

  final Wallet wallet;
  final Settings settings;
  final Atlas atlas;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _clock = Clock();
  final _camera = Camera();
  final _barriers = <Barrier>[];
  late final Ticker _ticker;
  late Traffic _traffic;
  TunnelRun? _run;
  Hop? _hop;
  RoundPhase _phase = RoundPhase.betting;
  var _onCarpet = false;
  int? _deathLane;
  var _wreckedAt = 0.0;
  int? _win;
  Duration _last = Duration.zero;
  Timer? _resetTimer;
  Timer? _winTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _traffic = Traffic(widget.wallet.spec.lanes);
    widget.wallet.addListener(_onWallet);
    _ticker = createTicker(_frame)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _resetTimer?.cancel();
    _winTimer?.cancel();
    _run?.release();
    widget.wallet.removeListener(_onWallet);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _ticker.stop();
    } else if (state == AppLifecycleState.resumed && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onWallet() {
    final lanes = widget.wallet.spec.lanes;
    if (_phase == RoundPhase.betting && _traffic.laneCount != lanes) {
      _traffic = Traffic(lanes);
    }
    if (mounted) setState(() {});
  }

  Scene _scene() {
    return Scene(
      spec: widget.wallet.spec,
      phase: _phase,
      lane: _run?.lane ?? -1,
      hop: _hop,
      onCarpet: _onCarpet,
      deathLane: _deathLane,
      wreckedAt: _wreckedAt,
      cars: _traffic.cars,
      barriers: _barriers,
      camera: _camera,
    );
  }

  int _firstVisibleLane() {
    final lane = ((_camera.focus - bankLeftWidth) / laneWidth).floor() - 1;
    return lane < 0 ? 0 : lane;
  }

  void _frame(Duration elapsed) {
    if (!mounted) return;
    final raw = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1000000;
    _last = elapsed;
    final dt = raw < 0 ? 0.0 : (raw > 0.05 ? 0.05 : raw);
    _clock.now += dt;
    _traffic.tick(dt, firstLane: _firstVisibleLane());
    final target = _scene().birdX(_clock.now);
    _camera.focus += (target - _camera.focus) * (1 - exp(-dt * 7));
    if (_hop != null && _hop!.progress(_clock.now) >= 1) {
      _finishHop();
      if (mounted) setState(() {});
    }
    if (mounted) _clock.notify();
  }

  void _play() {
    final stake = widget.wallet.stake;
    if (!widget.wallet.spend(stake)) return;
    _resetTimer?.cancel();
    widget.settings.light();
    setState(() {
      _clearRound();
      _run = TunnelRun.deal(widget.wallet.spec, stake);
      _phase = RoundPhase.waiting;
    });
  }

  void _go() {
    final run = _run;
    if (run == null || _phase != RoundPhase.waiting) return;
    final to = run.lane + 1;
    if (to > run.spec.lanes) return;
    widget.settings.light();
    setState(() {
      _startHop(run.lane, to, victory: to >= run.spec.lanes);
    });
  }

  void _startHop(int from, int to, {required bool victory}) {
    final run = _run;
    if (run == null) return;
    final dies = !victory && run.diesOnNext();
    _hop = Hop(
      from: from,
      to: to,
      dies: dies,
      victory: victory,
      startedAt: _clock.now,
      duration: victory ? 0.5 : 0.36,
    );
    _phase = RoundPhase.hopping;
    if (dies) {
      _traffic.strike(to);
    } else if (!victory) {
      _barriers.add(Barrier(to, _clock.now + 0.06));
      _traffic.block(to);
    }
  }

  void _finishHop() {
    final hop = _hop;
    if (hop == null || _run == null) return;
    _hop = null;
    if (hop.dies) {
      _deathLane = hop.to;
      _wreckedAt = _clock.now;
      _phase = RoundPhase.wrecked;
      widget.settings.heavy();
      _armReset(1100);
      return;
    }
    if (hop.victory) {
      _onCarpet = true;
      _pay(hold: 1500);
      return;
    }
    _run!.land(hop.to);
    if (hop.to == _run!.spec.lanes - 1) {
      _startHop(hop.to, hop.to + 1, victory: true);
      return;
    }
    _phase = RoundPhase.waiting;
  }

  void _cash() {
    if (_phase != RoundPhase.waiting || (_run?.lane ?? -1) < 0) return;
    _pay(hold: 700);
  }

  void _pay({required int hold}) {
    final run = _run;
    if (run == null || run.lane < 0) return;
    final amount = run.payout;
    widget.wallet.credit(amount);
    _phase = RoundPhase.cashed;
    _hop = null;
    _win = amount;
    _winTimer?.cancel();
    _winTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _win = null);
    });
    widget.settings.medium();
    _armReset(hold);
  }

  void _cancel() {
    final run = _run;
    if (run == null || _phase != RoundPhase.waiting || run.lane >= 0) return;
    widget.wallet.credit(run.stake);
    setState(() {
      _clearRound();
      _phase = RoundPhase.betting;
    });
  }

  void _pocket() {
    widget.wallet.credit(Wallet.pocket);
    widget.settings.light();
  }

  void _armReset(int milliseconds) {
    _resetTimer?.cancel();
    _resetTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (!mounted) return;
      setState(() {
        _clearRound();
        _phase = RoundPhase.betting;
      });
    });
  }

  void _clearRound() {
    _run?.release();
    _run = null;
    _hop = null;
    _onCarpet = false;
    _deathLane = null;
    _barriers.clear();
    _traffic.release();
  }

  Future<void> _menu() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Look.panel,
          title: const Text(
            'Turkey Tunnel',
            style: TextStyle(color: Look.cream, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _menuRow(dialogContext, 'How to play', () => showGuide(context)),
              _menuRow(dialogContext, 'Settings', _openSettings),
              _menuRow(dialogContext, 'Main menu', _exit),
            ],
          ),
        );
      },
    );
  }

  Widget _menuRow(
    BuildContext dialogContext,
    String label,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(color: Look.cream, fontWeight: FontWeight.w700),
      ),
      onTap: () {
        Navigator.pop(dialogContext);
        onTap();
      },
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(settings: widget.settings),
      ),
    );
  }

  // Leaving mid-round never costs the player: a bet that has not started is
  // refunded and a running round is cashed out where the bird stands.
  void _exit() {
    if (_phase == RoundPhase.hopping) return;
    final run = _run;
    if (run != null && _phase == RoundPhase.waiting) {
      if (run.lane < 0) {
        widget.wallet.credit(run.stake);
      } else {
        widget.wallet.credit(run.payout);
      }
    }
    _resetTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1);
    final pad = MediaQuery.paddingOf(context);
    final win = _win;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler),
        child: Scaffold(
          backgroundColor: Look.page,
          body: Column(
            children: [
              TopBar(
                balance: widget.wallet.balance,
                inset: pad,
                onGuide: () => showGuide(context),
                onMenu: _menu,
              ),
              Expanded(
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RoadView(
                        clock: _clock,
                        atlas: widget.atlas,
                        scene: _scene(),
                        onTap: _phase == RoundPhase.waiting ? _go : null,
                      ),
                      if (win != null)
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(child: _winPill(win)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: pad.left,
                  right: pad.right,
                  bottom: pad.bottom,
                ),
                child: PlayDeck(
                  wallet: widget.wallet,
                  phase: _phase,
                  lane: _run?.lane ?? -1,
                  payout: _run?.payout ?? 0,
                  onStake: widget.wallet.setStake,
                  onDifficulty: widget.wallet.setDifficulty,
                  onPlay: _play,
                  onGo: _go,
                  onCash: _cash,
                  onCancel: _cancel,
                  onPocket: _pocket,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _winPill(int amount) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Look.win,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF58B07C)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'WIN',
              style: TextStyle(
                color: Color(0xFFBFE8CF),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                height: 1.1,
              ),
            ),
            Text(
              formatCoins(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
