import 'stash.dart';

// ============================================================
// COLDLINK — cold-boot push URL reader
// ============================================================
// A cold-boot push tap arrives through the launch intent, which
// Firebase Messaging surfaces via getInitialMessage(); PushWatch
// drops the URL into the stash's pending slot. This one-shot reader
// gives the dispatcher a single entry point for cold-launch URLs.
// ============================================================

abstract final class ColdLink {
  /// Reads and clears the pending URL, or null when there was no tap.
  static Future<String?> take(Stash stash) => stash.takePending();
}
