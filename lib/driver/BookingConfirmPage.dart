import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sabaicub/driver/BookingDetailPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/simple_translations.dart';
import '../config/config.dart';

class BookingConfirmPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingConfirmPage({Key? key, required this.booking}) : super(key: key);

  @override
  State<BookingConfirmPage> createState() => _BookingConfirmPageState();
}

class _BookingConfirmPageState extends State<BookingConfirmPage>
    with TickerProviderStateMixin {
  String langCodes = 'en';
  GoogleMapController? _mapController;
  AnimationController? _countdownController;
  AnimationController? _pulseController;
  Timer? _countdownTimer;
  Timer? _bookingStatusTimer;
  int _countdownSeconds = 300;
  int _totalCountdownSeconds = 300;
  bool _isConfirming = false;
  bool _isExpired = false;
  Position? _currentPosition;

  // Map markers and polylines
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    getLanguage();
    _setupAnimations();
    _setupCountdown();
    _setupMarkersAndRoute();
    _getCurrentLocation();
    _startBookingStatusPolling();
  }

  @override
  void dispose() {
    _countdownController?.dispose();
    _pulseController?.dispose();
    _countdownTimer?.cancel();
    _bookingStatusTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController!.repeat();
  }

  void _setupCountdown() {
    final booking = widget.booking;
    final requestTimeStr = booking['request_time'];

    if (requestTimeStr != null && requestTimeStr.toString().isNotEmpty) {
      try {
        DateTime requestTime;
        if (requestTimeStr is String) {
          try {
            requestTime = DateTime.parse(requestTimeStr);
          } catch (e) {
            final timestamp = int.tryParse(requestTimeStr);
            if (timestamp != null) {
              requestTime = DateTime.fromMillisecondsSinceEpoch(
                timestamp * 1000,
              );
            } else {
              requestTime = DateTime.now();
            }
          }
        } else if (requestTimeStr is int) {
          requestTime = DateTime.fromMillisecondsSinceEpoch(
            requestTimeStr * 1000,
          );
        } else {
          requestTime = DateTime.now();
        }

        final now = DateTime.now();
        final elapsedSeconds = now.difference(requestTime).inSeconds;
        _totalCountdownSeconds = 300;
        _countdownSeconds = _totalCountdownSeconds - elapsedSeconds;

        if (_countdownSeconds <= 0) {
          _countdownSeconds = 0;
          _isExpired = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTimeoutDialog();
          });
          return;
        }
      } catch (e) {
        print('Error parsing request_time: $e');
        _totalCountdownSeconds = 300;
        _countdownSeconds = 300;
      }
    } else {
      _totalCountdownSeconds = 300;
      _countdownSeconds = 300;
    }

    _countdownController = AnimationController(
      duration: Duration(seconds: _countdownSeconds),
      vsync: this,
    );

    _startCountdown();
  }

  void _startCountdown() {
    if (_countdownController != null && !_isExpired) {
      _countdownController!.forward();
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0 && !_isExpired) {
        setState(() {
          _countdownSeconds--;
        });

        // Vibrate when countdown reaches 30 seconds
        if (_countdownSeconds == 30) {
          HapticFeedback.heavyImpact();
        }
      } else {
        timer.cancel();
        if (!_isExpired) {
          _isExpired = true;
          _showTimeoutDialog();
        }
      }
    });
  }

  void _startBookingStatusPolling() {
    _bookingStatusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isExpired) {
        _checkBookingStatus();
      }
    });
  }

  Future<void> _checkBookingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final bookingId = widget.booking['book_id'];

      final url = AppConfig.api('/api/book/status/$bookingId');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final status = data['book_status']?.toString().toLowerCase();

        if (status == 'cancelled' || status == 'expired') {
          _bookingStatusTimer?.cancel();
          _showBookingCancelledDialog();
        }
      }
    } catch (e) {
      print('Error checking booking status: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        _updateDriverLocationMarker();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _updateDriverLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: SimpleTranslations.get(langCodes, 'your_location'),
            ),
          ),
        );
      });
      // Re-fit the map to include driver location
      _fitMarkersInView();
    }
  }

  void _showTimeoutDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.timer_off, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  SimpleTranslations.get(langCodes, 'booking_timeout'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            SimpleTranslations.get(langCodes, 'booking_timeout_message'),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                SimpleTranslations.get(langCodes, 'ok'),
                style: const TextStyle(color: Colors.black87),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showBookingCancelledDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.cancel, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  SimpleTranslations.get(langCodes, 'booking_cancelled'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            SimpleTranslations.get(langCodes, 'booking_cancelled_message'),
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                SimpleTranslations.get(langCodes, 'ok'),
                style: const TextStyle(color: Colors.black87),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _setupMarkersAndRoute() {
    final booking = widget.booking;
    final pickupLat = double.parse(booking['pickup_lat'].toString());
    final pickupLon = double.parse(booking['pickup_lon'].toString());
    final dropoffLat = double.parse(booking['dropoff_lat'].toString());
    final dropoffLon = double.parse(booking['dropoff_lon'].toString());

    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLat, pickupLon),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: SimpleTranslations.get(langCodes, 'pickup_location'),
          snippet: booking['pickup_address'] ?? '',
        ),
        onTap: () => _openMaps(pickupLat, pickupLon),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(dropoffLat, dropoffLon),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: SimpleTranslations.get(langCodes, 'dropoff_location'),
          snippet: booking['dropoff_address'] ?? '',
        ),
        onTap: () => _openMaps(dropoffLat, dropoffLon),
      ),
    };

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [LatLng(pickupLat, pickupLon), LatLng(dropoffLat, dropoffLon)],
        color: Colors.blue,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      ),
    };
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMarkersInView();
  }

  void _fitMarkersInView() {
    if (_mapController == null || _markers.isEmpty) return;

    final bounds = _calculateBounds();
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _calculateBounds() {
    final booking = widget.booking;
    final pickupLat = double.parse(booking['pickup_lat'].toString());
    final pickupLon = double.parse(booking['pickup_lon'].toString());
    final dropoffLat = double.parse(booking['dropoff_lat'].toString());
    final dropoffLon = double.parse(booking['dropoff_lon'].toString());

    double minLat = min(pickupLat, dropoffLat);
    double maxLat = max(pickupLat, dropoffLat);
    double minLon = min(pickupLon, dropoffLon);
    double maxLon = max(pickupLon, dropoffLon);

    // Include driver location if available
    if (_currentPosition != null) {
      minLat = min(minLat, _currentPosition!.latitude);
      maxLat = max(maxLat, _currentPosition!.latitude);
      minLon = min(minLon, _currentPosition!.longitude);
      maxLon = max(maxLon, _currentPosition!.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  Future<void> _openMaps(double lat, double lon) async {
    final googleUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open Google Maps', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error opening maps', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildCountdownRing() {
    if (_isExpired) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red, width: 6),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '00:00',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              Text(
                SimpleTranslations.get(langCodes, 'expired'),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _totalCountdownSeconds > 0
        ? _countdownSeconds / _totalCountdownSeconds
        : 0.0;
    Color ringColor;

    if (progress > 0.6) {
      ringColor = Colors.green;
    } else if (progress > 0.3) {
      ringColor = Colors.orange;
    } else {
      ringColor = Colors.red;
    }

    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        return Container(
          width: 80 + (progress < 0.3 ? _pulseController!.value * 10 : 0),
          height: 80 + (progress < 0.3 ? _pulseController!.value * 10 : 0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(_countdownSeconds ~/ 60).toString().padLeft(2, '0')}:${(_countdownSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ringColor,
                    ),
                  ),
                  Text(
                    SimpleTranslations.get(langCodes, 'remaining'),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge() {
    final bookingStatus = (widget.booking['book_status'] ?? '')
        .toString()
        .toLowerCase();

    Color badgeColor;
    IconData badgeIcon;
    String statusText;

    switch (bookingStatus) {
      case 'booking':
        badgeColor = Colors.orange;
        badgeIcon = Icons.hourglass_empty;
        statusText = SimpleTranslations.get(langCodes, 'waiting_confirmation');
        break;
      case 'pick up':
        badgeColor = Colors.blue;
        badgeIcon = Icons.directions_car;
        statusText = SimpleTranslations.get(langCodes, 'driver_coming');
        break;
      case 'completed':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle;
        statusText = SimpleTranslations.get(langCodes, 'completed');
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        badgeIcon = Icons.cancel;
        statusText = SimpleTranslations.get(langCodes, 'cancelled');
        break;
      default:
        badgeColor = Colors.grey;
        badgeIcon = Icons.info;
        statusText = bookingStatus;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 16, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showSnackBar('Could not make phone call', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error making phone call', Colors.red);
    }
  }

  Future<void> _confirmBooking() async {
    if (_isConfirming || _isExpired) return;

    setState(() {
      _isConfirming = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final driverIdString = prefs.getString('user') ?? '';
      final token = prefs.getString('access_token') ?? '';
      final bookingId = widget.booking['book_id'];
      final carIdString = widget.booking['car_id'];

      // Convert driver_id and car_id to integers
      final driverId = int.tryParse(driverIdString) ?? 0;
      final carId = int.tryParse(carIdString.toString()) ?? 0;

      // Get current location for driver location fields
      String driverLocation = "";
      String driverLat = "";
      String driverLon = "";

      if (_currentPosition != null) {
        driverLat = _currentPosition!.latitude.toString();
        driverLon = _currentPosition!.longitude.toString();
        driverLocation =
            "${_currentPosition!.latitude}, ${_currentPosition!.longitude}";
      } else {
        // Try to get current location if not available
        try {
          Position? position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          if (position != null) {
            driverLat = position.latitude.toString();
            driverLon = position.longitude.toString();
            driverLocation = "${position.latitude}, ${position.longitude}";
          }
        } catch (e) {
          print('Error getting current location: $e');
          // Use default or fallback location if needed
          driverLat = "0.0";
          driverLon = "0.0";
          driverLocation = "0.0, 0.0";
        }
      }

      final url = AppConfig.api('/api/book/update/$bookingId');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'driver_id': driverId, // Now as integer
          'car_id': carId, // Now as integer
          'book_status': 'Pick up',
          'driver_location': driverLocation, // Format: "lat, lon"
          'driver_lat': driverLat, // As string
          'driver_lon': driverLon, // As string
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        HapticFeedback.lightImpact();
        _showSnackBar('Booking confirmed successfully!', Colors.green);

        // Cancel timers before navigation
        _countdownTimer?.cancel();
        _bookingStatusTimer?.cancel();

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailPage(booking: widget.booking),
            ),
            (route) => false,
          );
        }
      } else {
        _showSnackBar(
          'Failed to confirm booking (${response.statusCode})',
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Network error occurred', Colors.red);
      print('Error confirming booking: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final pickupLat = double.parse(booking['pickup_lat'].toString());
    final pickupLon = double.parse(booking['pickup_lon'].toString());
    final dropoffLat = double.parse(booking['dropoff_lat'].toString());
    final dropoffLon = double.parse(booking['dropoff_lon'].toString());

    final price = booking['payment_price'] ?? 0;
    final suggestePrice = booking['suggeste_price'] ?? 0;

    double distance = booking['distance'] != null && booking['distance'] > 0
        ? booking['distance'].toDouble()
        : calculateDistance(pickupLat, pickupLon, dropoffLat, dropoffLon);

    final formattedPrice = NumberFormat('#,###').format(price);
    final formattedSuggestPrice = NumberFormat('#,###').format(suggestePrice);
    final formattedDistance = "${distance.toStringAsFixed(2)} km";

    final bookingStatus = (booking['book_status'] ?? '')
        .toString()
        .toLowerCase();
    final customerPhone =
        booking['customer_phone']?.toString() ??
        booking['passenger_phone']?.toString() ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCodes, 'booking_confirmation')),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _buildCountdownRing()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: _buildStatusBadge()),
            ),

            // Enhanced Map with route
            Container(
              height: 280,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(pickupLat, pickupLon),
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                  buildingsEnabled: true,
                  mapToolbarEnabled: false,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Enhanced Info Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _EnhancedInfoCard(
                      icon: Icons.payments,
                      label: SimpleTranslations.get(langCodes, 'price'),
                      value: "₭ $formattedPrice",
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EnhancedInfoCard(
                      icon: Icons.place,
                      label: SimpleTranslations.get(langCodes, 'distance'),
                      value: formattedDistance,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Enhanced Driver Info Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.local_taxi,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${SimpleTranslations.get(langCodes, 'suggested_price')} ₭ $formattedSuggestPrice",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[200],
                      ),
                      const SizedBox(height: 16),
                      _driverRow(
                        Icons.person,
                        "${SimpleTranslations.get(langCodes, 'customer_name')}: ${booking['customer_name'] ?? booking['passenger_name'] ?? '-'}",
                      ),
                      _driverRow(
                        Icons.phone,
                        "${SimpleTranslations.get(langCodes, 'phone')}: ${customerPhone.isNotEmpty ? customerPhone : '-'}",
                        onTap: customerPhone.isNotEmpty
                            ? () => _makePhoneCall(customerPhone)
                            : null,
                      ),
                      _driverRow(
                        Icons.directions_car,
                        "${SimpleTranslations.get(langCodes, 'vehicle_type')}: ${booking['vehicle_type'] ?? booking['car_type'] ?? '-'}",
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Enhanced Confirm Button
            if (bookingStatus == 'booking' && !_isExpired)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConfirming
                            ? Colors.grey
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: _isConfirming
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 24),
                      label: Text(
                        _isConfirming
                            ? SimpleTranslations.get(langCodes, 'confirming')
                            : SimpleTranslations.get(
                                langCodes,
                                'confirm_booking',
                              ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _isConfirming ? null : _confirmBooking,
                    ),
                  ),
                ),
              ),

            // Quick Actions Row
            if (bookingStatus == 'booking' && !_isExpired)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                        ),
                        icon: const Icon(Icons.navigation, size: 20),
                        label: Text(
                          SimpleTranslations.get(langCodes, 'navigate_pickup'),
                          style: const TextStyle(fontSize: 14),
                        ),
                        onPressed: () => _openMaps(pickupLat, pickupLon),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (customerPhone.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: Colors.green.withOpacity(0.5),
                            ),
                          ),
                          icon: const Icon(
                            Icons.phone,
                            size: 20,
                            color: Colors.green,
                          ),
                          label: Text(
                            SimpleTranslations.get(langCodes, 'call_customer'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                          onPressed: () => _makePhoneCall(customerPhone),
                        ),
                      ),
                  ],
                ),
              ),

            // Booking Details Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SimpleTranslations.get(langCodes, 'trip_details'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.radio_button_checked,
                        SimpleTranslations.get(langCodes, 'pickup'),
                        booking['pickup_address'] ?? 'N/A',
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.location_on,
                        SimpleTranslations.get(langCodes, 'dropoff'),
                        booking['dropoff_address'] ?? 'N/A',
                        Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.access_time,
                        SimpleTranslations.get(langCodes, 'booking_time'),
                        _formatBookingTime(booking['request_time']),
                        Colors.blue,
                      ),
                      if (booking['passenger_note'] != null &&
                          booking['passenger_note'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.note,
                          SimpleTranslations.get(langCodes, 'passenger_note'),
                          booking['passenger_note'].toString(),
                          Colors.orange,
                        ),
                      ],
                      if (booking['payment_method'] != null &&
                          booking['payment_method'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.payment,
                          SimpleTranslations.get(langCodes, 'payment_method'),
                          booking['payment_method'].toString(),
                          Colors.purple,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatBookingTime(dynamic requestTime) {
    if (requestTime == null) return 'N/A';

    try {
      DateTime dateTime;
      if (requestTime is String) {
        try {
          dateTime = DateTime.parse(requestTime);
        } catch (e) {
          final timestamp = int.tryParse(requestTime);
          if (timestamp != null) {
            dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          } else {
            return 'N/A';
          }
        }
      } else if (requestTime is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(requestTime * 1000);
      } else {
        return 'N/A';
      }

      return DateFormat('MMM dd, yyyy - HH:mm').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }
}

class _EnhancedInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _EnhancedInfoCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
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
        ),
      ),
    );
  }
}
