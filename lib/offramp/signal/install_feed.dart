import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../vault/junction_env.dart';
import '../vault/stowed_bytes.dart';
import 'http_courier.dart';

// ============================================================
// INSTALL FEED — AppsFlyer install + deep-link collector
// ============================================================
// Folds three signals into the decision body:
//   1. onInstallConversionData — install attribution
//   2. onDeepLinking            — UDL / OneLink click
//   3. onAppOpenAttribution     — returning-user attribution
//
// Organic rescue: AppsFlyer sometimes reports `af_status: Organic` on
// the FIRST callback for a genuinely paid install. When it does, we
// wait `organicRescueDelay` seconds and re-pull GCD; the rescue wins,
// and if it fails we keep Organic (safe → game).
//
// Short-circuit: with no dev key packed yet, the SDK never boots and
// the futures resolve to empty maps so QA can exercise the game path.
// ============================================================

class InstallFeed {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _install;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _appOpen;

  final Completer<Map<String, dynamic>> _installDone =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkDone = Completer<void>();

  bool _booted = false;

  Future<void> start() async {
    if (_booted) return;
    _booted = true;

    final String devKey = JunctionEnv.trackKey;
    if (devKey.isEmpty) {
      _finishInstall(const <String, dynamic>{});
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: JunctionEnv.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );
    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> data = _flatten(raw);
      if (data['af_status']?.toString() == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: JunctionEnv.organicRescueDelay),
        );
        _install = await _gcdRescue() ?? data;
      } else {
        _install = data;
      }
      _finishInstall(_install ?? const <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic raw) => _appOpen = _flatten(raw));

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) _deepLink = Map<String, dynamic>.from(click);
      _finishDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall(const <String, dynamic>{});
      _finishDeepLink();
    }
  }

  /// Waits (capped) for the install + deep-link callbacks before the
  /// decision POST.
  Future<void> awaitSignals({int? installSeconds}) async {
    final int secs = installSeconds ?? JunctionEnv.firstInstallWaitSeconds;
    await Future.wait<void>(<Future<void>>[
      _installDone.future.timeout(
        Duration(seconds: secs),
        onTimeout: () => const <String, dynamic>{},
      ),
      _deepLinkDone.future.timeout(
        Duration(seconds: JunctionEnv.deepLinkWaitSeconds),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> deviceId() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assembles the flat decision body. Attribution payloads come first,
  /// then the device-side fields (verbatim contract).
  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    _deepLink?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpen?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceId() ?? '';
    body['bundle_id'] = JunctionEnv.applicationId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = JunctionEnv.storeTag;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String fcm = JunctionEnv.fcmProject;
    if (fcm.isNotEmpty) body['firebase_project_id'] = fcm;

    assert(() {
      // ignore: avoid_print
      print('[OFFRAMP.FEED] compose ${jsonEncode(body)}');
      return true;
    }());
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRescue() async {
    try {
      final String? uid = await deviceId();
      if (uid == null) return null;
      final String ref = Platform.isIOS
          ? JunctionEnv.storeNumericId
          : JunctionEnv.applicationId;
      final String url = pullGcdCallUrl(ref, uid);
      if (url.isEmpty) return null;
      final dynamic res = await courier.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${JunctionEnv.trackKey}',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall(Map<String, dynamic> data) {
    if (!_installDone.isCompleted) _installDone.complete(data);
  }

  void _finishDeepLink() {
    if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
  }

  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
