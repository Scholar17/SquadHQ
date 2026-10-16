/// Google Maps links pasted for a venue: is it one, and where does it
/// point (when the link says).
abstract final class MapsLink {
  /// A Google Maps link: a share link (maps.app.goo.gl/…) or a
  /// google.com/maps one. Typing "https://" is optional.
  static Uri? parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.contains(' ')) return null;
    final uri = Uri.tryParse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
    if (uri == null || !uri.isScheme('https') && !uri.isScheme('http')) return null;
    final host = uri.host.toLowerCase();
    final isShare = isShortLink(uri);
    final isGoogleMaps = (host.startsWith('maps.google.') ||
            host.startsWith('google.') ||
            host.startsWith('www.google.')) &&
        (uri.path.startsWith('/maps') || host.startsWith('maps.'));
    if (!isShare && !isGoogleMaps) return null;
    return uri;
  }

  /// A share link (maps.app.goo.gl/…): it carries no coordinates itself,
  /// only where it forwards to does.
  static bool isShortLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'maps.app.goo.gl' || (host == 'goo.gl' && uri.path.startsWith('/maps'));
  }

  /// The place's coordinates, when the link carries them: a place's own
  /// pin (!3d…!4d…), the map's centre (@lat,lng) or a query (q=lat,lng).
  /// Share links (maps.app.goo.gl) don't — null.
  static ({double latitude, double longitude})? coordinates(Uri uri) {
    final text = Uri.decodeFull(uri.toString());
    final patterns = [
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
      RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
      RegExp(r'[?&](?:q|query|ll|destination)=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final latitude = double.parse(match.group(1)!);
      final longitude = double.parse(match.group(2)!);
      if (latitude.abs() <= 90 && longitude.abs() <= 180) {
        return (latitude: latitude, longitude: longitude);
      }
    }
    return null;
  }
}
