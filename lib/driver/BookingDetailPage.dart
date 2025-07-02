import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../menu/menu_page.dart';
import '../utils/simple_translations.dart';

class BookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailPage({Key? key, required this.booking}) : super(key: key);

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  String langCodes = 'en';

  @override
  void initState() {
    super.initState();
    getLanguage();
  }

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCodes = prefs.getString('languageCode') ?? 'en';
    });
  }

  Future<void> _openMaps(double lat, double lon, BuildContext context) async {
    final Uri googleUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );

    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    final pickupLat = double.tryParse(booking['pickup_lat'].toString()) ?? 0;
    final pickupLon = double.tryParse(booking['pickup_lon'].toString()) ?? 0;
    final dropoffLat = double.tryParse(booking['dropoff_lat'].toString()) ?? 0;
    final dropoffLon = double.tryParse(booking['dropoff_lon'].toString()) ?? 0;

    final formattedPrice = (booking['payment_price'] != null)
        ? "₭ ${booking['payment_price']}"
        : "-";

    final formattedDistance = (booking['distance'] != null)
        ? "${(booking['distance'] as num).toStringAsFixed(2)} km"
        : "-";

    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCodes, 'booking_details')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            final role = prefs.getString('role') ?? 'customer';

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => MenuPage(role: role)),
              (route) => false,
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🗺 Map at Top
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 250,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(pickupLat, pickupLon),
                      zoom: 13,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: LatLng(pickupLat, pickupLon),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                        infoWindow: InfoWindow(
                          title: SimpleTranslations.get(langCodes, 'pickup'),
                        ),
                      ),
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: LatLng(dropoffLat, dropoffLon),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                        infoWindow: InfoWindow(
                          title: SimpleTranslations.get(langCodes, 'dropoff'),
                        ),
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ),
            ),

            // 🚗 Pickup & Dropoff Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openMaps(pickupLat, pickupLon, context),
                      icon: const Icon(Icons.location_on),
                      label: Text(SimpleTranslations.get(langCodes, 'pickup')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _openMaps(dropoffLat, dropoffLon, context),
                      icon: const Icon(Icons.flag),
                      label: Text(SimpleTranslations.get(langCodes, 'dropoff')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 📄 Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoColumn(
                          icon: Icons.confirmation_num,
                          label: SimpleTranslations.get(
                            langCodes,
                            'booking_id',
                          ),
                          value: booking['book_id']?.toString() ?? '-',
                          color: Colors.deepPurple,
                        ),
                      ),
                      Expanded(
                        child: _InfoColumn(
                          icon: Icons.person,
                          label: SimpleTranslations.get(langCodes, 'passenger'),
                          value:
                              booking['passenger_name'] ??
                              booking['passenger_id']?.toString() ??
                              '-',
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoColumn(
                          icon: Icons.directions_car,
                          label: SimpleTranslations.get(langCodes, 'driver'),
                          value: booking['driver_name'] ?? '-',
                          color: Colors.orange,
                        ),
                      ),
                      Expanded(
                        child: _InfoColumn(
                          icon: Icons.info,
                          label: SimpleTranslations.get(langCodes, 'status'),
                          value: booking['book_status'] ?? '-',
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoColumn(
                          icon: Icons.payments,
                          label: SimpleTranslations.get(langCodes, 'price'),
                          value: formattedPrice,
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _InfoColumn(
                          icon: Icons.place,
                          label: SimpleTranslations.get(langCodes, 'distance'),
                          value: formattedDistance,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoColumn({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
