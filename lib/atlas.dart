import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'art.dart';

class Atlas {
  Atlas(this._frames);

  final Map<String, ui.Image> _frames;

  ui.Image operator [](String key) => _frames[key]!;

  static Future<Atlas> load() async {
    final entries = await Future.wait(
      Art.world.map((path) async => MapEntry(path, await _decode(path))),
    );
    return Atlas(Map<String, ui.Image>.fromEntries(entries));
  }

  static Future<ui.Image> _decode(String key) async {
    final data = await rootBundle.load(key);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}
