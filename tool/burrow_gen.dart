// Standalone generator for native/burrow/src/vault.rs.
//
// The gray-part strings (edge endpoint, attribution key, UA fragments,
// WebView JS enhancers, notification-screen copy) must not live as
// readable literals anywhere — not in the Dart snapshot and not in the
// native `.so`. They live in the `burrow` guard as obfuscated byte
// arrays and are de-obfuscated per call behind the `bw_s` FFI export.
//
// This tool encodes every plaintext with the project scrambler (the
// exact scheme ported into native/burrow/src/lib.rs: fnv1a(salt) seeds
// an xorshift32 keystream; each byte is XORed with the keystream then
// bit-rotated left by (index & 7)) and writes the Rust vault module.
//
// Run after changing any gray-part string:
//
//   dart run tool/burrow_gen.dart
//
// then rebuild so the native crate picks up the new bytes.
import 'dart:convert';
import 'dart:io';

// Keep in lock-step with native/burrow/src/lib.rs AND
// lib/offramp/cloak/scrambler.dart.
const List<int> _salt = <int>[
  57, 151, 211, 209, 38, 32, 188, 3, 69, 25, 15, 102, 5, 109, 12, 27, 31, 81,
];
const int _streamLen = 29;

int _fnv1a(List<int> data) {
  int h = 0x811C9DC5;
  for (final int c in data) {
    h = (h ^ c) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h == 0 ? 0x9E3779B1 : h;
}

List<int> _stream() {
  int s = _fnv1a(_salt);
  final List<int> out = List<int>.filled(_streamLen, 0);
  for (int i = 0; i < _streamLen; i++) {
    s ^= (s << 13) & 0xFFFFFFFF;
    s ^= s >> 17;
    s ^= (s << 5) & 0xFFFFFFFF;
    s &= 0xFFFFFFFF;
    out[i] = (s >> 24) & 0xFF;
  }
  return out;
}

int _rotl8(int v, int r) => r == 0 ? v : ((v << r) | (v >> (8 - r))) & 0xFF;
int _rotr8(int v, int r) => r == 0 ? v : ((v >> r) | (v << (8 - r))) & 0xFF;

List<int> _hide(String plain) {
  if (plain.isEmpty) return const <int>[];
  final List<int> k = _stream();
  final List<int> src = utf8.encode(plain);
  final List<int> out = List<int>.filled(src.length, 0);
  for (int i = 0; i < src.length; i++) {
    out[i] = _rotl8((src[i] ^ k[i % _streamLen]) & 0xFF, i & 7);
  }
  return out;
}

String _show(List<int> enc) {
  if (enc.isEmpty) return '';
  final List<int> k = _stream();
  final List<int> out = List<int>.filled(enc.length, 0);
  for (int i = 0; i < enc.length; i++) {
    out[i] = (_rotr8(enc[i], i & 7) ^ k[i % _streamLen]) & 0xFF;
  }
  return utf8.decode(out);
}

// Selector → (Rust const name, plaintext). The numbers MUST match the
// `Sel` constants in lib/offramp/cloak/burrow.dart.
const Map<int, List<String>> _slots = <int, List<String>>{
  1: <String>['SYNC_URL', 'https://turkeytunel.com/edge/sync'],
  2: <String>['SEAL_KEY', 'wgb-YvHEqlwYj9SDZDHnPK8GyXRxQum17jjSRSfl2Tc'],
  3: <String>['GCD_BASE', 'https://gcdsdk.appsflyer.com/install_data/v4.0/'],
  4: <String>['TRACK_KEY', 'zbT5dX3heftXVwy2RuJ7d8'],
  5: <String>['FCM_PROJECT', '368773492069'],
  6: <String>['MARK_PRODUCT', 'Mozilla/5.0'],
  7: <String>['MARK_PLATFORM', '(Linux; Android'],
  8: <String>['MARK_BUILD_TAG', ' Build/'],
  9: <String>['MARK_PLATFORM_END', ')'],
  10: <String>['MARK_ENGINE', ' AppleWebKit/'],
  11: <String>['MARK_ENGINE_TAIL', ' (KHTML, like Gecko)'],
  12: <String>['MARK_VENDOR', ' Chrome/'],
  13: <String>['MARK_MOBILE', ' Mobile Safari/'],
  14: <String>['CHROME_REV', '150.0.7312.98'],
  15: <String>['WEBKIT_REV', '537.36'],
  16: <String>['TWEAK_SAFE_AREA', _safeAreaJs],
  17: <String>['TWEAK_AUTOPLAY', _autoplayJs],
  18: <String>['TWEAK_KEYBOARD', _keyboardJs],
  19: <String>['OPTIN_TITLE', 'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS'],
  20: <String>['OPTIN_BODY', 'Stay tuned for special offers and rewards'],
  // ── Gray-part constants (numeric + edge-wire shape) ──────────
  21: <String>['OPTIN_SNOOZE_SECONDS', '258972'],
  22: <String>['ORGANIC_RESCUE_DELAY', '9'],
  23: <String>['DECISION_TIMEOUT_SECONDS', '21'],
  24: <String>['FIRST_INSTALL_WAIT_SECONDS', '33'],
  25: <String>['RETURNING_INSTALL_WAIT_SECONDS', '8'],
  26: <String>['DEEP_LINK_WAIT_SECONDS', '6'],
  27: <String>['REACH_TIMEOUT_SECONDS', '8'],
  28: <String>['REACH_DROP_DEBOUNCE_MS', '950'],
  29: <String>['REDIRECT_LOOP_RETRIES', '3'],
  30: <String>['CACHED_URL_TTL_SECONDS', '604800'],
  31: <String>['NATIVE_RETRY_GAP_SECONDS', '3'],
  32: <String>['ENVELOPE_REV', '17'],
  33: <String>['FIELD_SCHEMA', 'f'],
  34: <String>['FIELD_NONCE', 'o'],
  35: <String>['FIELD_PAYLOAD', 'i'],
  36: <String>['FIELD_TAG', 'd'],
  37: <String>['TWEAK_SEAT_HOOK', '__ttxSeat'],
  38: <String>['IO_CHANNEL', 'junction/io'],
  39: <String>['IO_PICK', 'pick'],
  40: <String>['IO_IME', 'ime'],
  41: <String>['IO_CLOAK', 'cloak'],
};

String _rustArray(String name, List<int> enc) {
  final StringBuffer b = StringBuffer('pub const $name: [u8; ${enc.length}] = [');
  if (enc.isEmpty) {
    b.write('];');
    return b.toString();
  }
  b.write('\n');
  for (int i = 0; i < enc.length; i++) {
    if (i % 12 == 0) b.write('    ');
    b.write(enc[i]);
    b.write(',');
    b.write(i % 12 == 11 || i == enc.length - 1 ? '\n' : ' ');
  }
  b.write('];');
  return b.toString();
}

void main() {
  final StringBuffer out = StringBuffer()
    ..writeln('// GENERATED by tool/burrow_gen.dart — do not edit by hand.')
    ..writeln('//')
    ..writeln('// Obfuscated gray-part strings. De-obfuscated at call time by')
    ..writeln('// `expose` in lib.rs; never held as plaintext in a static.')
    ..writeln('#![allow(clippy::all)]')
    ..writeln();

  final List<int> keys = _slots.keys.toList()..sort();
  for (final int sel in keys) {
    final String name = _slots[sel]![0];
    final String plain = _slots[sel]![1];
    final List<int> enc = _hide(plain);
    if (_show(enc) != plain) {
      throw StateError('round-trip MISMATCH for $name');
    }
    out.writeln(_rustArray(name, enc));
    out.writeln();
  }

  out.writeln('pub fn raw(sel: u32) -> &\'static [u8] {');
  out.writeln('    match sel {');
  for (final int sel in keys) {
    out.writeln('        $sel => &${_slots[sel]![0]},');
  }
  out.writeln('        _ => &[],');
  out.writeln('    }');
  out.writeln('}');

  final File target = File('native/burrow/src/vault.rs');
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(out.toString());
  // ignore: avoid_print
  print('wrote ${target.path} (${keys.length} slots)');
}

// ── JS enhancer bodies (identical to tool/scramble_gen.dart) ──────────

// Safe-area neutraliser — overrides the site's OWN safe-area CSS vars
// and only trims known decorative top spacers. Never touches
// html/body/#app/#root horizontal padding (see the webview safe-area
// rule). Written as an IIFE with a project-unique sentinel.
const String _safeAreaJs =
    "(function(){if(window.__ttx_sa)return;window.__ttx_sa=1;"
    "var c=':root{--safe-area-inset-top:0px!important;"
    "--safe-area-inset-right:0px!important;"
    "--safe-area-inset-bottom:0px!important;"
    "--safe-area-inset-left:0px!important;"
    "--sat:0px!important;--sab:0px!important;"
    "--safe-top:0px!important;--safe-bottom:0px!important;}"
    "header.app-header,.gameview-mobile-header,.js-safe-top{"
    "padding-top:0!important;margin-top:0!important;}';"
    "var s=document.createElement('style');s.textContent=c;"
    "document.head.appendChild(s);})();";

// Inline autoplay nudge — mark media elements playsinline + muted so
// the compositor keeps them inline. Harmless on sites without media.
const String _autoplayJs =
    "(function(){if(window.__ttx_ap)return;window.__ttx_ap=1;"
    "var fix=function(v){try{v.setAttribute('playsinline','');"
    "v.setAttribute('webkit-playsinline','');}catch(e){}};"
    "document.querySelectorAll('video').forEach(fix);"
    "var mo=new MutationObserver(function(muts){muts.forEach(function(m){"
    "Array.prototype.forEach.call(m.addedNodes||[],function(n){"
    "if(n&&n.tagName==='VIDEO')fix(n);});});});"
    "mo.observe(document.documentElement,{childList:true,subtree:true});})();";

// Keyboard reveal — keeps the focused field just above the soft
// keyboard WITHOUT resizing the page viewport (so responsive modals
// never collapse; the native window runs in ADJUST_NOTHING).
//
// The live keyboard height is read from `window.visualViewport`: when
// the IME overlays the page, `visualViewport.height` shrinks and
// `offsetTop` shifts even though `window.innerHeight` stays constant and
// the window never resizes. That gives the true visible band
// [offsetTop, offsetTop+height] in BOTH orientations — which is exactly
// what was missing before (immersive-fullscreen never exposed it).
//
// `lane()` is that visible band; if the focused field falls outside it,
// `scrollIntoView({block:'center'})` lifts it in — the browser walks the
// real nested scroll containers itself, so nothing flies off the top and
// no manual window scrolling is needed. When `visualViewport` is absent
// (old WebView), a bottom padding (`held`, the native ime height pushed
// through `window.__ttxSeat(px)`) adds room as a fallback. Re-runs are
// coalesced via rAF; an `orientationchange` hush suppresses the churn.
const String _keyboardJs =
    "!function(win,doc){if(win.__ttxKbd){return;}win.__ttxKbd=1;"
    "var held=0,frame=0,quiet=0;"
    "var dead={button:1,submit:1,reset:1,checkbox:1,radio:1,file:1,"
    "hidden:1,range:1,color:1,image:1};"
    "function editable(node){if(!node){return false;}"
    "var tag=String(node.nodeName||'').toLowerCase();"
    "if(tag==='input'){return !dead[String(node.type||'').toLowerCase()];}"
    "return tag==='textarea'||tag==='select'||node.isContentEditable===true;}"
    "function gap(){var port=win.visualViewport;if(!port){return 0;}"
    "var delta=win.innerHeight-port.height;return delta>22?delta:0;}"
    "function cover(){var live=gap();return live>held?live:held;}"
    "function lane(){var port=win.visualViewport;var live=gap();"
    "if(live&&port){return {a:port.offsetTop,b:port.offsetTop+port.height};}"
    "var floor=win.innerHeight-held;return {a:0,b:floor>0?floor:0};}"
    "function wipe(){var html=doc.documentElement;"
    "if(!html.style.paddingBottom&&!html.classList.contains('ttx-kb')){return;}"
    "html.classList.remove('ttx-kb');html.style.paddingBottom='';}"
    "function paint(){if(quiet){return;}var h=cover();var html=doc.documentElement;"
    "html.classList[h>40?'add':'remove']('ttx-kb');"
    "html.style.paddingBottom=(!gap()&&h>20)?(h+'px'):'';}"
    "function reveal(){if(quiet||cover()<20){return;}var node=doc.activeElement;"
    "if(!editable(node)){return;}var box=node.getBoundingClientRect();"
    "var band=lane(),pad=10;"
    "if(box.bottom<=band.b-pad&&box.top>=band.a+pad){return;}"
    "try{node.scrollIntoView({behavior:'auto',inline:'nearest',block:'center'});}"
    "catch(e1){try{node.scrollIntoView(true);}catch(e2){}}}"
    "function queue(){if(quiet){return;}if(frame){cancelAnimationFrame(frame);}"
    "frame=requestAnimationFrame(function(){frame=0;reveal();});}"
    "win.__ttxSeat=function(px){if(quiet){return;}var next=px|0;if(next<0){next=0;}"
    "if(Math.abs(next-held)<6){return;}held=next;paint();queue();"
    "clearTimeout(win.__ttxHold);win.__ttxHold=setTimeout(reveal,210);};"
    "var port=win.visualViewport,prev=gap();"
    "if(port){port.addEventListener('resize',function(){if(quiet){return;}"
    "var now=gap();if(Math.abs(now-prev)<22){return;}prev=now;paint();queue();});}"
    "doc.addEventListener('focusin',function(){if(quiet){return;}queue();"
    "clearTimeout(win.__ttxFocus);win.__ttxFocus=setTimeout(reveal,280);},true);"
    "function hush(){quiet=1;held=0;if(frame){cancelAnimationFrame(frame);frame=0;}"
    "wipe();clearTimeout(win.__ttxSpin);"
    "win.__ttxSpin=setTimeout(function(){quiet=0;if(port){prev=gap();}},640);}"
    "win.addEventListener('orientationchange',hush);"
    "if(win.screen&&win.screen.orientation){"
    "win.screen.orientation.addEventListener('change',hush);}}(window,document);";
