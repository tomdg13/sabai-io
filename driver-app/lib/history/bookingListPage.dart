import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/driver/BookingConfirmPage.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
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
  String currentTheme = 'green'; // Default theme
  String? selectedStatusFilter; // Add filter state

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
    _loadTheme();
    _loadLangAndBookings();
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

  Future<void> _loadLangAndBookings() async {
    final prefs = await SharedPreferences.getInstance();
    langCode = prefs.getString('languageCode') ?? 'en';
    final driverId = prefs.getString('user');

    print('🌐 Language: $langCode');
    print('👤 Driver ID: $driverId');

    if (driverId != null) {
      await fetchBookings(driverId);
    } else {
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

          if (mounted) {
            setState(() {
              bookings = filtered;
              loading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              error = data['message'] ?? 'Unknown error';
              loading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            error = 'Server error: ${response.statusCode}';
            loading = false;
          });
        }
      }
    } catch (e) {
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
    switch (status.toLowerCase()) {
      case 'pickup':
        return Colors.orange.shade600;
      case 'completed':
        return Colors.green.shade600;
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return selectedTheme.primaryColor;
    }
  }

  IconData statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pickup':
        return Icons.directions_car;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  List<dynamic> get filteredBookings {
    if (selectedStatusFilter == null) {
      return bookings;
    }
    return bookings.where((booking) {
      final status = (booking['book_status'] ?? '').toString().toLowerCase();
      return status == selectedStatusFilter;
    }).toList();
  }

  Widget _buildHeader() {
    // Group bookings by status
    final Map<String, List<dynamic>> groupedBookings = {};
    for (var booking in bookings) {
      final status = (booking['book_status'] ?? '').toString().toLowerCase();
      if (!groupedBookings.containsKey(status)) {
        groupedBookings[status] = [];
      }
      groupedBookings[status]!.add(booking);
    }

    final totalBookings = bookings.length;
    final completedBookings = groupedBookings['completed']?.length ?? 0;
    final pickupBookings = groupedBookings['pickup']?.length ?? 0;
    final cancelledBookings = groupedBookings['cancelled']?.length ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [selectedTheme.primaryColor, selectedTheme.accentColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: selectedTheme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selectedTheme.buttonTextColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history,
                  color: selectedTheme.buttonTextColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SimpleTranslations.get(langCode, 'booking_history'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: selectedTheme.buttonTextColor,
                      ),
                    ),
                    Text(
                      SimpleTranslations.get(langCode, 'grouped_by_status'),
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedTheme.buttonTextColor.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    loading = true;
                  });
                  _loadLangAndBookings();
                },
                icon: Icon(Icons.refresh, color: selectedTheme.buttonTextColor),
                tooltip: SimpleTranslations.get(langCode, 'refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status group cards
          Row(
            children: [
              Expanded(
                child: _buildStatusGroupCard(
                  SimpleTranslations.get(langCode, 'pickup'),
                  pickupBookings.toString(),
                  Icons.directions_car,
                  Colors.orange.shade600,
                  'pickup',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusGroupCard(
                  SimpleTranslations.get(langCode, 'completed'),
                  completedBookings.toString(),
                  Icons.check_circle,
                  Colors.green.shade600,
                  'completed',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusGroupCard(
                  SimpleTranslations.get(langCode, 'cancelled'),
                  cancelledBookings.toString(),
                  Icons.cancel,
                  Colors.red.shade600,
                  'cancelled',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Total bookings summary
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: selectedTheme.buttonTextColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selectedTheme.buttonTextColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.list_alt,
                  color: selectedTheme.buttonTextColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${SimpleTranslations.get(langCode, 'total_bookings')}: ',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedTheme.buttonTextColor.withOpacity(0.9),
                  ),
                ),
                Text(
                  totalBookings.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: selectedTheme.buttonTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGroupCard(
    String label,
    String count,
    IconData icon,
    Color color,
    String statusFilter,
  ) {
    final isSelected = selectedStatusFilter == statusFilter;

    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle filter - if already selected, clear filter, otherwise set new filter
          selectedStatusFilter = isSelected ? null : statusFilter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedTheme.buttonTextColor.withOpacity(0.3)
              : selectedTheme.buttonTextColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? selectedTheme.buttonTextColor.withOpacity(0.6)
                : selectedTheme.buttonTextColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selectedTheme.buttonTextColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selectedTheme.buttonTextColor.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterIndicator() {
    if (selectedStatusFilter == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selectedTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list, color: selectedTheme.primaryColor, size: 16),
          const SizedBox(width: 8),
          Text(
            '${SimpleTranslations.get(langCode, 'filtered_by')}: ${translateStatus(selectedStatusFilter!)}',
            style: TextStyle(
              color: selectedTheme.primaryColor,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                selectedStatusFilter = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selectedTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: selectedTheme.buttonTextColor,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, int index) {
    final DateTime requestTime = DateTime.parse(booking['request_time']);
    final formattedTime =
        "${requestTime.hour.toString().padLeft(2, '0')}:${requestTime.minute.toString().padLeft(2, '0')}";
    final formattedDate = DateFormat('MMM dd, yyyy').format(requestTime);
    final formattedPrice = NumberFormat(
      '#,###',
    ).format(booking['payment_price']);

    final status = langCode.toLowerCase() == 'la'
        ? booking['bookla_status'] ?? ''
        : booking['book_status'] ?? '';

    final translatedStatus = translateStatus(status);
    final statusBgColor = statusColor(status);
    final statusIconData = statusIcon(status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            print('📲 Booking tapped: ${booking['book_id']}');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingConfirmPage(booking: booking),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Payment info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.payments,
                            color: Colors.green.shade600,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "₭ $formattedPrice",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Booking details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: selectedTheme.textColor.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  booking['passenger_id']?.toString() ??
                                      'Unknown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: selectedTheme.textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: selectedTheme.textColor.withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  color: selectedTheme.textColor.withOpacity(
                                    0.7,
                                  ),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: selectedTheme.textColor.withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: selectedTheme.textColor.withOpacity(
                                    0.7,
                                  ),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: statusBgColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIconData, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            translatedStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bottom row with booking ID and arrow
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 14,
                      color: selectedTheme.textColor.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ID: ${booking['book_id'] ?? 'N/A'}',
                      style: TextStyle(
                        color: selectedTheme.textColor.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: selectedTheme.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = selectedStatusFilter != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: selectedTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered ? Icons.filter_list_off : Icons.history,
              size: 64,
              color: selectedTheme.primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFiltered
                ? '${SimpleTranslations.get(langCode, 'no_bookings_filtered')}'
                : '${SimpleTranslations.get(langCode, 'no_bookings')}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: selectedTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? '${SimpleTranslations.get(langCode, 'no_bookings_for_status')}: ${translateStatus(selectedStatusFilter!)}'
                : '${SimpleTranslations.get(langCode, 'no_bookings_desc')}',
            style: TextStyle(
              fontSize: 14,
              color: selectedTheme.textColor.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (isFiltered) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedStatusFilter = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedTheme.primaryColor,
                foregroundColor: selectedTheme.buttonTextColor,
              ),
              child: Text(SimpleTranslations.get(langCode, 'clear_filter')),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: selectedTheme.backgroundColor,
      body: loading
          ? Container(
              color: selectedTheme.backgroundColor,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    selectedTheme.primaryColor,
                  ),
                ),
              ),
            )
          : error != null
          ? Container(
              color: selectedTheme.backgroundColor,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade400,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          loading = true;
                          error = null;
                        });
                        _loadLangAndBookings();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTheme.primaryColor,
                        foregroundColor: selectedTheme.buttonTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildHeader(),
                _buildFilterIndicator(),
                Expanded(
                  child: filteredBookings.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: filteredBookings.length,
                          itemBuilder: (context, index) {
                            return _buildBookingCard(
                              filteredBookings[index],
                              index,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
