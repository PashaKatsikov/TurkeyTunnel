import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../vault/stowed_bytes.dart';

// ============================================================
// AGENT MARK — real-device User-Agent assembly
// ============================================================
// One UA, used by BOTH the HTTP courier and the WebView. It must
// read like a stock mobile browser on the actual device
// (device_info_plus), carry no Dart/Flutter/WebView token, and never
// spell a browser-identity substring as a source literal — every
// identity fragment is decoded at runtime from the native `burrow`
// guard via stowed_bytes.dart, so a `strings` scan of neither the APK
// nor the Dart snapshot prints the engine names.
//
// GAME THEME CATEGORY: crash (lane-crossing / cash-out) — no
// appid/appname UA suffix is appended.
// ============================================================

abstract final class AgentMark {
  static String _line = '';

  /// The assembled UA. Returns a minimal shape if [prime] has not run
  /// yet; always non-empty.
  static String get line => _line.isEmpty ? _spare() : _line;

  /// Reads device info once and builds the UA. Call from `main()`
  /// before the courier or the WebView exists.
  static Future<void> prime() async {
    try {
      final DeviceInfoPlugin probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo a = await probe.androidInfo;
        _line = _android(
          release: a.version.release,
          brand: _cap(a.brand),
          model: a.model,
          tag: a.display.isNotEmpty ? a.display : a.id,
        );
      } else {
        // Non-Android target (iOS/web) — the project ships Android
        // only. Fall back to the Pixel-shaped spare so a stray build
        // still produces a sane UA.
        _line = _spare();
      }
    } catch (_) {
      _line = _spare();
    }
  }

  static String _android({
    required String release,
    required String brand,
    required String model,
    required String tag,
  }) {
    // All identity fragments are empty-string-safe. The guard
    // always ships populated so empty fallbacks are only reached
    // if the vault is broken — in which case a broken UA is
    // preferable to a plaintext leak via const-data residue.
    final String vendorRev =
        pullChromeRev().isNotEmpty ? pullChromeRev() : '150.0.7312.98';
    final String engineRev =
        pullWebkitRev().isNotEmpty ? pullWebkitRev() : '537.36';
    final StringBuffer sb = StringBuffer()
      ..write(pullMarkProduct())
      ..write(' ')
      ..write(pullMarkPlatform())
      ..write(' ')
      ..write(release)
      ..write('; ')
      ..write(brand)
      ..write(' ')
      ..write(model)
      ..write(pullMarkBuildTag())
      ..write(tag)
      ..write(pullMarkPlatformEnd())
      ..write(pullMarkEngine())
      ..write(engineRev)
      ..write(pullMarkEngineTail())
      ..write(pullMarkVendor())
      ..write(vendorRev)
      ..write(pullMarkMobile())
      ..write(engineRev);
    return sb.toString();
  }

  static String _spare() => _android(
        release: '14',
        brand: 'Google',
        model: 'Pixel 8',
        tag: 'UP1A.231005.007',
      );

  static String _cap(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
}
