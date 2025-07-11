import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/history/bookingConfirmedPage.dart';
// import 'package:sabaicub/history/booking_confirmed_page.dart';  // Import your BookingConfirmedPage here
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (bookings.isEmpty) {
      return Center(
        child: Text('No bookings found'), // You can localize this
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Booking List')),
      body: ListView.builder(
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final b = bookings[index];
          final status = b['book_status'] ?? 'unknown';
          final requestTime = formatDateTime(b['request_time'] ?? '');
          final payment = NumberFormat('#,###').format(b['payment_price'] ?? 0);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(
                status,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
              subtitle: Text(requestTime, style: const TextStyle(fontSize: 14)),
              trailing: Text(
                payment,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
              onTap: () {
                final bookingId = b['book_id'];
                if (bookingId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BookingConfirmedPage(bookingId: bookingId),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
