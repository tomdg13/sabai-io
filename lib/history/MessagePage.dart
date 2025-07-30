import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabaicub/config/theme.dart'; // Use main ThemeConfig
import '../utils/simple_translations.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({Key? key}) : super(key: key);

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme; // Use ThemeConfig default
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadLanguageAndMessages();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
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
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);

    switch (type) {
      case 'success':
        return Colors.green;
      case 'info':
        return primaryColor;
      case 'promotion':
        return Colors.orange;
      case 'warning':
        return Colors.amber;
      case 'error':
        return Colors.red;
      default:
        return primaryColor;
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
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? primaryColor.withOpacity(0.1)
              : primaryColor.withOpacity(0.3),
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
                                color: textColor,
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
                          color: textColor.withOpacity(0.7),
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
                        color: textColor.withOpacity(0.5),
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
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.message_outlined,
              size: 64,
              color: primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            SimpleTranslations.get(langCode, 'no_messages'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SimpleTranslations.get(langCode, 'no_messages_desc'),
            style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);

    return Container(
      color: backgroundColor,
      child: messages.isEmpty
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: buttonTextColor,
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
                                color: buttonTextColor,
                              ),
                            ),
                            Text(
                              '${messages.where((m) => !(m['isRead'] ?? true)).length} ${SimpleTranslations.get(langCode, 'unread')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: buttonTextColor.withOpacity(0.9),
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
                        icon: Icon(Icons.done_all, color: buttonTextColor),
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
