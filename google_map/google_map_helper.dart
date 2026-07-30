import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapHelper {
  GoogleMapHelper._();

  static const String _googleApiKey =
      'your_google_api_key_here'; // Replace with your Google API Key

  //? how to use it
  // in google map widget
  // GoogleMap(
  // ...
  // polylines: Set<Polyline>.of(polylines.values),
  // ),
  /// Retrieves polyline between source and destination locations.
  static Future<Map<PolylineId, Polyline>> getPolyline(
    LatLng sourceLocation,
    LatLng destination,
    Color polylineColor,
  ) async {
    List<LatLng> polylineCoordinates = [];
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      _googleApiKey,
      PointLatLng(sourceLocation.latitude, sourceLocation.longitude),
      PointLatLng(destination.latitude, destination.longitude),
    );
    if (result.points.isNotEmpty) {
      polylineCoordinates = result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    }
    return _addPolyLine(polylineCoordinates, polylineColor);
  }

  /// Generates camera position for displaying location image preview.
  static CameraPosition generateLocationImagePreview({
    required double latitude,
    required double longitude,
  }) {
    return CameraPosition(
      target: LatLng(latitude, longitude),
      zoom: 16,
    );
  }

  /// Generates marker for displaying location marker preview.
  static Future<Marker> generateLocationMarkerPreview({
    required double latitude,
    required double longitude,
    required String markerAssetPath,
    required int markerWidth,
  }) async {
    final Uint8List markerIcon = await getBytesFromAsset(
      path: markerAssetPath,
      width: markerWidth,
    );
    return Marker(
      markerId: const MarkerId('Marker'),
      position: LatLng(latitude, longitude),
      icon: BitmapDescriptor.fromBytes(markerIcon),
    );
  }

  // set custom marker with width
  static Future<Uint8List> getBytesFromAsset({
    required String path,
    required int width,
  }) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  // set custom marker without width
  BitmapDescriptor setCustomMarkerIcon(String path) {
    BitmapDescriptor sourceIcon = BitmapDescriptor.defaultMarker;

    BitmapDescriptor.fromAssetImage(ImageConfiguration.empty, path)
        .then((icon) => sourceIcon = icon);

    return sourceIcon;
  }

  static Map<PolylineId, Polyline> _addPolyLine(
    List<LatLng> polylineCoordinates,
    Color polylineColor,
  ) {
    const PolylineId id = PolylineId("poly");
    final Polyline polyline = Polyline(
      polylineId: id,
      color: polylineColor,
      points: polylineCoordinates,
    );
    return {id: polyline};
  }
}
