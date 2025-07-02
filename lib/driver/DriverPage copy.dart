import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kupcar/config/config.dart';
import 'package:kupcar/driver/BookingConfirmPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({Key? key}) : super(key: key);

  @override
  _DriverPageState createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> with WidgetsBindingObserver {
  String name = '';
  String phone = '';
  String status = 'Offline';
  String langCodes = 'en';
  String token = '';
  List<dynamic> bookings = [];
  bool loading = false;
  Timer? refreshTimer;

  double? currentLat;
  double? currentLon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDriverInfo();
    getLanguage();
    startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (status == 'Online' && currentLat != null && currentLon != null) {
        fetchNearbyBookings(currentLat!, currentLon!);
      }
    }
  }

  void startAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status == 'Online' && currentLat != null && currentLon != null) {
        fetchNearbyBookings(currentLat!, currentLon!);
      }
    });
  }

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    langCodes = prefs.getString('languageCode') ?? 'en';
    setState(() {});
  }

  Future<void> _loadDriverInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('name') ?? 'Driver';
      phone = prefs.getString('user') ?? '';
      status = prefs.getString('status') ?? 'Offline';
      token = prefs.getString('access_token') ?? '';
    });

    currentLat = 17.960895;
    currentLon = 102.620052;

    if (status == 'Online' && currentLat != null && currentLon != null) {
      await fetchNearbyBookings(currentLat!, currentLon!);
    } else {
      setState(() {
        bookings = [];
      });
    }
  }

  Future<void> fetchNearbyBookings(double lat, double lon) async {
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
        setState(() {
          bookings = data;
        });
      }
    } catch (e) {
      // Error handling
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
        setState(() {
          status = newStatus;
        });

        if (newStatus == 'Online' && currentLat != null && currentLon != null) {
          await fetchNearbyBookings(currentLat!, currentLon!);
          startAutoRefresh(); // restart timer when online
        } else {
          refreshTimer?.cancel();
          setState(() {
            bookings = [];
          });
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${SimpleTranslations.get(langCodes, 'welcome')}, $name",
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  "${SimpleTranslations.get(langCodes, 'status')}: ",
                  style: const TextStyle(fontSize: 16),
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
                  onPressed: _toggleStatus,
                  child: Text(
                    status == 'Online'
                        ? SimpleTranslations.get(langCodes, 'go_offline')
                        : SimpleTranslations.get(langCodes, 'go_online'),
                  ),
                ),
              ],
            ),
            const Divider(height: 40),
            Text(
              SimpleTranslations.get(langCodes, 'my_bookings'),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: status != 'Online'
                  ? Center(
                      child: Text(
                        SimpleTranslations.get(langCodes, 'offline_message'),
                      ),
                    )
                  : bookings.isEmpty
                  ? const Center(child: CircularProgressIndicator())
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text("Time: $formattedTime"),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BookingConfirmPage(booking: booking),
                                ),
                              );
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
