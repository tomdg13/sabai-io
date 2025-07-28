import 'package:flutter/material.dart';
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

class MessagePage extends StatefulWidget {
  const MessagePage({Key? key}) : super(key: key);

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  String langCode = 'en';
  String currentTheme = 'green'; // Default theme
  List<Map<String, dynamic>> messages = [];

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
    _loadLanguageAndMessages();
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

  Future<void> _loadLanguageAndMessages() async {
    final prefs = await SharedPreferences.getInstance();
    langCode = prefs.getString('languageCode') ?? 'en';

    // Load translated messages with more variety
    setState(() {
      messages = [
        {
          "icon": Icons.notifications_active_outlined,
          "title": SimpleTranslations.get(langCode, 'booking_confirmed'),
          "body": SimpleTranslations.get(langCode, 'booking_accepted'),
          "time": "10:30 AM",
          "type": "success",
          "isRead": false,
        },
        {
          "icon": Icons.directions_car_filled,
          "title": SimpleTranslations.get(langCode, 'driver_arrived'),
          "body": SimpleTranslations.get(langCode, 'driver_at_pickup'),
          "time": "10:40 AM",
          "type": "info",
          "isRead": true,
        },
        {
          "icon": Icons.payment,
          "title": SimpleTranslations.get(langCode, 'payment_completed'),
          "body": SimpleTranslations.get(langCode, 'payment_success'),
          "time": "10:50 AM",
          "type": "success",
          "isRead": true,
        },
        {
          "icon": Icons.star_rate,
          "title": SimpleTranslations.get(langCode, 'rate_trip'),
          "body": SimpleTranslations.get(langCode, 'please_rate'),
          "time": "11:00 AM",
          "type": "info",
          "isRead": false,
        },
        {
          "icon": Icons.local_offer,
          "title": SimpleTranslations.get(langCode, 'special_offer'),
          "body": SimpleTranslations.get(langCode, 'discount_available'),
          "time": "Yesterday",
          "type": "promotion",
          "isRead": true,
        },
      ];
    });
  }

  Color _getMessageTypeColor(String type) {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'info':
        return selectedTheme.primaryColor;
      case 'promotion':
        return Colors.orange;
      case 'warning':
        return Colors.amber;
      case 'error':
        return Colors.red;
      default:
        return selectedTheme.primaryColor;
    }
  }

  IconData _getMessageTypeIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline;
      case 'info':
        return Icons.info_outline;
      case 'promotion':
        return Icons.local_offer_outlined;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.message_outlined;
    }
  }

  Widget _buildMessageCard(Map<String, dynamic> message, int index) {
    final messageColor = _getMessageTypeColor(message['type'] ?? 'info');
    final isRead = message['isRead'] ?? true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: selectedTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? selectedTheme.primaryColor.withOpacity(0.1)
              : selectedTheme.primaryColor.withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: messageColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle message tap
            setState(() {
              messages[index]['isRead'] = true;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Message Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: messageColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: messageColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(message['icon'], size: 24, color: messageColor),
                ),

                const SizedBox(width: 16),

                // Message Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: selectedTheme.textColor,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: messageColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message['body'],
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedTheme.textColor.withOpacity(0.7),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Time and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message['time'],
                      style: TextStyle(
                        color: selectedTheme.textColor.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      _getMessageTypeIcon(message['type'] ?? 'info'),
                      size: 16,
                      color: messageColor.withOpacity(0.6),
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
              Icons.message_outlined,
              size: 64,
              color: selectedTheme.primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            SimpleTranslations.get(langCode, 'no_messages'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: selectedTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SimpleTranslations.get(langCode, 'no_messages_desc'),
            style: TextStyle(
              fontSize: 14,
              color: selectedTheme.textColor.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: selectedTheme.backgroundColor,
      child: messages.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  selectedTheme.primaryColor,
                ),
              ),
            )
          : Column(
              children: [
                // Header with summary
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        selectedTheme.primaryColor,
                        selectedTheme.accentColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: selectedTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: selectedTheme.buttonTextColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              SimpleTranslations.get(langCode, 'notifications'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: selectedTheme.buttonTextColor,
                              ),
                            ),
                            Text(
                              '${messages.where((m) => !(m['isRead'] ?? true)).length} ${SimpleTranslations.get(langCode, 'unread')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: selectedTheme.buttonTextColor
                                    .withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // Mark all as read
                          setState(() {
                            for (var message in messages) {
                              message['isRead'] = true;
                            }
                          });
                        },
                        icon: Icon(
                          Icons.done_all,
                          color: selectedTheme.buttonTextColor,
                        ),
                        tooltip: SimpleTranslations.get(
                          langCode,
                          'mark_all_read',
                        ),
                      ),
                    ],
                  ),
                ),

                // Messages List
                Expanded(
                  child: messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageCard(messages[index], index);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
