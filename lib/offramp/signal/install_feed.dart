import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../vault/junction_env.dart';

// ============================================================
// INSTALL FEED — AppsFlyer install + deep-link collector
// ============================================================
// Folds three signals into the decision body:
//   1. onInstallConversionData — install attribution
//   2. onDeepLinking            — UDL / OneLink click
//   3. onAppOpenAttribution     — returning-user attribution
//
// Organic fast-path: when the first conversion callback already reports
// `af_status: Organic` there is no paid attribution to wait for, so we
// stop waiting for a deep link immediately and flag the install organic.
// The dispatcher then decides on the very first config answer without a
// retry poll, so a genuine organic first launch settles in well under
// ten seconds. (We no longer re-pull GCD — that extra AppsFlyer round
// trip only delayed the organic → game path.)
//
// Short-circuit: with no dev key packed yet, the SDK never boots and
// the futures resolve to empty maps so QA can exercise the game path.
// ============================================================

class InstallFeed {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _install;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _appOpen;
  bool _organic = false;

  /// True once AppsFlyer has reported this install as organic. The
  /// dispatcher uses it to skip the late-attribution retry poll — an
  /// organic verdict will not change, so the native game can start as
  /// soon as the first config answer lands.
  bool get wasOrganic => _organic;

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
      _install = data;
      if (data['af_status']?.toString() == 'Organic') {
        // Organic: no paid attribution and no deep link to wait for.
        _organic = true;
        _finishDeepLink();
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
      print('[compose] ${jsonEncode(body)}');
      return true;
    }());
    return body;
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
