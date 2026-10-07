import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../vault/junction_env.dart';
import '../vault/stowed_bytes.dart';
import '../cloak/inset_ledger.dart';
import '../signal/agent_mark.dart';
import '../signal/page_tweaks.dart';
import '../signal/pushwatch.dart';
import '../signal/reach_scout.dart';
import '../signal/stash.dart';
import 'no_signal.dart';

// ============================================================
// WEB HALL — the WebView shell (gray content)
// ============================================================
// Hosts the destination URL with the forged device UA (identical to
// the courier's), all orientations, immersive chrome, external-scheme
// hand-off, bounded redirect-loop recovery, a debounced connectivity
// guard, warm push delivery, a native file chooser over a
// MethodChannel, and the PageTweaks JS set.
//
// There is NO client-side classification of the partner site — any
// funnel lives server-side; this is a dumb shell.
//
// The camera-cutout inset is learned once per orientation and cached in
// the native geometry ledger (native/drift) so a rotation applies its
// final geometry in a single frame. The WebView is NOT shrunk for the
// keyboard — the native window runs in ADJUST_NOTHING so it keeps full
// height (responsive modals never collapse); the page's JS enhancer
// reads the live `window.visualViewport` band and lifts the focused
// field above the keyboard with `scrollIntoView`. The native ime height
// is pushed through `window.__ttxSeat` only as a settle-trigger/fallback.
// The system navigation bar never contributes a safe area — it is hidden
// by WindowInsetsController in MainActivity, in either orientation.
// ============================================================

class WebHall extends StatefulWidget {
  const WebHall({
    super.key,
    required this.url,
    required this.stash,
    required this.push,
  });

  final String url;
  final Stash stash;
  final PushWatch push;

  @override
  State<WebHall> createState() => _WebHallState();
}

class _WebHallState extends State<WebHall> with WidgetsBindingObserver {
  // Bridge name and method keys come from the native vault, so no plaintext
  // literal lands in the snapshot; MainActivity derives the same strings.
  late final MethodChannel _io;
  String _mPick = '';
  String _mIme = '';
  String _mCloak = '';

  late final WebViewController _web;
  bool _spinner = true;
  bool _leftForOffline = false;
  String? _lastTop;
  int _retries = 0;
  Timer? _dropTimer;
  int _kbSent = -1;
  String _seat = '';
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _seat = pullTweakSeatHook();
    _io = MethodChannel(pullIoChannel());
    _mPick = pullIoPick();
    _mIme = pullIoIme();
    _mCloak = pullIoCloak();
    _immersive();
    _build();

    // Native keyboard-height feed (WindowInsets.ime from MainActivity),
    // pushed to the page's `window.__ttxSeat` enhancer as a trigger and a
    // fallback height. The enhancer itself primarily reads the live
    // `visualViewport` band, but the native nudge re-runs the reveal once
    // the IME animation settles (and feeds the old-WebView padding path).
    _io.setMethodCallHandler((MethodCall call) async {
      if (call.method == _mIme && _seat.isNotEmpty) {
        final int px = (call.arguments as num?)?.round() ?? 0;
        if (px != _kbSent) {
          _kbSent = px;
          _web
              .runJavaScript('window.$_seat&&window.$_seat($px);')
              .catchError((_) {});
        }
      }
      return null;
    });

