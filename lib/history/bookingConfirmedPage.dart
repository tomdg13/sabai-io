import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/history/bookingListPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
  String currentTheme = 'green'; // Default theme

  // Predefined themes - same as DriverPage
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
    _loadTheme();
    _fetchBookingDetails();
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: selectedTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selectedTheme.primaryColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _getIconForLabel(label),
            color: selectedTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selectedTheme.textColor,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: selectedTheme.textColor, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'booking id':
        return Icons.confirmation_number;
      case 'booking date':
        return Icons.calendar_today;
      case 'booking time':
        return Icons.access_time;
      case 'payment price':
        return Icons.payments;
      case 'status':
        return Icons.info_outline;
      default:
        return Icons.info;
    }
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

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final formattedPrice = NumberFormat('#,###').format(price);
    return '₭ $formattedPrice';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: selectedTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Booking Confirmed',
          style: TextStyle(color: selectedTheme.buttonTextColor),
        ),
        backgroundColor: selectedTheme.primaryColor,
        iconTheme: IconThemeData(color: selectedTheme.buttonTextColor),
        elevation: 0,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  selectedTheme.primaryColor,
                ),
              ),
            )
          : errorMsg != null
          ? Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMsg!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isLoading = true;
                          errorMsg = null;
                        });
                        _fetchBookingDetails();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTheme.primaryColor,
                        foregroundColor: selectedTheme.buttonTextColor,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Success Animation Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: selectedTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selectedTheme.primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.directions_car,
                            size: 48,
                            color: selectedTheme.buttonTextColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '✅ Booking Confirmed!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: selectedTheme.primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your ride has been successfully booked',
                          style: TextStyle(
                            fontSize: 16,
                            color: selectedTheme.textColor.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Booking Details Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: selectedTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selectedTheme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: selectedTheme.primaryColor.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: selectedTheme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Booking Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: selectedTheme.textColor,
                              ),
                            ),
                          ],
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
                          _formatPrice(bookingDetails!['payment_price']),
                        ),
                        _buildDetailRow(
                          'Status',
                          bookingDetails!['book_status'] ?? '-',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BookingListPage(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.list_alt,
                        color: selectedTheme.buttonTextColor,
                      ),
                      label: Text(
                        'Go to Booking List',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: selectedTheme.buttonTextColor,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTheme.primaryColor,
                        foregroundColor: selectedTheme.buttonTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: selectedTheme.primaryColor.withOpacity(
                          0.4,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
