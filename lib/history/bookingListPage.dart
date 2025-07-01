import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kupcar/driver/BookingConfirmPage.dart'; // Update if your path differs
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLangAndBookings();
  }

  Future<void> _loadLangAndBookings() async {
    final prefs = await SharedPreferences.getInstance();
    langCode = prefs.getString('langCode') ?? 'en';
    final passengerId = prefs.getString('user');
    if (passengerId != null) {
      await fetchBookings(passengerId);
    } else {
      setState(() {
        loading = false;
        error = 'Missing passenger ID';
      });
    }
  }

  Future<void> fetchBookings(String passengerId) async {
    final url = AppConfig.api('/api/book/bookList');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"passenger_id": passengerId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> result = data['data'] ?? [];
          result.sort(
            (a, b) => DateTime.parse(
              b['request_time'],
            ).compareTo(DateTime.parse(a['request_time'])),
          );
          setState(() {
            bookings = result;
            loading = false;
          });
        } else {
          setState(() {
            error = data['message'] ?? 'Unknown error';
            loading = false;
          });
        }
      } else {
        setState(() {
          error = 'Server error: ${response.statusCode}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load data: $e';
        loading = false;
      });
    }
  }

  String formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String translateStatus(String status) {
    if (langCode == 'la') {
      switch (status.toLowerCase()) {
        case 'pick up':
        case 'pickup':
          return 'ໄປຮັບ';
        case 'booking':
          return 'ເອີນລົດ';
        default:
          return status;
      }
    } else {
      return status;
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pick up':
      case 'pickup':
        return Colors.green.shade700;
      case 'booking':
        return Colors.orange.shade700;
      case 'completed':
        return Colors.blue.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : bookings.isEmpty
          ? Center(
              child: Text(
                SimpleTranslations.get(langCode, 'no_bookings_found'),
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
                final status = booking['book_status'] ?? '';
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
                          " ${booking['passenger_id']}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text("Time: $formattedTime"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
                      // Positioned status label at top right
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
                            style: const TextStyle(
                              color: Colors.white,
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
