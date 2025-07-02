import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
<<<<<<< HEAD
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../menu/menu_page.dart';
=======
import 'package:kupcar/driver/BookingDetailPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// import '../menu/menu_page.dart';
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
import '../utils/simple_translations.dart';
import '../config/config.dart';

class BookingConfirmPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingConfirmPage({Key? key, required this.booking}) : super(key: key);

  @override
  State<BookingConfirmPage> createState() => _BookingConfirmPageState();
}

class _BookingConfirmPageState extends State<BookingConfirmPage> {
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

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

<<<<<<< HEAD
=======
  // ignore: unused_element
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
  Future<void> _openMaps(double lat, double lon) async {
    final googleUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

<<<<<<< HEAD
=======
  Widget _driverRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

<<<<<<< HEAD
    final pickupLat = double.parse(booking['pickup_lat']);
    final pickupLon = double.parse(booking['pickup_lon']);
    final dropoffLat = double.parse(booking['dropoff_lat']);
    final dropoffLon = double.parse(booking['dropoff_lon']);
=======
    final pickupLat = double.parse(booking['pickup_lat'].toString());
    final pickupLon = double.parse(booking['pickup_lon'].toString());
    final dropoffLat = double.parse(booking['dropoff_lat'].toString());
    final dropoffLon = double.parse(booking['dropoff_lon'].toString());
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95

    final price = booking['payment_price'] ?? 0;
    final suggestePrice = booking['suggeste_price'] ?? 0;

<<<<<<< HEAD
    double distance = 0;
    if (booking['distance'] != null && booking['distance'] > 0) {
      distance = booking['distance'].toDouble();
    } else {
      distance = calculateDistance(
        pickupLat,
        pickupLon,
        dropoffLat,
        dropoffLon,
      );
    }
=======
    double distance = booking['distance'] != null && booking['distance'] > 0
        ? booking['distance'].toDouble()
        : calculateDistance(pickupLat, pickupLon, dropoffLat, dropoffLon);
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95

    final formattedPrice = NumberFormat('#,###').format(price);
    final formattedSuggestPrice = NumberFormat('#,###').format(suggestePrice);
    final formattedDistance = "${distance.toStringAsFixed(2)} km";

    final bookingStatus = (booking['book_status'] ?? '')
        .toString()
        .toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCodes, 'booking_confirmation')),
        backgroundColor: Colors.blue,
      ),
<<<<<<< HEAD
      body: Column(
        children: [
          Container(
            height: 300,
            margin: const EdgeInsets.all(16),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(pickupLat, pickupLon),
                      zoom: 13,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: LatLng(pickupLat, pickupLon),
                        infoWindow: InfoWindow(
                          title: SimpleTranslations.get(
                            langCodes,
                            'pickup_location',
                          ),
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                      ),
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: LatLng(dropoffLat, dropoffLon),
                        infoWindow: InfoWindow(
                          title: SimpleTranslations.get(
                            langCodes,
                            'dropoff_location',
                          ),
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openMaps(pickupLat, pickupLon),
                      splashColor: Colors.black26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoColumn(
                    icon: Icons.payments,
                    label: SimpleTranslations.get(langCodes, 'price'),
                    value: "₭ $formattedPrice",
                    color: Colors.blue,
                  ),
                  _InfoColumn(
                    icon: Icons.place,
                    label: SimpleTranslations.get(langCodes, 'distance'),
                    value: formattedDistance,
                    color: Colors.green,
=======
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              margin: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
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
                        title: SimpleTranslations.get(
                          langCodes,
                          'pickup_location',
                        ),
                      ),
                    ),
                    Marker(
                      markerId: const MarkerId('dropoff'),
                      position: LatLng(dropoffLat, dropoffLon),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                      infoWindow: InfoWindow(
                        title: SimpleTranslations.get(
                          langCodes,
                          'dropoff_location',
                        ),
                      ),
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoColumn(
                      icon: Icons.payments,
                      label: SimpleTranslations.get(langCodes, 'price'),
                      value: "₭ $formattedPrice",
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
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
                  ),
                ],
              ),
            ),
<<<<<<< HEAD
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Text(
              "${SimpleTranslations.get(langCodes, 'suggested_price')}: ₭ $formattedSuggestPrice",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          bookingStatus == 'booking'
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final driverId = prefs.getString('user') ?? '';
                        final token = prefs.getString('access_token') ?? '';
                        final role = prefs.getString('role') ?? 'customer';

                        final bookingId = booking['book_id'];
                        final url = AppConfig.api(
                          '/api/book/update/$bookingId',
                        );

                        final response = await http.put(
                          url,
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode({
                            'driver_id': driverId,
                            'book_status': 'Pick up',
                          }),
                        );

                        if (!mounted) return;

                        if (response.statusCode == 200 ||
                            response.statusCode == 201) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenuPage(role: role),
                            ),
                            (route) => false,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to confirm booking (${response.statusCode})',
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        SimpleTranslations.get(langCodes, 'confirm_booking'),
=======
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${SimpleTranslations.get(langCodes, 'suggested_price')} ₭ $formattedSuggestPrice",
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
<<<<<<< HEAD
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ],
=======
                      const SizedBox(height: 8),
                      _driverRow(
                        Icons.person,
                        "${SimpleTranslations.get(langCodes, 'name')}: ${booking['driver_name'] ?? '-'}",
                      ),
                      _driverRow(
                        Icons.phone,
                        "${SimpleTranslations.get(langCodes, 'phone')}: ${booking['driver_phone'] ?? '-'}",
                      ),
                      _driverRow(
                        Icons.directions_car,
                        "${SimpleTranslations.get(langCodes, 'license_plate')}: ${booking['license_plate'] ?? '-'}",
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (bookingStatus == 'booking')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      SimpleTranslations.get(langCodes, 'confirm_booking'),
                      style: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final driverId = prefs.getString('user') ?? '';
                      final token = prefs.getString('access_token') ?? '';
                      // ignore: unused_local_variable
                      final role = prefs.getString('role') ?? 'customer';
                      final bookingId = booking['book_id'];
                      final carId = booking['car_id'];

                      final url = AppConfig.api('/api/book/update/$bookingId');
                      final response = await http.put(
                        url,
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: jsonEncode({
                          'driver_id': driverId,
                          'car_id': carId,
                          'book_status': 'Pick up',
                        }),
                      );

                      if (!mounted) return;
                      if (response.statusCode == 200 ||
                          response.statusCode == 201) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingDetailPage(booking: booking),
                          ),
                          (route) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed (${response.statusCode})'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
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
        ),
      ],
    );
  }
}
