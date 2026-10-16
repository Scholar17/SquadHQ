import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/venue/domain/location_input.dart';
import 'package:squad_hq/features/venue/domain/maps_link.dart';

void main() {
  group('MapsLink.parse', () {
    test('share links and google.com/maps links are accepted', () {
      expect(MapsLink.parse('https://maps.app.goo.gl/AbC123xyz'), isNotNull);
      expect(MapsLink.parse('maps.app.goo.gl/AbC123xyz'), isNotNull, reason: 'https:// is optional');
      expect(MapsLink.parse('https://goo.gl/maps/AbC123'), isNotNull);
      expect(MapsLink.parse('https://www.google.com/maps/place/Arena+5/@13.75,100.56,17z'), isNotNull);
      expect(MapsLink.parse('https://maps.google.com/?q=13.75,100.56'), isNotNull);
      expect(MapsLink.parse('  https://maps.app.goo.gl/AbC123xyz  '), isNotNull);
    });

    test('anything else is refused', () {
      expect(MapsLink.parse(''), isNull);
      expect(MapsLink.parse('Arena 5 Rama 9'), isNull);
      expect(MapsLink.parse('https://example.com/maps'), isNull);
      expect(MapsLink.parse('https://www.google.com/search?q=arena'), isNull);
      expect(MapsLink.parse('https://goo.gl/AbC123'), isNull);
    });
  });

  group('MapsLink.coordinates', () {
    ({double latitude, double longitude})? coordinates(String link) =>
        MapsLink.coordinates(MapsLink.parse(link)!);

    test("a place's own pin wins over the map's centre", () {
      expect(
        coordinates(
          'https://www.google.com/maps/place/Arena+5/@13.7500,100.5600,17z/'
          'data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d13.7563!4d100.5018',
        ),
        (latitude: 13.7563, longitude: 100.5018),
      );
    });

    test("the map's centre, or a q= query", () {
      expect(
        coordinates('https://www.google.com/maps/@13.75,100.56,15z'),
        (latitude: 13.75, longitude: 100.56),
      );
      expect(
        coordinates('https://maps.google.com/?q=16.8409,96.1735'),
        (latitude: 16.8409, longitude: 96.1735),
      );
    });

    test('share links carry none', () {
      expect(coordinates('https://maps.app.goo.gl/AbC123xyz'), isNull);
    });
  });

  test('short links are told apart from full ones', () {
    expect(MapsLink.isShortLink(MapsLink.parse('https://maps.app.goo.gl/AbC123xyz')!), isTrue);
    expect(MapsLink.isShortLink(MapsLink.parse('https://goo.gl/maps/AbC123')!), isTrue);
    expect(MapsLink.isShortLink(MapsLink.parse('https://www.google.com/maps/@13.75,100.56,15z')!), isFalse);
  });

  group('LocationInput', () {
    test('a pasted pair, as Google Maps copies it', () {
      expect(LocationInput.pair('13.7563, 100.5018'), (latitude: 13.7563, longitude: 100.5018));
      expect(LocationInput.pair(' 13.7563 100.5018 '), (latitude: 13.7563, longitude: 100.5018));
      expect(LocationInput.pair('-33.86,151.2'), (latitude: -33.86, longitude: 151.2));
      expect(LocationInput.pair('13.7563'), isNull);
      expect(LocationInput.pair('95, 100'), isNull);
    });

    test('each number in its range', () {
      expect(LocationInput.latitude('13.75'), 13.75);
      expect(LocationInput.latitude('-90'), -90);
      expect(LocationInput.latitude('91'), isNull);
      expect(LocationInput.longitude('180'), 180);
      expect(LocationInput.longitude('180.1'), isNull);
      expect(LocationInput.longitude('abc'), isNull);
    });

    test('shown with up to 6 decimals, no trailing zeros', () {
      expect(LocationInput.format(13.7303951), '13.730395');
      expect(LocationInput.format(13.75), '13.75');
      expect(LocationInput.format(100), '100');
    });
  });
}
