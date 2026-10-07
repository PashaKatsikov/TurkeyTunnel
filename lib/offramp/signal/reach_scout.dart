import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../vault/junction_env.dart';

// ============================================================
// REACH SCOUT — adapter check + DNS reachability
// ============================================================
// `connectivity_plus` lies through captive portals and half-up VPN
// interfaces, so a live adapter is confirmed with a real DNS lookup
// before the pipeline ever commits to the online path. VPN/Bluetooth/
// Ethernet all count as live — dropping them produced false offline
// verdicts on real users.
//
// Probe hosts are cheap-DNS and unrelated to the partner/endpoint, so
// no probe→own-host correlation shows up in a traffic sniff.
// ============================================================

class ReachScout {
  ReachScout({Connectivity? connectivity})
      : _conn = connectivity ?? Connectivity();

  static const List<String> _hosts = <String>[
    'microsoft.com',
    'wikipedia.org',
  ];

  static const Set<ConnectivityResult> _live = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  final Connectivity _conn;
  int _turn = 0;

  /// At least one adapter reports live. No DNS lookup here.
  Future<bool> hasLink() async {
    try {
      final List<ConnectivityResult> now = await _conn.checkConnectivity();
      return now.any(_live.contains);
    } catch (_) {
      return false;
    }
  }

  /// Can resolve at least one probe host inside the timeout. Rotates
  /// the host so a single flaky resolver does not force offline.
  Future<bool> canResolve() async {
    if (!await hasLink()) return false;
    final Duration limit = Duration(seconds: JunctionEnv.reachTimeoutSeconds);
    for (int i = 0; i < _hosts.length; i++) {
      final String host = _hosts[(_turn + i) % _hosts.length];
      try {
        final List<InternetAddress> hit =
            await InternetAddress.lookup(host).timeout(limit);
        if (hit.any((InternetAddress a) => a.rawAddress.isNotEmpty)) {
          _turn = (_turn + 1) % _hosts.length;
          return true;
        }
      } catch (_) {
        // next host
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes => _conn.onConnectivityChanged;
}
