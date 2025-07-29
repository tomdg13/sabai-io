import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/driver/BookingConfirmPage.dart';
import 'package:sabaicub/car/CarAddPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';

// Theme data class
class AppTheme {
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  final Color buttonTextColor;

  AppTheme({
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.buttonTextColor,
  });
}

class DriverPage extends StatefulWidget {
  const DriverPage({Key? key}) : super(key: key);

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> with WidgetsBindingObserver {
  String name = 'Driver';
  String phone = '';
  String licensePlate = '';
  String status = 'Offline';
  String langCodes = 'en';
  String currentTheme = 'green';
  String token = '';
  List<dynamic> bookings = [];
  Timer? refreshTimer;
  bool isNavigatingAway = false; // Track navigation state

  double? currentLat;
  double? currentLon;

  // Predefined themes
  final Map<String, AppTheme> themes = {
    'green': AppTheme(
      name: 'Green',
      primaryColor: Colors.green,
      accentColor: Colors.green.shade700,
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      buttonTextColor: Colors.white,
    ),
    'blue': AppTheme(
      name: 'Blue',
      primaryColor: Colors.blue,
      accentColor: Colors.blue.shade700,
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      buttonTextColor: Colors.white,
    ),
    'purple': AppTheme(
      name: 'Purple',
      primaryColor: Colors.purple,
      accentColor: Colors.purple.shade700,
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      buttonTextColor: Colors.white,
    ),
    'orange': AppTheme(
      name: 'Orange',
      primaryColor: Colors.orange,
      accentColor: Colors.orange.shade700,
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      buttonTextColor: Colors.white,
    ),
    'teal': AppTheme(
      name: 'Teal',
      primaryColor: Colors.teal,
      accentColor: Colors.teal.shade700,
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      buttonTextColor: Colors.white,
    ),
    'dark': AppTheme(
      name: 'Dark',
      primaryColor: Colors.grey.shade800,
      accentColor: Colors.grey.shade900,
      backgroundColor: Colors.grey.shade100,
      textColor: Colors.black87,
      buttonTextColor: Colors.white,
    ),
  };

  AppTheme get selectedTheme => themes[currentTheme] ?? themes['green']!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDriverInfo();
    getLanguage();
    _loadTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground
        isNavigatingAway = false;
        if (status == 'Online' && currentLat != null && currentLon != null) {
          fetchNearbyBookings(currentLat!, currentLon!);
          startAutoRefresh(); // Restart auto-refresh
        }
        break;
      case AppLifecycleState.paused:
        // App went to background
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., during navigation)
        break;
      case AppLifecycleState.detached:
        // App is detached
        refreshTimer?.cancel();
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('selectedTheme') ?? 'green';
    if (mounted) {
      setState(() {
        currentTheme = savedTheme;
      });
    }
  }

  void startAutoRefresh() {
    // Cancel existing timer
    refreshTimer?.cancel();

    // Only start if online and not navigating away
    if (status == 'Online' && !isNavigatingAway) {
      refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (status == 'Online' &&
            currentLat != null &&
            currentLon != null &&
            mounted &&
            !isNavigatingAway) {
          fetchNearbyBookings(currentLat!, currentLon!);
        }
      });
    }
  }

  void stopAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        langCodes = prefs.getString('languageCode') ?? 'en';
      });
    }
  }

  Future<void> _loadDriverInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        phone = prefs.getString('user') ?? '';
        status = prefs.getString('status') ?? 'Offline';
        token = prefs.getString('access_token') ?? '';
      });
    }

    currentLat = 17.960895;
    currentLon = 102.620052;

    await getDriverProfile();

    if (status == 'Online' && currentLat != null && currentLon != null) {
      await fetchNearbyBookings(currentLat!, currentLon!);
      startAutoRefresh();
    } else {
      setState(() {
        bookings = [];
      });
    }
  }

  Future<void> getDriverProfile() async {
    if (token.isEmpty || phone.isEmpty) return;

    final url = AppConfig.api('/api/user/getProfiledriver');
    final body = jsonEncode({'phone': int.tryParse(phone) ?? phone});

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final profile = data['data'] ?? {};

        if (mounted) {
          setState(() {
            name = profile['name'] ?? 'Driver';
            licensePlate = profile['license_plate'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error getting driver profile: $e');
    }
  }

  Future<void> fetchNearbyBookings(double lat, double lon) async {
    if (token.isEmpty || isNavigatingAway) return;

    final url = AppConfig.api('/api/driver/nearby');
    final payload = {'lat': lat, 'lon': lon};

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted && !isNavigatingAway) {
          setState(() {
            bookings = data;
          });
        }
      }
    } catch (e) {
      print('Error fetching nearby bookings: $e');
    }
  }

  Future<void> _toggleStatus() async {
    final newStatus = (status == 'Online') ? 'Offline' : 'Online';
    final url = AppConfig.api('/api/driver/status');
    final payload = {'phone': phone, 'online': newStatus};

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('status', newStatus);

        if (mounted) {
          setState(() {
            status = newStatus;
          });
        }

        if (newStatus == 'Online' && currentLat != null && currentLon != null) {
          await fetchNearbyBookings(currentLat!, currentLon!);
          startAutoRefresh();
        } else {
          stopAutoRefresh();
          if (mounted) {
            setState(() {
              bookings = [];
            });
          }
        }
      }
    } catch (e) {
      print('Error toggling status: $e');
    }
  }

  // Method to refresh bookings when returning from navigation
  Future<void> _refreshAfterNavigation() async {
    if (status == 'Online' && currentLat != null && currentLon != null) {
      await fetchNearbyBookings(currentLat!, currentLon!);
      startAutoRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show Add Car button if license plate missing
    if (licensePlate.isEmpty) {
      return Scaffold(
        backgroundColor: selectedTheme.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${SimpleTranslations.get(langCodes, 'welcome')}, $name",
                  style: TextStyle(
                    fontSize: 20,
                    color: selectedTheme.textColor,
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedTheme.primaryColor,
                    foregroundColor: selectedTheme.buttonTextColor,
                  ),
                  onPressed: () async {
                    isNavigatingAway = true;
                    stopAutoRefresh();

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CarAddPage(),
                      ),
                    );

                    isNavigatingAway = false;
                    await getDriverProfile();
                    await _refreshAfterNavigation();
                  },
                  child: Text(SimpleTranslations.get(langCodes, 'add_car')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: selectedTheme.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${SimpleTranslations.get(langCodes, 'welcome')}, $name",
              style: TextStyle(fontSize: 20, color: selectedTheme.textColor),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellowAccent.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car, color: Colors.black),
                    const SizedBox(width: 10),
                    Text(
                      licensePlate,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  "${SimpleTranslations.get(langCodes, 'status')}: ",
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedTheme.textColor,
                  ),
                ),
                Text(
                  SimpleTranslations.get(langCodes, status.toLowerCase()),
                  style: TextStyle(
                    fontSize: 16,
                    color: status == 'Online' ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedTheme.primaryColor,
                    foregroundColor: selectedTheme.buttonTextColor,
                  ),
                  onPressed: _toggleStatus,
                  child: Text(
                    status == 'Online'
                        ? SimpleTranslations.get(langCodes, 'go_offline')
                        : SimpleTranslations.get(langCodes, 'go_online'),
                  ),
                ),
              ],
            ),
            Divider(
              height: 40,
              color: selectedTheme.textColor.withOpacity(0.3),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  SimpleTranslations.get(langCodes, 'my_bookings'),
                  style: TextStyle(
                    fontSize: 18,
                    color: selectedTheme.textColor,
                  ),
                ),
                if (status == 'Online')
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: selectedTheme.primaryColor,
                    ),
                    onPressed: () async {
                      if (currentLat != null && currentLon != null) {
                        await fetchNearbyBookings(currentLat!, currentLon!);
                      }
                    },
                    tooltip: 'Refresh bookings',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: status != 'Online'
                  ? Center(
                      child: Text(
                        SimpleTranslations.get(langCodes, 'offline_message'),
                        style: TextStyle(color: selectedTheme.textColor),
                      ),
                    )
                  : bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              selectedTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Searching for nearby customers...',
                            style: TextStyle(
                              color: selectedTheme.textColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        final requestTime = DateTime.parse(
                          booking['request_time'],
                        );
                        final formattedTime =
                            "${requestTime.hour.toString().padLeft(2, '0')}:${requestTime.minute.toString().padLeft(2, '0')}";
                        final formattedPrice = NumberFormat(
                          '#,###',
                        ).format(booking['payment_price']);

                        return Card(
                          color: selectedTheme.backgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.payments, color: Colors.green),
                                Text(
                                  "₭ $formattedPrice",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              (booking['passenger_name'] ??
                                      booking['passenger_id'])
                                  .toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: selectedTheme.textColor,
                              ),
                            ),
                            subtitle: Text(
                              "Time: $formattedTime",
                              style: TextStyle(
                                color: selectedTheme.textColor.withOpacity(0.7),
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: selectedTheme.primaryColor,
                            ),
                            onTap: () async {
                              // Set navigation flag and stop auto-refresh
                              isNavigatingAway = true;
                              stopAutoRefresh();

                              final updatedBooking = Map<String, dynamic>.from(
                                booking,
                              );

                              updatedBooking['car_id'] =
                                  booking['car_id'] ?? 19;
                              updatedBooking['license_plate'] =
                                  booking['license_plate'] ?? licensePlate;
                              updatedBooking['driver_name'] =
                                  booking['driver_name'] ?? name;
                              updatedBooking['driver_phone'] =
                                  booking['driver_phone'] ?? phone;

                              // Navigate to booking confirmation
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingConfirmPage(
                                    booking: updatedBooking,
                                  ),
                                ),
                              );

                              // Reset navigation flag and restart auto-refresh
                              isNavigatingAway = false;
                              await _refreshAfterNavigation();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
