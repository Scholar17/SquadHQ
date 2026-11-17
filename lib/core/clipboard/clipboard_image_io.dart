import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('squad_hq/clipboard_image');

/// iOS (AppDelegate.swift) and Android (MainActivity.kt) answer the
/// channel.
bool get canPasteImage =>
    defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

/// The copied photo as a JPEG, fitted within [maxWidth]×[maxHeight] at
/// [quality] (0–100), or null if nothing copied is a photo. iOS may ask
/// to "Allow Paste" first; saying no also gives null. Android shows a
/// "pasted from clipboard" notice.
Future<Uint8List?> pasteClipboardImage({
  required int maxWidth,
  int? maxHeight,
  required int quality,
}) async {
  if (!canPasteImage) return null;
  return _channel.invokeMethod<Uint8List>('readImage', {
    'maxWidth': maxWidth,
    'maxHeight': maxHeight,
    'quality': quality,
  });
}
