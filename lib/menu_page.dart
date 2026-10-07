import 'package:flutter/material.dart';

import 'arcade_button.dart';
import 'art.dart';
import 'atlas.dart';
import 'guide.dart';
import 'look.dart';
import 'play_page.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'wallet.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.wallet,
    required this.settings,
    required this.atlas,
  });

  final Wallet wallet;
  final Settings settings;
  final Atlas atlas;

  void _play(BuildContext context) {
    settings.light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlayPage(wallet: wallet, settings: settings, atlas: atlas),
      ),
    );
  }

  void _settings(BuildContext context) {
    settings.light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SettingsPage(settings: settings)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A140C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            Art.loadLand,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB3000000),
                ],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                12 + pad.top,
                pad.right + 28,
                12 + pad.bottom,
              ),
              child: SizedBox(
                width: 210,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArcadeButton(
                      label: 'Play',
                      color: Look.green,
                      height: 56,
                      onTap: () => _play(context),
                    ),
                    const SizedBox(height: 10),
                    ArcadeButton(
                      label: 'How to play',
                      color: Look.key,
                      height: 44,
                      onTap: () {
                        settings.light();
                        showGuide(context);
                      },
                    ),
                    const SizedBox(height: 10),
                    ArcadeButton(
                      label: 'Settings',
                      color: Look.key,
                      height: 44,
                      onTap: () => _settings(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
