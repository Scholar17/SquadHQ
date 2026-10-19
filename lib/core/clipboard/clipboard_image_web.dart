import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Safari (iOS 13.4+), Chrome and Edge can read a copied image.
bool get canPasteImage => true;

/// The copied photo as a JPEG, fitted within [maxWidth]×[maxHeight] at
/// [quality] (0–100), or null if nothing copied is a photo — or the
/// browser said no (Safari shows its own "Paste" bubble first).
///
/// Call it straight from a tap, before any await: browsers only read the
/// clipboard during a user's gesture.
Future<Uint8List?> pasteClipboardImage({
  required int maxWidth,
  int? maxHeight,
  required int quality,
}) async {
  final List<web.ClipboardItem> items;
  try {
    items = (await web.window.navigator.clipboard.read().toDart).toDart;
  } catch (_) {
    return null;
  }
  for (final item in items) {
    final types = item.types.toDart.map((type) => type.toDart);
    final type = types.where((type) => type.startsWith('image/')).firstOrNull;
    if (type == null) continue;
    try {
      final blob = await item.getType(type).toDart;
      return await _shrink(blob, maxWidth: maxWidth, maxHeight: maxHeight, quality: quality);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Redraws [blob] on a canvas — at most [maxWidth]×[maxHeight] — and
/// encodes it as a JPEG, as image_picker does for a picked photo.
Future<Uint8List?> _shrink(
  web.Blob blob, {
  required int maxWidth,
  int? maxHeight,
  required int quality,
}) async {
  final bitmap = await web.window.createImageBitmap(blob).toDart;
  final scale = math.min(
    1.0,
    math.min(
      maxWidth / bitmap.width,
      maxHeight == null ? double.infinity : maxHeight / bitmap.height,
    ),
  );
  final width = math.max(1, (bitmap.width * scale).round());
  final height = math.max(1, (bitmap.height * scale).round());
  final canvas = web.HTMLCanvasElement()
    ..width = width
    ..height = height;
  final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
  // A transparent screenshot would turn black as a JPEG.
  context
    ..fillStyle = '#ffffff'.toJS
    ..fillRect(0, 0, width, height)
    ..drawImage(bitmap, 0, 0, width, height);
  bitmap.close();

  final jpeg = Completer<web.Blob?>();
  canvas.toBlob(((web.Blob? blob) => jpeg.complete(blob)).toJS, 'image/jpeg', (quality / 100).toJS);
  final encoded = await jpeg.future;
  if (encoded == null) return null;
  return (await encoded.arrayBuffer().toDart).toDart.asUint8List();
}
