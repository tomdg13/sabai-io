import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import '../menu/menu_page.dart';
import '../utils/simple_translations.dart';
import '../config/config.dart';
import '../config/theme.dart';

class BookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailPage({Key? key, required this.booking}) : super(key: key);

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage>
    with TickerProviderStateMixin {
  String langCodes = 'en';
  String currentTheme = ThemeConfig.defaultTheme;
  GoogleMapController? _mapController;
  Timer? _statusUpdateTimer;
  Timer? _locationUpdateTimer;
  Position? _currentPosition;
  Map<String, dynamic> _currentBooking = {};
  bool _isUpdatingStatus = false;
  bool _isNavigating = false;

  // Animation controllers
  AnimationController? _statusAnimationController;
  AnimationController? _buttonAnimationController;
  AnimationController? _pulseController;

  // Map markers and polylines
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _currentBooking = Map<String, dynamic>.from(widget.booking);
    _initializePage();
  }

  @override
  void dispose() {
    _statusAnimationController?.dispose();
    _buttonAnimationController?.dispose();
    _pulseController?.dispose();
    _statusUpdateTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    // Debug: Print all available fields
    debugPrint('=== BOOKING DATA FIELDS ===');
    _currentBooking.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('=== END BOOKING DATA ===');

    await Future.wait([getLanguage(), _loadTheme()]);

    _setupAnimations();
    _setupMarkersAndRoute();
    _getCurrentLocation();
    _startStatusPolling();
    _startLocationTracking();
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
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Fixed: Added null checks before using !
    _statusAnimationController?.forward();
    _buttonAnimationController?.forward();
    _pulseController?.repeat();
  }

  void _setupMarkersAndRoute() {
    final pickupLat =
        double.tryParse(_currentBooking['pickup_lat'].toString()) ?? 0;
    final pickupLon =
        double.tryParse(_currentBooking['pickup_lon'].toString()) ?? 0;
    final dropoffLat =
        double.tryParse(_currentBooking['dropoff_lat'].toString()) ?? 0;
    final dropoffLon =
        double.tryParse(_currentBooking['dropoff_lon'].toString()) ?? 0;

    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLat, pickupLon),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: SimpleTranslations.get(langCodes, 'pickup_location'),
          snippet: _currentBooking['pickup_address'] ?? '',
        ),
        onTap: () => _openMaps(pickupLat, pickupLon),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(dropoffLat, dropoffLon),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: SimpleTranslations.get(langCodes, 'dropoff_location'),
          snippet: _currentBooking['dropoff_address'] ?? '',
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

  void _startStatusPolling() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _updateBookingStatus();
      }
    });
  }

  void _startLocationTracking() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _getCurrentLocation();
      }
    });
  }

  Future<void> _updateBookingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final bookingId = _currentBooking['book_id'];

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
        if (data['book_status'] != _currentBooking['book_status']) {
          setState(() {
            _currentBooking = {..._currentBooking, ...data};
          });
          _showStatusUpdateSnackBar(data['book_status']);
        }
      }
    } catch (e) {
      debugPrint('Error updating booking status: $e');
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
    // Fixed: Proper null check for current position
    final currentPos = _currentPosition;
    if (currentPos != null) {
      setState(() {
        _markers.removeWhere((marker) => marker.markerId.value == 'driver');
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

  void _fitMarkersInView() {
    // Fixed: Added null check for map controller
    final mapController = _mapController;
    if (mapController == null || _markers.isEmpty) return;

    final bounds = _calculateBounds();
    mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _calculateBounds() {
    final pickupLat =
        double.tryParse(_currentBooking['pickup_lat'].toString()) ?? 0;
    final pickupLon =
        double.tryParse(_currentBooking['pickup_lon'].toString()) ?? 0;
    final dropoffLat =
        double.tryParse(_currentBooking['dropoff_lat'].toString()) ?? 0;
    final dropoffLon =
        double.tryParse(_currentBooking['dropoff_lon'].toString()) ?? 0;

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

  void _showStatusUpdateSnackBar(String newStatus) {
    if (!mounted) return;

    Color statusColor = _getStatusColor(newStatus);
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.update, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Status updated to: $newStatus',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: statusColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openMaps(double lat, double lon) async {
    setState(() {
      _isNavigating = true;
    });

    final Uri googleUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleUrl)) {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
        HapticFeedback.lightImpact();
      } else {
        _showSnackBar('Could not open Google Maps', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error opening maps', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        HapticFeedback.lightImpact();
      } else {
        _showSnackBar('Could not make phone call', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error making phone call', Colors.red);
    }
  }

  Future<void> _updateTripStatus(String newStatus) async {
    if (_isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final bookingId = _currentBooking['book_id'];

      final url = AppConfig.api('/api/book/update/$bookingId');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'book_status': newStatus}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _currentBooking['book_status'] = newStatus;
        });
        HapticFeedback.lightImpact();
        _showSnackBar(
          'Status updated successfully!',
          ThemeConfig.getPrimaryColor(currentTheme),
        );
      } else {
        _showSnackBar('Failed to update status', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Network error occurred', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booking':
        return Colors.orange;
      case 'pick up':
        return ThemeConfig.getPrimaryColor(currentTheme);
      case 'in progress':
      case 'on trip':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge() {
    final status = _currentBooking['book_status']?.toString() ?? 'Unknown';
    final color = _getStatusColor(status);

    // Fixed: Added null checks for animation controllers
    final statusController = _statusAnimationController;
    final pulseController = _pulseController;

    if (statusController == null || pulseController == null) {
      // Fallback widget when controllers are null
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              status.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: statusController,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            final pulseValue = (sin(pulseController.value * 2 * pi) + 1) / 2;
            final shouldPulse =
                status.toLowerCase() == 'in progress' ||
                status.toLowerCase() == 'on trip';

            return Transform.scale(
              scale:
                  0.8 +
                  (statusController.value * 0.2) +
                  (shouldPulse ? pulseValue * 0.1 : 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: shouldPulse ? pulseValue * 2 : 0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons() {
    final status =
        _currentBooking['book_status']?.toString().toLowerCase() ?? '';
    final customerPhone =
        _currentBooking['customer_phone']?.toString() ??
        _currentBooking['passenger_phone']?.toString() ??
        _currentBooking['phone']?.toString() ??
        _currentBooking['user_phone']?.toString() ??
        _currentBooking['passenger_id']?.toString() ??
        '';

    // Fixed: Added null check for button animation controller
    final buttonController = _buttonAnimationController;
    if (buttonController == null) {
      // Fallback widget when controller is null
      return Column(
        children: [
          if (status == 'pick up')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _isUpdatingStatus
                        ? [Colors.grey, Colors.grey]
                        : [Colors.purple, Colors.purple.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: _isUpdatingStatus
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
                        : const Icon(Icons.play_arrow, size: 28),
                    label: Text(
                      _isUpdatingStatus
                          ? SimpleTranslations.get(langCodes, 'updating')
                          : SimpleTranslations.get(langCodes, 'start_trip'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _updateTripStatus('In Progress'),
                  ),
                ),
              ),
            ),
          // Add other buttons similarly...
        ],
      );
    }

    return AnimatedBuilder(
      animation: buttonController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - buttonController.value)),
          child: Opacity(
            opacity: buttonController.value,
            child: Column(
              children: [
                // Status update buttons
                if (status == 'pick up')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: _isUpdatingStatus
                              ? [Colors.grey, Colors.grey]
                              : [Colors.purple, Colors.purple.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: _isUpdatingStatus
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
                              : const Icon(Icons.play_arrow, size: 28),
                          label: Text(
                            _isUpdatingStatus
                                ? SimpleTranslations.get(langCodes, 'updating')
                                : SimpleTranslations.get(
                                    langCodes,
                                    'start_trip',
                                  ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _isUpdatingStatus
                              ? null
                              : () => _updateTripStatus('In Progress'),
                        ),
                      ),
                    ),
                  ),

                if (status == 'in progress' || status == 'on trip')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: _isUpdatingStatus
                              ? [Colors.grey, Colors.grey]
                              : [Colors.green, Colors.green.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: _isUpdatingStatus
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
                              : const Icon(Icons.check_circle, size: 28),
                          label: Text(
                            _isUpdatingStatus
                                ? SimpleTranslations.get(langCodes, 'updating')
                                : SimpleTranslations.get(
                                    langCodes,
                                    'complete_trip',
                                  ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _isUpdatingStatus
                              ? null
                              : () => _updateTripStatus('Completed'),
                        ),
                      ),
                    ),
                  ),

                // Quick action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      if (customerPhone.isNotEmpty) ...[
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.phone,
                            label: SimpleTranslations.get(langCodes, 'call'),
                            color: Colors.green,
                            onPressed: () => _makePhoneCall(customerPhone),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: _buildActionButton(
                          icon: _isNavigating
                              ? Icons.hourglass_empty
                              : Icons.navigation,
                          label: SimpleTranslations.get(langCodes, 'navigate'),
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                          isLoading: _isNavigating,
                          onPressed: _isNavigating
                              ? null
                              : () {
                                  final pickupLat =
                                      double.tryParse(
                                        _currentBooking['pickup_lat']
                                            .toString(),
                                      ) ??
                                      0;
                                  final pickupLon =
                                      double.tryParse(
                                        _currentBooking['pickup_lon']
                                            .toString(),
                                      ) ??
                                      0;
                                  _openMaps(pickupLat, pickupLon);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              children: [
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMarkersInView();
  }

  @override
  Widget build(BuildContext context) {
    final pickupLat =
        double.tryParse(_currentBooking['pickup_lat'].toString()) ?? 0;
    final pickupLon =
        double.tryParse(_currentBooking['pickup_lon'].toString()) ?? 0;
    final dropoffLat =
        double.tryParse(_currentBooking['dropoff_lat'].toString()) ?? 0;
    final dropoffLon =
        double.tryParse(_currentBooking['dropoff_lon'].toString()) ?? 0;

    final formattedPrice = (_currentBooking['payment_price'] != null)
        ? "₭ ${NumberFormat('#,###').format(_currentBooking['payment_price'])}"
        : "-";

    final formattedDistance = (_currentBooking['distance'] != null)
        ? "${(_currentBooking['distance'] as num).toStringAsFixed(2)} km"
        : "-";

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCodes, 'booking_details'),
          style: TextStyle(
            color: ThemeConfig.getButtonTextColor(currentTheme),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: ThemeConfig.getButtonTextColor(currentTheme),
          ),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            final role = prefs.getString('role') ?? 'driver';

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => MenuPage(role: role)),
              (route) => false,
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _buildStatusBadge()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Enhanced Map Section
            Container(
              height: 320,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ThemeConfig.getPrimaryColor(
                      currentTheme,
                    ).withOpacity(0.15),
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

            // Action Buttons Section
            _buildActionButtons(),

            const SizedBox(height: 20),

            // Enhanced Info Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _EnhancedInfoCard(
                          icon: Icons.confirmation_num,
                          label: SimpleTranslations.get(
                            langCodes,
                            'booking_id',
                          ),
                          value: _currentBooking['book_id']?.toString() ?? '-',
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
                          icon: Icons.person,
                          label: SimpleTranslations.get(langCodes, 'customer'),
                          value:
                              _currentBooking['customer_name']?.toString() ??
                              _currentBooking['passenger_name']?.toString() ??
                              _currentBooking['user_name']?.toString() ??
                              _currentBooking['name']?.toString() ??
                              '-',
                          color: Colors.teal,
                          backgroundColor: ThemeConfig.getBackgroundColor(
                            currentTheme,
                          ),
                          textColor: ThemeConfig.getTextColor(currentTheme),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _EnhancedInfoCard(
                          icon: Icons.payments,
                          label: SimpleTranslations.get(langCodes, 'price'),
                          value: formattedPrice,
                          color: Colors.green,
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
                          color: Colors.orange,
                          backgroundColor: ThemeConfig.getBackgroundColor(
                            currentTheme,
                          ),
                          textColor: ThemeConfig.getTextColor(currentTheme),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Trip Details Card
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
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
                        _currentBooking['pickup_address'] ?? 'N/A',
                        Colors.green,
                        onTap: () => _openMaps(pickupLat, pickupLon),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.location_on,
                        SimpleTranslations.get(langCodes, 'dropoff'),
                        _currentBooking['dropoff_address'] ?? 'N/A',
                        Colors.red,
                        onTap: () => _openMaps(dropoffLat, dropoffLon),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        Icons.access_time,
                        SimpleTranslations.get(langCodes, 'booking_time'),
                        _formatBookingTime(_currentBooking['request_time']),
                        ThemeConfig.getPrimaryColor(currentTheme),
                      ),
                      if (_currentBooking['passenger_note'] != null &&
                          _currentBooking['passenger_note']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.note,
                          SimpleTranslations.get(langCodes, 'passenger_note'),
                          _currentBooking['passenger_note'].toString(),
                          Colors.orange,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: onTap != null ? color.withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
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
            if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: color),
          ],
        ),
      ),
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: textColor.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
