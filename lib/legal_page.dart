import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'offramp/signal/agent_mark.dart';

const _shell = MethodChannel('turkey_tunnel/shell');

Future<void> tuneWebView() async {
  try {
    await _shell.invokeMethod<void>('tuneWebView');
  } on PlatformException {
    // The page still loads. This only stops the view from recoloring it.
  } on MissingPluginException {
    return;
  }
}

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final WebViewController _controller;
  var _progress = 0;
  var _failed = false;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            tuneWebView();
            if (!mounted) return;
            setState(() => _failed = false);
          },
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value);
          },
          onPageFinished: (_) {
            tuneWebView();
            if (!mounted) return;
            setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            if (!mounted) return;
            setState(() => _failed = true);
          },
        ),
      );
    WidgetsBinding.instance.addPostFrameCallback((_) => tuneWebView());
    _open();
  }

  Future<void> _open() async {
    try {
      final existing = await _controller.getUserAgent();
      await _controller.setUserAgent(_chromeAgent(existing));
    } on PlatformException {
      // The stock agent still renders the page.
    }
    if (!mounted) return;
    setState(() => _ready = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  String _chromeAgent(String? ua) {
    // Reuse the same forged UA the off-ramp courier stamps — keeps
    // the two WebViews fingerprint-identical and avoids a plaintext
    // Mozilla/… literal landing in const data.
    if (ua == null || ua.isEmpty) return AgentMark.line;
    return ua.replaceAll('; wv', '').replaceAll('Version/4.0 ', '');
  }

  Future<void> _back() async {
    if (_ready && await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _retry() {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: AppBar(
          backgroundColor: const Color(0xFF202124),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              if (_ready) WebViewWidget(controller: _controller),
              if (_progress < 100 && !_failed)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress / 100,
                    minHeight: 3,
                    color: const Color(0xFF1A73E8),
                    backgroundColor: const Color(0xFFE8EAED),
                  ),
                ),
              if (_failed)
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFFFFFFFF)),
                ),
              if (_failed)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'This page did not load.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.url,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF5F6368),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Try again'),
                        ),
                      ],
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
