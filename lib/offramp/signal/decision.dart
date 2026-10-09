import 'dart:convert';
import 'dart:typed_data';

import '../cloak/burrow.dart';
import '../vault/stowed_bytes.dart';
import 'agent_mark.dart';
import 'outcome.dart';
import 'stash.dart';

// ============================================================
// DECISION — hand the attribution body to the guard, cache the answer
// ============================================================
// The POST itself runs inside the native guard: the endpoint and the
// header names stay encrypted there and are never Dart literals. The
// body goes out as compact JSON and the answer comes back as plain
// JSON (`ok` / `url` / `expires`). On a granted answer both the URL
// AND its expiry are cached so a returning launch can skip the
// network when the URL is still fresh. Any failure — HTTP error,
// timeout, bad JSON — yields a denied ruling; the dispatcher turns
// that into the game (or dead-air when the network itself is down).
// ============================================================

class Decision {
  Decision(this._stash);

  final Stash _stash;

  Future<Ruling> ask(Map<String, dynamic> body) async {
    if (!pullSyncUrlPresent()) return Ruling.denied('endpoint_missing');

    try {
      final Uint8List raw =
          Uint8List.fromList(utf8.encode(jsonEncode(body)));
      final ConfigReply reply = await deliverConfig(raw, AgentMark.line);

      assert(() {
        final String preview = reply.payload.length > 160
            ? '${reply.payload.substring(0, 160)}…'
            : reply.payload;
        // ignore: avoid_print
        print('[reply] code=${reply.code} body=$preview');
        return true;
      }());

      if (reply.code != 200) {
        return Ruling.denied('http_${reply.code}');
      }

      final dynamic decoded = jsonDecode(reply.payload);
      if (decoded is! Map) return Ruling.denied('malformed');
      final Ruling ruling =
          Ruling.fromWire(Map<String, dynamic>.from(decoded));

      if (ruling.hasTarget) {
        await _stash.cacheTarget(ruling.url!, ruling.expiresAt);
      }
      return ruling;
    } catch (e) {
      return Ruling.denied('net:$e');
    }
  }
}
