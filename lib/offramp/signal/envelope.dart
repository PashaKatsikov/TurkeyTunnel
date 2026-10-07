import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../vault/junction_env.dart';

// ============================================================
// ENVELOPE — opaque wire packer for the edge relay
// ============================================================
// The edge relay never sees the config key names on the wire; it
// receives a sealed blob and rebuilds the clean attribution body on
// its side. This mirrors scripts/relay_service.py exactly:
//
//   raw       = utf8(json(body, compact))
//   keystream = concat( sha256(secret + nonce + counterBE32) )
//   enc       = raw XOR keystream
//   payload   = base64url(enc) without '='
//   tag       = HMAC_SHA256(secret, nonce + enc).hex()[:16]
//   wire      = { fieldSchema: rev, fieldNonce: nonce.hex,
//                 fieldPayload: payload, fieldTag: tag }
//
// Field names + schema rev come from JunctionEnv and must match the
// deployed relay's FIELD_*/SCHEMA_REV constants.
// ============================================================

abstract final class Envelope {
  static final Random _rng = Random.secure();

  /// Seals [body] for `POST`. Returns null when the shared secret is
  /// absent (gate not wired yet).
  static Map<String, dynamic>? seal(Map<String, dynamic> body) {
    final String secretText = JunctionEnv.sealKey;
    if (secretText.isEmpty) return null;
    final List<int> secret = utf8.encode(secretText);

    final Uint8List raw =
        Uint8List.fromList(utf8.encode(jsonEncode(body)));
    final Uint8List nonce = _nonce(16);
    final Uint8List key = _keystream(secret, nonce, raw.length);

    final Uint8List enc = Uint8List(raw.length);
    for (int i = 0; i < raw.length; i++) {
      enc[i] = raw[i] ^ key[i];
    }

    final String tag = Hmac(sha256, secret)
        .convert(<int>[...nonce, ...enc])
        .toString()
        .substring(0, 16);

    return <String, dynamic>{
      JunctionEnv.fieldSchema: JunctionEnv.envelopeRev,
      JunctionEnv.fieldNonce: _hex(nonce),
      JunctionEnv.fieldPayload: _b64url(enc),
      JunctionEnv.fieldTag: tag,
    };
  }

  static Uint8List _keystream(List<int> secret, Uint8List nonce, int length) {
    final BytesBuilder acc = BytesBuilder();
    int counter = 0;
    while (acc.length < length) {
      final Uint8List be = Uint8List(4)
        ..buffer.asByteData().setUint32(0, counter, Endian.big);
      acc.add(sha256.convert(<int>[...secret, ...nonce, ...be]).bytes);
      counter++;
    }
    return Uint8List.fromList(acc.toBytes().sublist(0, length));
  }

  static Uint8List _nonce(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  static String _hex(List<int> bytes) =>
      bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
