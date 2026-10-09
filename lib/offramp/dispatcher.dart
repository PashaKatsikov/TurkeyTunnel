import 'dart:async';
import 'dart:io';

import 'vault/junction_env.dart';
import 'signal/coldlink.dart';
import 'signal/decision.dart';
import 'signal/install_feed.dart';
import 'signal/outcome.dart';
import 'signal/pushwatch.dart';
import 'signal/reach_scout.dart';
import 'signal/stash.dart';

// ============================================================
// DISPATCHER — the one place the boot decision is made
// ============================================================
// `resolve()` returns a single `Exit`. The loading surface switches
// over it and pushes one route; no routing logic lives anywhere else.
//
// It branches on the persisted `LaneMemory`:
//
//   undecided (first launch)
//     • no adapter / DNS fails → DeadAirExit(wasGame:false)
//     • granted               → save web  → WebExit(url)
//     • denied                → one retry 3 s later, then
//                               granted → web / denied → save game
//
//   webBound (was in the WebView)
//     • no adapter            → DeadAirExit(wasGame:false)
//     • cold-tap URL          → WebExit(url, coldTap:true)
//     • fresh cache           → WebExit(cachedUrl)
//     • granted               → WebExit(freshUrl)
//     • denied + cache        → WebExit(cachedUrl)  (last-known-good)
//     • otherwise             → DeadAirExit(wasGame:false)
//
//   gameBound (was in the game)
//     • no adapter            → GameExit            (never blocks)
//     • granted               → save web → WebExit(url)
//     • denied                → one retry 3 s later, then GameExit
//
// Concurrent boots are de-duplicated via the in-flight future, which
// clears on completion so a retry re-runs the pipeline in full.
// ============================================================

class Dispatcher {
  Dispatcher({
    required this.stash,
    required this.scout,
    required this.feed,
    required this.decision,
    required this.push,
  });

  final Stash stash;
  final ReachScout scout;
  final InstallFeed feed;
  final Decision decision;
  final PushWatch push;

  Duration get _nativeRetryGap =>
      Duration(seconds: JunctionEnv.nativeRetryGapSeconds);

  Future<Exit>? _pending;

  Future<Exit> resolve({void Function(double)? onProgress}) {
    return _pending ??= _run(onProgress ?? (_) {})
        .whenComplete(() => _pending = null);
  }

  Future<Exit> _run(void Function(double) tick) async {
    if (!JunctionEnv.gateArmed) {
      tick(1);
      return const GameExit();
    }

    push.onToken = _reaskOnToken;

    // Warm Firebase Messaging FIRST — a cold-tap URL is only
    // deposited into the stash after getInitialMessage resolves.
    // Swallow failures: if Firebase is unconfigured the gate wouldn't
    // be armed anyway, and if it just can't reach the network we
    // continue down the lane paths that handle offline themselves.
    await _tryWarm();

    // A cold-boot push tap always wins.
    final String? coldUrl = await ColdLink.take(stash);
    if (coldUrl != null && coldUrl.isNotEmpty) {
      await stash.saveLane(LaneMemory.webBound);
      unawaited(_warmInBackground());
      tick(1);
      return WebExit(coldUrl, coldTap: true);
    }

    tick(0.18);
    return switch (stash.lane) {
      LaneMemory.undecided => _firstLaunch(tick),
      LaneMemory.webBound => _returningWeb(tick),
      LaneMemory.gameBound => _returningGame(tick),
    };
  }

  Future<Exit> _firstLaunch(void Function(double) tick) async {
    if (!await scout.hasLink()) return const DeadAirExit(wasGame: false);
    tick(0.32);
    await _tryWarm();
    if (!await scout.canResolve()) {
      return const DeadAirExit(wasGame: false);
    }
    tick(0.52);
    await feed.start();
    await feed.awaitSignals(installSeconds: JunctionEnv.firstInstallWaitSeconds);
    tick(0.78);
    Ruling ruling = await _poll();
    // Organic installs settle on the first config answer: a second poll
    // would never change an organic verdict and only delays the game.
    if (!ruling.hasTarget && !feed.wasOrganic) {
      tick(0.9);
      ruling = await _pollAgainAfterGap();
    }
    tick(1);
    if (ruling.hasTarget) {
      await stash.saveLane(LaneMemory.webBound);
      return WebExit(ruling.url!);
    }
    await stash.saveLane(LaneMemory.gameBound);
    return const GameExit();
  }

  Future<Exit> _returningWeb(void Function(double) tick) async {
    if (!await scout.hasLink()) return const DeadAirExit(wasGame: false);

    final String? cached = await stash.cachedTarget();
    if (cached != null && !stash.cachedTargetStale) {
      tick(1);
      return WebExit(cached);
    }

    await Future.wait<void>(<Future<void>>[push.warm(), feed.start()]);
    if (!await scout.canResolve()) {
      if (cached != null) return WebExit(cached);
      return const DeadAirExit(wasGame: false);
    }
    tick(0.62);
    await feed.awaitSignals(
      installSeconds: JunctionEnv.returningInstallWaitSeconds,
    );
    final Ruling ruling = await _poll();
    tick(1);
    if (ruling.hasTarget) return WebExit(ruling.url!);
    if (cached != null) return WebExit(cached);
    return const DeadAirExit(wasGame: false);
  }

  Future<Exit> _returningGame(void Function(double) tick) async {
    if (!await scout.hasLink()) {
      tick(1);
      return const GameExit();
    }
    await Future.wait<void>(<Future<void>>[push.warm(), feed.start()]);
    if (!await scout.canResolve()) {
      tick(1);
      return const GameExit();
    }
    tick(0.58);
    await feed.awaitSignals(
      installSeconds: JunctionEnv.returningInstallWaitSeconds,
    );
    Ruling ruling = await _poll();
    if (!ruling.hasTarget && !feed.wasOrganic) {
      tick(0.82);
      ruling = await _pollAgainAfterGap();
    }
    tick(1);
    if (!ruling.hasTarget) return const GameExit();
    await stash.saveLane(LaneMemory.webBound);
    return WebExit(ruling.url!);
  }

  /// A native verdict gets exactly one more chance: late attribution
  /// often lands a moment after the first POST.
  Future<Ruling> _pollAgainAfterGap() async {
    await Future<void>.delayed(_nativeRetryGap);
    return _poll();
  }

  Future<Ruling> _poll({String? token}) async {
    final Map<String, dynamic> body = await feed.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? push.token,
    );
    return decision.ask(body);
  }

  Future<void> _tryWarm() async {
    try {
      await push.warm();
    } catch (_) {}
  }

  Future<void> _warmInBackground() async {
    try {
      await Future.wait<void>(<Future<void>>[push.warm(), feed.start()]);
      await feed.awaitSignals(
        installSeconds: JunctionEnv.returningInstallWaitSeconds,
      );
      await _poll();
    } catch (_) {}
  }

  Future<void> _reaskOnToken(String token) async {
    try {
      await _poll(token: token);
    } catch (_) {}
  }
}
