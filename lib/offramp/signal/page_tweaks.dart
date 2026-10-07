import 'package:webview_flutter/webview_flutter.dart';

import '../vault/stowed_bytes.dart';

// ============================================================
// PAGE TWEAKS — JavaScript enhancers for the WebView
// ============================================================
// Each body is stored encoded in stowed_bytes.dart (no plaintext JS in
// the APK) and decoded at runtime. Every tweak is idempotent via its
// own window sentinel, so running the set on each onPageFinished is
// safe. Empty bodies are skipped.
// ============================================================

abstract final class PageTweaks {
  /// Runs the ordered enhancer set on [controller].
  static Future<void> apply(WebViewController controller) async {
    for (final String body in _bodies) {
      if (body.isEmpty) continue;
      await controller.runJavaScript(body);
    }
  }

  static List<String> get _bodies => <String>[
        pullTweakSafeArea(),
        pullTweakKeyboard(),
        pullTweakAutoplay(),
      ];
}
