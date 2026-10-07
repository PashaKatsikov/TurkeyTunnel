import 'package:flutter/material.dart';

import 'arcade_button.dart';
import 'legal_page.dart';
import 'links.dart';
import 'look.dart';
import 'settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final Settings settings;

  void _open(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Look.page,
      body: Column(
        children: [
          ColoredBox(
            color: Look.bar,
            child: Padding(
              padding: EdgeInsets.only(
                left: pad.left + 4,
                right: pad.right + 12,
                top: pad.top,
              ),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Look.cream),
                    ),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Look.cream,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  pad.left + 16,
                  12,
                  pad.right + 16,
                  12 + pad.bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Look.card,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Look.cardLine),
                        ),
                        child: ListenableBuilder(
                          listenable: settings,
                          builder: (context, _) {
                            return SwitchListTile(
                              value: settings.haptics,
                              onChanged: settings.setHaptics,
                              activeThumbColor: Look.green,
                              title: const Text(
                                'Haptic feedback',
                                style: TextStyle(
                                  color: Look.cream,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Vibrate on jumps, wins and crashes',
                                style: TextStyle(color: Look.dim, fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      ArcadeButton(
                        label: 'Privacy Policy',
                        color: Look.key,
                        height: 44,
                        onTap: () =>
                            _open(context, 'Privacy Policy', privacyPolicyUrl),
                      ),
                      const SizedBox(height: 8),
                      ArcadeButton(
                        label: 'Support',
                        color: Look.key,
                        height: 44,
                        onTap: () => _open(context, 'Support', supportUrl),
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
