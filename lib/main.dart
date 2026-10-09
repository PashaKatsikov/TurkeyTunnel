import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'boot_page.dart';
import 'look.dart';
import 'offramp/dispatcher.dart';
import 'offramp/signal/agent_mark.dart';
import 'offramp/signal/decision.dart';
import 'offramp/signal/install_feed.dart';
import 'offramp/signal/pushwatch.dart';
import 'offramp/signal/reach_scout.dart';
import 'offramp/signal/stash.dart';
import 'settings.dart';
import 'wallet.dart';

// ============================================================
// main.dart — bootstrap wiring
// ============================================================
// Boot order (do not reorder):
//   1. Binding — before any plugin call.
//   2. Firebase + AppCheck in try/catch — the app runs without
//      google-services.json; a failure here must never block start
//      (the dispatcher falls back to the native game).
//   3. Chrome + orientations — all four allowed on boot; the game
//      path re-locks landscape once it takes over.
//   4. AgentMark.prime — the forged UA used by the courier AND the
//      WebView. Must run before either exists.
//   5. Stash.warm — reads prefs into memory so the lane decision is
//      synchronous.
//   6. Assemble the off-ramp pipeline, mount the app.
// ============================================================

// Background message sink. Must be a top-level `vm:entry-point` function:
// the framework stores its *library* so it can relaunch it in a background
// isolate, and that library URI survives obfuscation. Keeping it here means
// the only entry-point URI that leaks is the neutral `main.dart`.
@pragma('vm:entry-point')
Future<void> _onPushMessage(RemoteMessage message) async {
  // The OS renders the notification; the tap is handled on resume/boot.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_onPushMessage);
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  await AgentMark.prime();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final Wallet wallet = Wallet(prefs);
  final Settings settings = Settings(prefs);

  final Stash stash = Stash();
  await stash.warm();

  final PushWatch push = PushWatch(stash);
  final Dispatcher dispatcher = Dispatcher(
    stash: stash,
    scout: ReachScout(),
    feed: InstallFeed(),
    decision: Decision(stash),
    push: push,
  );

  runApp(TurkeyTunnelApp(
    wallet: wallet,
    settings: settings,
    dispatcher: dispatcher,
    stash: stash,
    push: push,
  ));
}

class TurkeyTunnelApp extends StatefulWidget {
  const TurkeyTunnelApp({
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
  State<TurkeyTunnelApp> createState() => _TurkeyTunnelAppState();
}

class _TurkeyTunnelAppState extends State<TurkeyTunnelApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turkey Tunnel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Look.ink,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Look.gold,
          surface: Look.ink,
        ),
      ),
      home: BootPage(
        wallet: widget.wallet,
        settings: widget.settings,
        dispatcher: widget.dispatcher,
        stash: widget.stash,
        push: widget.push,
      ),
    );
  }
}
