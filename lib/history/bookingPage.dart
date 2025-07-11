import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/history/bookingConfirmedPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_picker_page.dart';
import '../utils/simple_translations.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({Key? key}) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final pickupCtrl = TextEditingController();
  final dropoffCtrl = TextEditingController();
  final customerFareCtrl = TextEditingController();
  final suggestedFareCtrl = TextEditingController();

  LatLng? pickupLatLng;
  LatLng? dropoffLatLng;

  List<dynamic> _CarTypeId = [];
  int? _selectedCarTypeId;
  String langCode = 'en';

  @override
  void initState() {
    super.initState();
    _fetchCarType();
    _getLanguage();
  }

  @override
  void dispose() {
    pickupCtrl.dispose();
    dropoffCtrl.dispose();
    customerFareCtrl.dispose();
    suggestedFareCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    langCode = prefs.getString('langCode') ?? 'en';
    print('[Language] Loaded language code: $langCode');
    setState(() {});
  }

  Future<void> _fetchCarType() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/user/carType');

    print('[CarType] Fetching car types from $url');
    print('[CarType] Using JWT Token: $token');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      print('[CarType] Response status: ${response.statusCode}');
      print('[CarType] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _CarTypeId = data['data'] ?? [];
        });
        print('[CarType] Loaded ${_CarTypeId.length} car types');
      } else {
        _showError('Failed to load car types: ${response.statusCode}');
      }
    } catch (e) {
      print('[CarType] Exception: $e');
      _showError('Error loading car types: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    print('[Error] $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Future<void> _pickLocation(bool isPickup) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initialPosition: isPickup ? pickupLatLng : dropoffLatLng,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isPickup) {
          pickupLatLng = result;
          pickupCtrl.text =
              '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
          print('[Location] Pickup set to: ${pickupCtrl.text}');
        } else {
          dropoffLatLng = result;
          dropoffCtrl.text =
              '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
          print('[Location] Dropoff set to: ${dropoffCtrl.text}');
        }
        _calculateSuggestedFare();
      });
    }
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  double _calculateDistanceInKm(LatLng a, LatLng b) {
    const double R = 6371;
    final double dLat = _deg2rad(b.latitude - a.latitude);
    final double dLon = _deg2rad(b.longitude - a.longitude);
    final double lat1 = _deg2rad(a.latitude);
    final double lat2 = _deg2rad(b.latitude);

    final double aVal =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    final distance = R * c;
    print('[Distance] Calculated distance: ${distance.toStringAsFixed(3)} km');
    return distance;
  }

  void _calculateSuggestedFare() {
    if (pickupLatLng == null ||
        dropoffLatLng == null ||
        _selectedCarTypeId == null) {
      print('[Fare] Cannot calculate fare: Missing data');
      return;
    }

    final carType = _CarTypeId.firstWhere(
      (e) => e['car_type_id'] == _selectedCarTypeId,
      orElse: () => null,
    );

    if (carType != null && carType['index_price'] != null) {
      final distance = _calculateDistanceInKm(pickupLatLng!, dropoffLatLng!);
      final pricePerKm = carType['index_price'];
      double total = distance * pricePerKm;
      int roundedTotal = ((total + 499) ~/ 1000) * 1000;
      suggestedFareCtrl.text = roundedTotal.toString();
      print('[Fare] Calculated suggested fare: $roundedTotal LAK');
    } else {
      print('[Fare] Car type or price not found.');
    }
  }

  Future<void> _bookCar() async {
    if (pickupLatLng == null ||
        dropoffLatLng == null ||
        _selectedCarTypeId == null ||
        customerFareCtrl.text.isEmpty) {
      _showError('Please complete all fields before booking.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final passengerId = prefs.getString('user');

    print('Debug token9999999999999: $token');
    print('Debug user_id: $passengerId');

    if (token == null || passengerId == null) {
      _showError("User not authenticated.");
      return;
    }

    final body = {
      "passenger_id": passengerId,
      "pickup_lat": pickupLatLng!.latitude,
      "pickup_lon": pickupLatLng!.longitude,
      "dropoff_lat": dropoffLatLng!.latitude,
      "dropoff_lon": dropoffLatLng!.longitude,
      "prickup": pickupCtrl.text,
      "dropoff": dropoffCtrl.text,
      "start_time": DateTime.now().toIso8601String(),
      "end_time": DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      "suggeste_price": int.tryParse(suggestedFareCtrl.text) ?? 0,
      "payment_price": int.tryParse(customerFareCtrl.text) ?? 0,
      "book_status": "Booking",
      "review": "",
    };

    final url = AppConfig.api('/api/book/bookAdd');

    print('🔑 JWT Token: $token');
    print('📦 Booking request body: ${jsonEncode(body)}');
    print('🔗 Booking API URL: $url');

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        // final responseBody = jsonDecode(res.body);
        // final bookingId = responseBody['data']['book_id'] ?? 0;

        // if (!mounted) return;
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => BookingConfirmedPage(bookingId: bookingId),
        //   ),
        // );

        final responseBody = jsonDecode(res.body);
        final data = responseBody['data'];

        if (data != null && data['book_id'] != null) {
          final bookingId = data['book_id'];

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BookingConfirmedPage(bookingId: bookingId),
            ),
          );
        } else {
          _showError("❌ Booking failed: Missing booking ID in response.");
        }
      } else {
        _showError("❌ Booking failed: ${res.statusCode}");
      }
      print('🧾 Full response: ${res.body}');
    } catch (e) {
      _showError("API error: $e");
    }
  }

  Widget _buildLocationField(
    String label,
    TextEditingController ctrl,
    bool isPickup,
  ) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.map),
      ),
      onTap: () => _pickLocation(isPickup),
    );
  }

  Widget _buildSuggestedFare() {
    return TextField(
      controller: suggestedFareCtrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: SimpleTranslations.get(langCode, 'Suggested'),
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.monetization_on_outlined),
      ),
    );
  }

  Widget _buildCustomerFareInput() {
    return TextField(
      controller: customerFareCtrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: SimpleTranslations.get(langCode, 'FareOffer'),
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.money),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildLocationField(
              SimpleTranslations.get(langCode, 'PickupLocation'),
              pickupCtrl,
              true,
            ),
            const SizedBox(height: 12),
            _buildLocationField(
              SimpleTranslations.get(langCode, 'DropoffLocation'),
              dropoffCtrl,
              false,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedCarTypeId,
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'car_type'),
                border: const OutlineInputBorder(),
              ),
              items: _CarTypeId.map<DropdownMenuItem<int>>((type) {
                return DropdownMenuItem<int>(
                  value: type['car_type_id'],
                  child: Text(type['car_type_la']),
                );
              }).toList(),
              onChanged: (val) => setState(() {
                _selectedCarTypeId = val;
                _calculateSuggestedFare();
              }),
            ),
            const SizedBox(height: 16),
            _buildSuggestedFare(),
            const SizedBox(height: 12),
            _buildCustomerFareInput(),
            const SizedBox(height: 24),
            // _buildSaveTestTokenButton(),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _bookCar,
              child: Text(SimpleTranslations.get(langCode, 'BookNow')),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
