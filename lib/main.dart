import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'atlas.dart';
import 'boot_page.dart';
import 'look.dart';
import 'menu_page.dart';
import 'settings.dart';
import 'wallet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  final prefs = await SharedPreferences.getInstance();
  runApp(TurkeyTunnelApp(wallet: Wallet(prefs), settings: Settings(prefs)));
}

class TurkeyTunnelApp extends StatefulWidget {
  const TurkeyTunnelApp({
    super.key,
    required this.wallet,
    required this.settings,
  });

  final Wallet wallet;
  final Settings settings;

  @override
  State<TurkeyTunnelApp> createState() => _TurkeyTunnelAppState();
}

class _TurkeyTunnelAppState extends State<TurkeyTunnelApp>
    with WidgetsBindingObserver {
  Atlas? _atlas;

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

  Future<void> _booted(Atlas atlas) async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    setState(() => _atlas = atlas);
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas;
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
      home: atlas == null
          ? BootPage(onReady: _booted)
          : MenuPage(
              wallet: widget.wallet,
              settings: widget.settings,
              atlas: atlas,
            ),
    );
  }
}
