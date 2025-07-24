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

class BookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BookingDetailPage({Key? key, required this.booking}) : super(key: key);

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage>
    with TickerProviderStateMixin {
  String langCodes = 'en';
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

  // Map markers and polylines
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _currentBooking = Map<String, dynamic>.from(widget.booking);

    // Debug: Print all available fields
    print('=== BOOKING DATA FIELDS ===');
    _currentBooking.forEach((key, value) {
      print('$key: $value');
    });
    print('=== END BOOKING DATA ===');

    getLanguage();
    _setupAnimations();
    _setupMarkersAndRoute();
    _getCurrentLocation();
    _startStatusPolling();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _statusAnimationController?.dispose();
    _buttonAnimationController?.dispose();
    _statusUpdateTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _statusAnimationController!.forward();
    _buttonAnimationController!.forward();
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
      print('Error updating booking status: $e');
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
        _markers.removeWhere((marker) => marker.markerId.value == 'driver');
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
      _fitMarkersInView();
    }
  }

  void _fitMarkersInView() {
    if (_mapController == null || _markers.isEmpty) return;

    final bounds = _calculateBounds();
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
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

  void _showStatusUpdateSnackBar(String newStatus) {
    if (!mounted) return;

    Color statusColor = _getStatusColor(newStatus);
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.update, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Status updated to: $newStatus'),
          ],
        ),
        backgroundColor: statusColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        _showSnackBar('Status updated successfully!', Colors.green);
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
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        return Colors.blue;
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

    return AnimatedBuilder(
      animation: _statusAnimationController!,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_statusAnimationController!.value * 0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
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
  }

  Widget _buildActionButtons() {
    final status =
        _currentBooking['book_status']?.toString().toLowerCase() ?? '';
    final customerPhone =
        _currentBooking['customer_phone']?.toString() ??
        _currentBooking['passenger_phone']?.toString() ??
        _currentBooking['phone']?.toString() ??
        _currentBooking['user_phone']?.toString() ??
        '';

    return AnimatedBuilder(
      animation: _buttonAnimationController!,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _buttonAnimationController!.value)),
          child: Opacity(
            opacity: _buttonAnimationController!.value,
            child: Column(
              children: [
                // Status update buttons
                if (status == 'pick up')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: _isUpdatingStatus
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.play_arrow, size: 24),
                        label: Text(
                          _isUpdatingStatus
                              ? SimpleTranslations.get(langCodes, 'updating')
                              : SimpleTranslations.get(langCodes, 'start_trip'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _isUpdatingStatus
                            ? null
                            : () => _updateTripStatus('In Progress'),
                      ),
                    ),
                  ),

                if (status == 'in progress' || status == 'on trip')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: _isUpdatingStatus
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.check_circle, size: 24),
                        label: Text(
                          _isUpdatingStatus
                              ? SimpleTranslations.get(langCodes, 'updating')
                              : SimpleTranslations.get(
                                  langCodes,
                                  'complete_trip',
                                ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _isUpdatingStatus
                            ? null
                            : () => _updateTripStatus('Completed'),
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
                              color: Colors.green,
                              size: 20,
                            ),
                            label: Text(
                              SimpleTranslations.get(langCodes, 'call'),
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                            onPressed: () => _makePhoneCall(customerPhone),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: Colors.blue.withOpacity(0.5),
                            ),
                          ),
                          icon: _isNavigating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.navigation,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                          label: Text(
                            SimpleTranslations.get(langCodes, 'navigate'),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
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
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCodes, 'booking_details')),
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
              height: 300,
              margin: const EdgeInsets.all(16),
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
                          color: Colors.deepPurple,
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
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Trip Details Card
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
                        _currentBooking['pickup_address'] ?? 'N/A',
                        Colors.green,
                        onTap: () => _openMaps(pickupLat, pickupLon),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.location_on,
                        SimpleTranslations.get(langCodes, 'dropoff'),
                        _currentBooking['dropoff_address'] ?? 'N/A',
                        Colors.red,
                        onTap: () => _openMaps(dropoffLat, dropoffLon),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.access_time,
                        SimpleTranslations.get(langCodes, 'booking_time'),
                        _formatBookingTime(_currentBooking['request_time']),
                        Colors.blue,
                      ),
                      if (_currentBooking['passenger_note'] != null &&
                          _currentBooking['passenger_note']
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 12),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
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
            if (onTap != null)
              Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.05), color.withOpacity(0.02)],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
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
