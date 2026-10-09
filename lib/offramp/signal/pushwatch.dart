import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'http_courier.dart';
import 'stash.dart';

// ============================================================
// PUSHWATCH — Firebase Messaging + local notifications
// ============================================================
// Cold-start taps (app killed) drop the URL into the stash so the boot
// pipeline collects it next frame. Warm taps deliver through
// [onUrl]; those are one-shot and not persisted.
//
// The channel id must equal the AndroidManifest
// default_notification_channel_id. Rotated for this app.
// ============================================================

const String kPushChannelId = 'promo_pulse';
const String kPushChannelName = 'Bonuses & Promos';
const String _smallIcon = '@drawable/ic_notification';

class PushWatch {
  PushWatch(this._stash);

  final Stash _stash;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  bool _ready = false;

  /// Warm-tap URL delivery — the WebView loads this directly.
  void Function(String url)? onUrl;

  /// FCM rotated the token — the dispatcher re-POSTs so the backend can
  /// target this device.
  void Function(String token)? onToken;

  String? get token => _token;

  Future<void> warm() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _fm = FirebaseMessaging.instance;

      await _setupLocal();

      // FIS outages make getToken() retry internally without ever
      // resolving; an unbounded await here stalls the whole boot.
      _token = await _fm!.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      _fm!.onTokenRefresh.listen((String t) {
        _token = t;
        onToken?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? first = await _fm!.getInitialMessage().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (first != null) _onColdTap(first);

      _ready = true;
    } catch (_) {
      // Firebase not configured yet — push stays dormant.
    }
  }

  Future<void> _setupLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: apple),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) onUrl?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? plugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kPushChannelId,
          kPushChannelName,
          description: 'Bonuses, offers and promos',
          importance: Importance.high,
        ),
      );
    }
  }

  /// System prompt. Records an OS-denied flag so the opt-in stage stops
  /// reappearing after a hard "no".
  Future<bool> requestPermission() async {
    if (_fm == null) return false;
    final NotificationSettings s = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = s.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _stash.markOptinGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _stash.markOptinBlockedByOs();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? image = n.android?.imageUrl;
    if (image != null && image.isNotEmpty) {
      final Uint8List? bytes = await _fetch(image);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kPushChannelId,
          kPushChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kPushChannelId,
      kPushChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
    );

    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) _stash.stashPending(url);
  }

  void _onWarmTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) onUrl?.call(url);
  }

  Future<Uint8List?> _fetch(String url) async {
    try {
      final dynamic res = await courier
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
