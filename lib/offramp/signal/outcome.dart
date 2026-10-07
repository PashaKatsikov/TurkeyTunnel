// ============================================================
// OUTCOME — the three sealed results of the boot decision
// ============================================================
// `Dispatcher.resolve()` returns exactly one `Exit`. The loading
// surface switches over it and pushes a single route. No routing
// branch lives anywhere else.
// ============================================================

/// Persisted lane across launches. Legacy wire spellings are still
/// accepted on read so an upgraded install keeps its lane.
enum LaneMemory {
  undecided,
  webBound,
  gameBound;

  String get wire => switch (this) {
        LaneMemory.undecided => 'u',
        LaneMemory.webBound => 'w',
        LaneMemory.gameBound => 'g',
      };

  static LaneMemory read(String? raw) => switch (raw) {
        'w' || 'web' || 'portal' => LaneMemory.webBound,
        'g' || 'game' || 'native' => LaneMemory.gameBound,
        _ => LaneMemory.undecided,
      };
}

/// Parsed answer from the edge relay. Wire keys stay `{ok,url,expires,
/// message}` — the upstream config contract owns those spellings.
class Ruling {
  const Ruling({required this.granted, this.url, this.expiresAt, this.note});

  factory Ruling.fromWire(Map<String, dynamic> wire) {
    final dynamic rawExpiry = wire['expires'];
    return Ruling(
      granted: wire['ok'] == true,
      url: wire['url'] is String ? wire['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      note: wire['message']?.toString(),
    );
  }

  factory Ruling.denied(String note) => Ruling(granted: false, note: note);

  final bool granted;
  final String? url;
  final int? expiresAt;
  final String? note;

  bool get hasTarget => granted && url != null && url!.isNotEmpty;
}

/// Sealed boot outcome. Adding a destination forces a new case at
/// every switch site.
sealed class Exit {
  const Exit();
}

/// Run the native game.
final class GameExit extends Exit {
  const GameExit();
}

/// Open the WebView on [url]. [coldTap] is true only when the launch
/// came from a cold-boot push tap (URL from the intent, not the cache).
final class WebExit extends Exit {
  const WebExit(this.url, {this.coldTap = false});

  final String url;
  final bool coldTap;
}

/// Show the no-connection screen. [wasGame] is true when the user was
/// previously on the native lane, so a retry can go straight back.
final class DeadAirExit extends Exit {
  const DeadAirExit({required this.wasGame});

  final bool wasGame;
}
