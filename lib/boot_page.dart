import 'package:flutter/material.dart';

import 'arcade_button.dart';
import 'art.dart';
import 'atlas.dart';
import 'look.dart';

class BootPage extends StatefulWidget {
  const BootPage({super.key, required this.onReady});

  final ValueChanged<Atlas> onReady;

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bar;
  Atlas? _atlas;
  var _ready = false;
  var _failed = false;
  var _left = false;
  var _ticket = 0;

  @override
  void initState() {
    super.initState();
    _bar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _bar.addStatusListener((status) {
      if (status == AnimationStatus.completed) _leave();
    });
    _bar.forward();
    _load();
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    try {
      final atlas = await Atlas.load();
      if (!mounted || ticket != _ticket) return;
      _atlas = atlas;
      _ready = true;
      _leave();
    } catch (_) {
      if (!mounted || ticket != _ticket) return;
      setState(() => _failed = true);
    }
  }

  void _leave() {
    if (!mounted || _left || !_ready || _failed) return;
    if (_bar.status != AnimationStatus.completed) return;
    final atlas = _atlas;
    if (atlas == null) return;
    _left = true;
    widget.onReady(atlas);
  }

  void _retry() {
    setState(() => _failed = false);
    _bar.forward(from: 0);
    _load();
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final land = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      backgroundColor: const Color(0xFF1A140C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            land ? Art.loadLand : Art.loadPort,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
          if (_failed)
            Center(
              child: SizedBox(
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    child: AnimatedBuilder(
                      animation: _bar,
                      builder: (context, _) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'LOADING',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 8),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _bar.value,
                                minHeight: 8,
                                color: Look.gold,
                                backgroundColor: const Color(0x66000000),
                              ),
                            ),
                          ],
                        );
                      },
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
