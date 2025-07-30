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
import '../config/theme.dart';

class BookingConfirmPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingConfirmPage({Key? key, required this.booking}) : super(key: key);

  @override
  State<BookingConfirmPage> createState() => _BookingConfirmPageState();
}

class _BookingConfirmPageState extends State<BookingConfirmPage>
    with TickerProviderStateMixin {
  String langCodes = 'en';
  String currentTheme = ThemeConfig.defaultTheme;
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
    _initializePage();
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

  Future<void> _initializePage() async {
    await Future.wait([getLanguage(), _loadTheme()]);

    _setupAnimations();
    _setupCountdown();
    _setupMarkersAndRoute();
    _getCurrentLocation();
    _startBookingStatusPolling();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    if (mounted) {
      setState(() {
        currentTheme = savedTheme;
      });
    }
  }

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        langCodes = prefs.getString('languageCode') ?? 'en';
      });
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController?.repeat();
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
        debugPrint('Error parsing request_time: $e');
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
    // Fixed: Added null check before using !
    if (_countdownController != null && !_isExpired) {
      _countdownController?.forward();
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
      debugPrint('Error checking booking status: $e');
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
      debugPrint('Error getting location: $e');
    }
  }

  void _updateDriverLocationMarker() {
    // Fixed: Added proper null check
    final currentPos = _currentPosition;
    if (currentPos != null) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: LatLng(currentPos.latitude, currentPos.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: SimpleTranslations.get(langCodes, 'your_location'),
            ),
          ),
        );
      });
      _fitMarkersInView();
    }
  }

  void _showTimeoutDialog() {
    if (!mounted) return;

    _showEnhancedDialog(
      icon: Icons.timer_off,
      iconColor: Colors.red,
      title: SimpleTranslations.get(langCodes, 'booking_timeout'),
      content: SimpleTranslations.get(langCodes, 'booking_timeout_message'),
      onConfirm: () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
    );
  }

  void _showBookingCancelledDialog() {
    if (!mounted) return;

    _showEnhancedDialog(
      icon: Icons.cancel,
      iconColor: Colors.orange,
      title: SimpleTranslations.get(langCodes, 'booking_cancelled'),
      content: SimpleTranslations.get(langCodes, 'booking_cancelled_message'),
      onConfirm: () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
    );
  }

  void _showEnhancedDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.getTextColor(currentTheme),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            content,
            style: TextStyle(
              fontSize: 16,
              color: ThemeConfig.getTextColor(currentTheme),
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                  foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: onConfirm,
                child: Text(
                  SimpleTranslations.get(langCodes, 'ok'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
        color: ThemeConfig.getPrimaryColor(currentTheme),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      ),
    };
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
    // Fixed: Added null check before using map controller
    final mapController = _mapController;
    if (mapController == null || _markers.isEmpty) return;

    final bounds = _calculateBounds();
    mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
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

    // Fixed: Proper null check for current position
    final currentPos = _currentPosition;
    if (currentPos != null) {
      minLat = min(minLat, currentPos.latitude);
      maxLat = max(maxLat, currentPos.latitude);
      minLon = min(minLon, currentPos.longitude);
      maxLon = max(maxLon, currentPos.longitude);
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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ringColor = ThemeConfig.getPrimaryColor(currentTheme);
    } else if (progress > 0.3) {
      ringColor = Colors.orange;
    } else {
      ringColor = Colors.red;
    }

    // Fixed: Added null check for pulse controller
    final pulseController = _pulseController;
    if (pulseController == null) {
      return Container(
        width: 80,
        height: 80,
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
    }

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Container(
          width: 80 + (progress < 0.3 ? pulseController.value * 10 : 0),
          height: 80 + (progress < 0.3 ? pulseController.value * 10 : 0),
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
        badgeColor = ThemeConfig.getPrimaryColor(currentTheme);
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: badgeColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 18, color: badgeColor),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: onTap != null
              ? ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeConfig.getPrimaryColor(
                  currentTheme,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: ThemeConfig.getTextColor(currentTheme),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
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

      final driverId = int.tryParse(driverIdString) ?? 0;
      final carId = int.tryParse(carIdString.toString()) ?? 0;

      String driverLocation = "";
      String driverLat = "";
      String driverLon = "";

      // Fixed: Proper null handling for current position
      final currentPos = _currentPosition;
      if (currentPos != null) {
        driverLat = currentPos.latitude.toString();
        driverLon = currentPos.longitude.toString();
        driverLocation = "${currentPos.latitude}, ${currentPos.longitude}";
      } else {
        try {
          Position? position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          // ignore: unnecessary_null_comparison
          if (position != null) {
            driverLat = position.latitude.toString();
            driverLon = position.longitude.toString();
            driverLocation = "${position.latitude}, ${position.longitude}";
          }
        } catch (e) {
          debugPrint('Error getting current location: $e');
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
          'driver_id': driverId,
          'car_id': carId,
          'book_status': 'Pick up',
          'driver_location': driverLocation,
          'driver_lat': driverLat,
          'driver_lon': driverLon,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        HapticFeedback.lightImpact();
        _showSnackBar(
          'Booking confirmed successfully!',
          ThemeConfig.getPrimaryColor(currentTheme),
        );

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
      debugPrint('Error confirming booking: $e');
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
    final customerPhone = booking['passenger_id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCodes, 'booking_confirmation'),
          style: TextStyle(
            color: ThemeConfig.getButtonTextColor(currentTheme),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
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

            // Enhanced Map
            Container(
              height: 280,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ThemeConfig.getPrimaryColor(
                      currentTheme,
                    ).withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                      backgroundColor: ThemeConfig.getBackgroundColor(
                        currentTheme,
                      ),
                      textColor: ThemeConfig.getTextColor(currentTheme),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EnhancedInfoCard(
                      icon: Icons.place,
                      label: SimpleTranslations.get(langCodes, 'distance'),
                      value: formattedDistance,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                      backgroundColor: ThemeConfig.getBackgroundColor(
                        currentTheme,
                      ),
                      textColor: ThemeConfig.getTextColor(currentTheme),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Enhanced Customer Info Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: ThemeConfig.getBackgroundColor(currentTheme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: ThemeConfig.getPrimaryColor(
                  currentTheme,
                ).withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.local_taxi,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  SimpleTranslations.get(
                                    langCodes,
                                    'suggested_price',
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: ThemeConfig.getTextColor(
                                      currentTheme,
                                    ).withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "₭ $formattedSuggestPrice",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeConfig.getPrimaryColor(
                                      currentTheme,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              ThemeConfig.getTextColor(
                                currentTheme,
                              ).withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _driverRow(
                        Icons.person,
                        "${SimpleTranslations.get(langCodes, 'customer_name')}: ${booking['customer_name'] ?? booking['passenger_name'] ?? '-'}",
                      ),
                      const SizedBox(height: 8),
                      _driverRow(
                        Icons.phone,
                        "${SimpleTranslations.get(langCodes, 'phone')}: ${customerPhone.isNotEmpty ? customerPhone : '-'}",
                        onTap: customerPhone.isNotEmpty
                            ? () => _makePhoneCall(customerPhone)
                            : null,
                      ),
                      const SizedBox(height: 8),
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
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: _isConfirming
                          ? [Colors.grey, Colors.grey]
                          : [
                              ThemeConfig.getPrimaryColor(currentTheme),
                              ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ).withOpacity(0.8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeConfig.getPrimaryColor(
                          currentTheme,
                        ).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: ThemeConfig.getButtonTextColor(
                          currentTheme,
                        ),
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      icon: _isConfirming
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ThemeConfig.getButtonTextColor(currentTheme),
                                ),
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 28),
                      label: Text(
                        _isConfirming
                            ? SimpleTranslations.get(langCodes, 'confirming')
                            : SimpleTranslations.get(
                                langCodes,
                                'confirm_booking',
                              ),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: ThemeConfig.getButtonTextColor(currentTheme),
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
                      child: _buildActionButton(
                        icon: Icons.navigation,
                        label: SimpleTranslations.get(
                          langCodes,
                          'navigate_pickup',
                        ),
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                        onPressed: () => _openMaps(pickupLat, pickupLon),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (customerPhone.isNotEmpty)
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.phone,
                          label: SimpleTranslations.get(
                            langCodes,
                            'call_customer',
                          ),
                          color: Colors.green,
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
                color: ThemeConfig.getBackgroundColor(currentTheme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 3,
                shadowColor: ThemeConfig.getPrimaryColor(
                  currentTheme,
                ).withOpacity(0.1),
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
                              color: ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            SimpleTranslations.get(langCodes, 'trip_details'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ThemeConfig.getTextColor(currentTheme),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        Icons.radio_button_checked,
                        SimpleTranslations.get(langCodes, 'pickup'),
                        booking['pickup_address'] ?? 'N/A',
                        Colors.green,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.location_on,
                        SimpleTranslations.get(langCodes, 'dropoff'),
                        booking['dropoff_address'] ?? 'N/A',
                        Colors.red,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.access_time,
                        SimpleTranslations.get(langCodes, 'booking_time'),
                        _formatBookingTime(booking['request_time']),
                        ThemeConfig.getPrimaryColor(currentTheme),
                      ),
                      if (booking['passenger_note'] != null &&
                          booking['passenger_note'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.note,
                          SimpleTranslations.get(langCodes, 'passenger_note'),
                          booking['passenger_note'].toString(),
                          Colors.orange,
                        ),
                      ],
                      if (booking['payment_method'] != null &&
                          booking['payment_method'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        color: color.withOpacity(0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: ThemeConfig.getTextColor(
                    currentTheme,
                  ).withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ThemeConfig.getTextColor(currentTheme),
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
  final Color backgroundColor;
  final Color textColor;

  const _EnhancedInfoCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      shadowColor: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: textColor.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
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
