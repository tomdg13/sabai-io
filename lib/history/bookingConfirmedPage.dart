import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kupcar/config/config.dart';
import 'package:kupcar/history/bookingListPage.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// import 'bookingListPage.dart'; // ✅ Update this to match your file name

class BookingConfirmedPage extends StatefulWidget {
  final int bookingId;

  const BookingConfirmedPage({super.key, required this.bookingId});

  @override
  State<BookingConfirmedPage> createState() => _BookingConfirmedPageState();
}

class _BookingConfirmedPageState extends State<BookingConfirmedPage> {
  Map<String, dynamic>? bookingDetails;
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      setState(() {
        errorMsg = 'You are not logged in.';
        isLoading = false;
      });
      return;
    }

    final url = AppConfig.api('/api/book/${widget.bookingId}');

    try {
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          bookingDetails = data['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMsg = 'Failed to load booking details (${res.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Error fetching data: $e';
        isLoading = false;
      });
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '-';
    final dateTime = DateTime.tryParse(isoString);
    if (dateTime == null) return '-';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '-';
    final dateTime = DateTime.tryParse(isoString);
    if (dateTime == null) return '-';
    return DateFormat('HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Confirmed')),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : errorMsg != null
            ? Text(errorMsg!, style: const TextStyle(color: Colors.red))
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.directions_car,
                        size: 80,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        '✅ Your booking has been confirmed!',
                        style: TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow(
                      'Booking ID',
                      bookingDetails!['book_id'].toString(),
                    ),
                    _buildDetailRow(
                      'Booking Date',
                      _formatDate(bookingDetails!['request_time']),
                    ),
                    _buildDetailRow(
                      'Booking Time',
                      _formatTime(bookingDetails!['request_time']),
                    ),
                    _buildDetailRow(
                      'Payment Price',
                      '${bookingDetails!['payment_price']} LAK',
                    ),
                    _buildDetailRow(
                      'Status',
                      bookingDetails!['book_status'] ?? '-',
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BookingListPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Go to Booking List'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(220, 48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
