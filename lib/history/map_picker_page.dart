import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerPage extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPickerPage({Key? key, this.initialPosition}) : super(key: key);

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? pickedPosition;
  bool locationPermissionGranted = false;
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    pickedPosition = widget.initialPosition;
    _checkPermissionAndFetchLocation();
  }

  Future<void> _checkPermissionAndFetchLocation() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }

    if (status.isGranted) {
      locationPermissionGranted = true;

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        currentLocation = LatLng(pos.latitude, pos.longitude);

        if (pickedPosition == null) {
          pickedPosition = currentLocation;
        }
      } catch (e) {
        print('Error getting location: $e');
      }
    } else {
      locationPermissionGranted = false;
    }

    // ✅ Only update UI if widget is still active
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final initialCameraPos = CameraPosition(
      target: pickedPosition ?? currentLocation ?? const LatLng(20.0, 100.0),
      zoom: 14,
    );

    Set<Marker> markers = {};
    if (pickedPosition != null) {
      markers.add(
        Marker(markerId: const MarkerId('picked'), position: pickedPosition!),
      );
    }
    if (currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          TextButton(
            onPressed: pickedPosition == null
                ? null
                : () => Navigator.of(context).pop(pickedPosition),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: initialCameraPos,
        markers: markers,
        onTap: (pos) {
          setState(() {
            pickedPosition = pos;
          });
        },
        myLocationEnabled: locationPermissionGranted,
        myLocationButtonEnabled: locationPermissionGranted,
      ),
    );
  }
}
