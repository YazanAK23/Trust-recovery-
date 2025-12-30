import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';

class MapWithMarkers extends StatefulWidget {
  final List<dynamic> merchants;

  MapWithMarkers({super.key, required this.merchants});

  @override
  _MapWithMarkersState createState() => _MapWithMarkersState();
}

class _MapWithMarkersState extends State<MapWithMarkers> {
  GoogleMapController? mapController;

  @override
  void initState() {
    super.initState();
    // Ensure widget is built before accessing merchants
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.merchants_location),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        onMapCreated: _onMapCreated,
        markers: _createMarkers(),
        initialCameraPosition: CameraPosition(
          target: LatLng(
            widget.merchants.first['coordinates']['y'],
            widget.merchants.first['coordinates']['x'],
          ),
          zoom: 10.0,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomGesturesEnabled: true,
        zoomControlsEnabled: false,
        compassEnabled: true,
        mapToolbarEnabled: false,
        indoorViewEnabled: true,
        trafficEnabled: false,
        buildingsEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        minMaxZoomPreference: MinMaxZoomPreference(2, 20),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    // Force refresh for iOS
    await Future.delayed(Duration(milliseconds: 300));
    if (mounted) {
      setState(() {});
    }
  }

  Set<Marker> _createMarkers() {
    return widget.merchants
        .where((merchant) => merchant['coordinates'] != null)
        .map<Marker>((merchant) {
      return Marker(
        markerId: MarkerId(merchant['id'].toString()),
        position: LatLng(
          merchant['coordinates']['y'],
          merchant['coordinates']['x'],
        ),
        infoWindow: InfoWindow(
          title: merchant['name'],
          snippet: merchant['address'],
        ),
      );
    }).toSet();
  }
}
