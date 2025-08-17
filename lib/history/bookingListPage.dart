import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/driver/BookingConfirmPage.dart';
// import 'package:sabaicub/config/theme_config.dart'; // Add this import
import 'package:sabaicub/config/theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'package:intl/intl.dart';

class BookingListPage extends StatefulWidget {
  const BookingListPage({super.key});

  @override
  State<BookingListPage> createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  List<dynamic> bookings = [];
  bool loading = true;
  String? error;
  String langCode = 'en';
  String currentTheme = 'green'; // Add theme variable

  @override
  void initState() {
    super.initState();
    _loadLangAndBookings();
  }

  Future<void> _loadLangAndBookings() async {
    final prefs = await SharedPreferences.getInstance();
    langCode = prefs.getString('languageCode') ?? 'en';
    currentTheme = prefs.getString('selectedTheme') ?? 'green'; // Load theme
    final driverId = prefs.getString('user');

    print('🌐 Language: $langCode');
    print('🎨 Theme: $currentTheme'); // Add theme logging
    print('👤 Driver ID: $driverId');

    if (driverId != null) {
      await fetchBookings(driverId);
    } else {
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Missing driver ID';
        });
      }
    }
  }

  Future<void> fetchBookings(String driverId) async {
    final url = AppConfig.api('/api/book/driverbookList');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"driver_id": driverId}),
      );

      print('📥 Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> result = data['data'] ?? [];

          final filtered = result.where((b) {
            final status = (b['book_status'] ?? '').toString().toLowerCase();
            return status != 'booking';
          }).toList();

          filtered.sort(
            (a, b) => DateTime.parse(
              b['request_time'],
            ).compareTo(DateTime.parse(a['request_time'])),
          );

          // Check if widget is still mounted before calling setState
          if (mounted) {
            setState(() {
              bookings = filtered;
              loading = false;
            });
          }
        } else {
          // Check if widget is still mounted before calling setState
          if (mounted) {
            setState(() {
              error = data['message'] ?? 'Unknown error';
              loading = false;
            });
          }
        }
      } else {
        // Check if widget is still mounted before calling setState
        if (mounted) {
          setState(() {
            error = 'Server error: ${response.statusCode}';
            loading = false;
          });
        }
      }
    } catch (e) {
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          error = 'Failed to load data: $e';
          loading = false;
        });
      }
    }
  }

  String translateStatus(String status) {
    if (langCode == 'la') {
      switch (status.toLowerCase()) {
        case 'pickup':
          return 'ໄປຮັບ';
        case 'completed':
          return 'ສຳເລັດ';
        case 'cancelled':
          return 'ຍົກເລີກ';
        default:
          return status;
      }
    }
    return status;
  }

  Color statusColor(String status) {
    // Use theme colors instead of hardcoded colors
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);

    switch (status.toLowerCase()) {
      case 'pickup':
        return primaryColor; // Use primary theme color for pickup
      case 'completed':
        return primaryColor.withOpacity(
          0.8,
        ); // Slightly transparent primary for completed
      case 'cancelled':
        return Colors.red.shade700; // Keep red for cancelled (error state)
      default:
        return Colors.grey.shade600; // Keep grey for unknown status
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(
        currentTheme,
      ), // Use theme background
      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: ThemeConfig.getPrimaryColor(
                  currentTheme,
                ), // Use theme color
              ),
            )
          : error != null
          ? Center(
              child: Text(
                error!,
                style: const TextStyle(
                  color: Colors.red,
                ), // Keep red for errors
              ),
            )
          : bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.car_crash,
                    size: 60,
                    color: Colors.grey, // Keep grey for empty state
                  ),
                  const SizedBox(height: 8),
                  Text(
                    SimpleTranslations.get(langCode, 'no_data_found'),
                    style: TextStyle(
                      color: ThemeConfig.getTextColor(
                        currentTheme,
                      ), // Use theme text color
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final DateTime requestTime = DateTime.parse(
                  booking['request_time'],
                );
                final formattedTime =
                    "${requestTime.hour.toString().padLeft(2, '0')}:${requestTime.minute.toString().padLeft(2, '0')}";
                final formattedPrice = NumberFormat(
                  '#,###',
                ).format(booking['payment_price']);

                // Use different status field based on language code
                final status = langCode.toLowerCase() == 'la'
                    ? booking['bookla_status'] ?? ''
                    : booking['book_status'] ?? '';

                final translatedStatus = translateStatus(status);
                final statusBgColor = statusColor(status);

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Stack(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              // Remove 'const' here
                              Icons.payments,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                            Text(
                              "₭ $formattedPrice",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.getTextColor(currentTheme),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          " ${booking['passenger_id']}",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: ThemeConfig.getTextColor(
                              currentTheme,
                            ), // Use theme text color
                          ),
                        ),
                        subtitle: Text(
                          "Time: $formattedTime",
                          style: TextStyle(
                            color: ThemeConfig.getTextColor(
                              currentTheme,
                            ).withOpacity(0.7), // Lighter theme text
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ), // Use theme color
                        ),
                        onTap: () {
                          print('📲 Booking tapped: ${booking['book_id']}');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BookingConfirmPage(booking: booking),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            translatedStatus,
                            style: TextStyle(
                              color: ThemeConfig.getButtonTextColor(
                                currentTheme,
                              ), // Use theme button text color
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
