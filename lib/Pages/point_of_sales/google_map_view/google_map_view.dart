import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../Constants/constants.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';

class GoogleMapView extends StatefulWidget {
  final double latt;
  final double long;

  GoogleMapView({required this.latt, required this.long});

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> {
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: MAIN_COLOR,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back,
              color: Colors.white,
            )),
        title: Text(AppLocalizations.of(context)!.merchants_location),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        onMapCreated: (GoogleMapController controller) async {
          _controller = controller;
          await Future.delayed(Duration(milliseconds: 300));
          if (mounted) setState(() {});
        },
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.latt, widget.long),
          zoom: 15.0,
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
        markers: {
          Marker(
            markerId: MarkerId("23"),
            position: LatLng(widget.latt, widget.long),
            infoWindow: InfoWindow(title: "Your Marker"),
          ),
        },
      ),
    );
  }
}
