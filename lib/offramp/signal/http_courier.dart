import 'package:http/http.dart' as http;

import 'agent_mark.dart';

// ============================================================
// HTTP COURIER — client that always stamps the forged UA
// ============================================================
// Every outbound call in the off-ramp (edge POST, GCD rescue, push
// image fetch) rides this client so nothing leaves with Dart's
// default `dart-io/x.y` UA.
// ============================================================

class Courier extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = AgentMark.line;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Shared instance — primed after `AgentMark.prime()` in `main()`.
final Courier courier = Courier();
