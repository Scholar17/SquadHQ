import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('squad_hq/clipboard_image');

/// Only iOS answers the channel (AppDelegate.swift).
bool get canPasteImage => defaultTargetPlatform == TargetPlatform.iOS;

/// The copied photo as a JPEG, fitted within [maxWidth]×[maxHeight] at
/// [quality] (0–100), or null if nothing copied is a photo. iOS may ask
/// to "Allow Paste" first; saying no also gives null.
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