    widget.push.onUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    _connSub = ReachScout().changes.listen((List<ConnectivityResult> r) {
      final bool allDown = r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allDown) {
        _dropTimer?.cancel();
        return;
      }
      _dropTimer?.cancel();
      _dropTimer = Timer(
        Duration(milliseconds: JunctionEnv.reachDropDebounceMs),
        _toOffline,
      );
    });
  }

  void _immersive() {
    // Edge-to-edge (NOT fullscreen). MainActivity hides the system bars
    // with WindowInsetsController — so no safe area is consumed under the
    // navigation bar — while the window stays resizable-aware, which lets
    // the WebView's `visualViewport` report the keyboard band in both
    // orientations (fullscreen/immersive never exposed it in landscape).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ));
    // edgeToEdge re-shows the bars; the native controller tucks them back
    // on the next frame so they never flash on first entry (not only after
    // the first focus change).
    _io.invokeMethod<void>(_mCloak).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _immersive();
  }

  void _build() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(AgentMark.line)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _retries = 0;
          PageTweaks.apply(_web);
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _configureAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;
    final String blurb = err.description.toLowerCase();

    final bool loop = blurb.contains('too_many_redirects') ||
        blurb.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;
    if (loop && _lastTop != null && _retries < JunctionEnv.redirectLoopRetries) {
      _retries++;
      _web.loadRequest(Uri.parse(_lastTop!));
      return;
    }

    // Cover the native chrome error page immediately.
    if (mounted) setState(() => _spinner = true);

    final bool netGone = blurb.contains('name_not_resolved') ||
        blurb.contains('address_unreachable') ||
        blurb.contains('internet_disconnected') ||
        blurb.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;
    if (netGone) {
      _toOffline();
    } else {
      _toOfflineIfDown();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inApp = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (inApp.contains(uri.scheme)) {
      if (req.isMainFrame) _lastTop = req.url;
      return NavigationDecision.navigate;
    }
    _handoff(uri);
    return NavigationDecision.prevent;
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a = _web.platform as AndroidWebViewController;
    a.setMediaPlaybackRequiresUserGesture(false);
    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    a.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked =
          await _io.invokeMethod<List<Object?>>(_mPick, <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _handoff(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _toOfflineIfDown() async {
    if (_leftForOffline) return;
    if (await ReachScout().canResolve()) return;
    _toOffline();
  }

  void _toOffline() {
    if (_leftForOffline || !mounted) return;
    _leftForOffline = true;
    final String here = _lastTop ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalScreen(
          onRetry: (_) => WebHall(
            url: here,
            stash: widget.stash,
            push: widget.push,
          ),
        ),
      ),
    );
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  // Resolves the camera-cutout inset for the current orientation from
  // the native ledger. The first clean read (keyboard down, immersive
  // nav bar hidden, so `viewPadding` holds the cutout alone) is learned
  // natively and reused forever — including across a WebHall rebuild —
  // so the transient nav bar the IME forces on open/close can never
  // churn the inset, and a rotation hits the cached value instantly.
  EdgeInsets _cutoutFor(MediaQueryData mq) {
    final Orientation o = mq.orientation;
    if (!InsetLedger.hasCutout(o)) {
      if (mq.viewInsets.bottom != 0) {
        // Keyboard is up and nothing learned yet — a bare top inset
        // until we can capture cleanly.
        return EdgeInsets.only(top: mq.viewPadding.top);
      }
      InsetLedger.learnCutout(
        o,
        EdgeInsets.only(
          top: mq.viewPadding.top,
          left: mq.viewPadding.left,
          right: mq.viewPadding.right,
        ),
      );
    }
    return InsetLedger.cutout(o);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropTimer?.cancel();
    _io.setMethodCallHandler(null);
    _connSub?.cancel();
    widget.push.onUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;

    // Camera cutout on top/sides (cached natively). The WebView keeps its
    // full height; the keyboard overlays it (ADJUST_NOTHING) and the
    // focused field is lifted above the keyboard by the page JS, which
    // reads the live visualViewport band. The navigation bar never adds a
    // safe area.
    final EdgeInsets cutout = _cutoutFor(mq);
    final EdgeInsets pad = EdgeInsets.only(
      top: cutout.top,
      left: cutout.left,
      right: cutout.right,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _back();
      },
      // Strip the bottom keyboard inset from Flutter's view of the world:
      // the WebView runs in ADJUST_NOTHING and handles the keyboard itself
      // via visualViewport, so nothing on the Flutter side should shift.
      child: MediaQuery(
        data: mq.copyWith(viewInsets: EdgeInsets.zero),
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Padding(
                padding: pad,
                child: WebViewWidget(controller: _web),
              ),
              if (_spinner && !landscape)
                const ColoredBox(
                  color: Color(0x80000000),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFF2BE35)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
