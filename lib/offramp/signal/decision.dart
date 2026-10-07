import 'dart:convert';

import '../vault/junction_env.dart';
import 'envelope.dart';
import 'http_courier.dart';
import 'outcome.dart';
import 'stash.dart';

// ============================================================
// DECISION — seal the body, POST it, cache the answer
// ============================================================
// The edge relay is the single source of truth for routing. On a
// granted answer both the URL AND its expiry are cached so a returning
// launch can skip the network when the URL is still fresh. Any failure
// — HTTP error, timeout, bad JSON, missing secret — yields a denied
// ruling; the dispatcher turns that into the game (or dead-air when
// the network itself is down).
// ============================================================

class Decision {
  Decision(this._stash);

  final Stash _stash;

  Future<Ruling> ask(Map<String, dynamic> body) async {
    final String endpoint = JunctionEnv.syncUrl;
    if (endpoint.isEmpty) return Ruling.denied('endpoint_missing');

    final Map<String, dynamic>? sealed = Envelope.seal(body);
    if (sealed == null) return Ruling.denied('secret_missing');

    try {
      final dynamic res = await courier
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(sealed),
          )
          .timeout(Duration(seconds: JunctionEnv.decisionTimeoutSeconds));

      if (res.statusCode != 200) {
        return Ruling.denied('http_${res.statusCode}');
      }

      final dynamic decoded = jsonDecode(res.body);
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
