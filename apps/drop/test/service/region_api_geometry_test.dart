import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:drop/service/RegionApi.dart';

void main() {
  const square = <LatLng>[
    LatLng(0, 0),
    LatLng(0, 0.01),
    LatLng(0.01, 0.01),
    LatLng(0.01, 0),
    LatLng(0, 0),
  ];

  group('Mapbox GeoJSON region geometry helpers', () {
    test('finds a point inside a service polygon', () {
      expect(RegionApi.containingPolygonIndex(const LatLng(0.005, 0.005), [square]), 0);
    });

    test('returns null for a point outside configured polygons', () {
      expect(RegionApi.containingPolygonIndex(const LatLng(0.02, 0.02), [square]), isNull);
    });

    test('identifies a point close to a polygon edge', () {
      expect(RegionApi.isNearBoundary(const LatLng(0.005, 0.0005), [square], withinMeters: 100), isTrue);
    });

    test('does not classify a distant point as near a polygon edge', () {
      expect(RegionApi.isNearBoundary(const LatLng(0.005, 0.02), [square], withinMeters: 100), isFalse);
    });

    test('uses stable first-match ordering for overlapping polygons', () {
      expect(RegionApi.containingPolygonIndex(const LatLng(0.005, 0.005), [square, square]), 0);
    });
  });
}
