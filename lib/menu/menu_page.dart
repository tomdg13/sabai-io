import 'package:flutter/material.dart';
// import 'package:sabaicub/car/CarListPage.dart';
import 'package:sabaicub/car/mycar.dart' as mycar_ctrl;
import 'package:sabaicub/driver/DriverPage.dart' as driver_ctrl;
import 'package:sabaicub/history/ProfilePage.dart' as profile_ctrl;
import 'package:sabaicub/history/bookingListPage.dart' as booklist_ctrl;
import 'package:sabaicub/history/MessagePage.dart' as message_ctrl;
// import 'package:sabaicub/car/CarListPage.dart';
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

class MenuPage extends StatefulWidget {
  final String role;
  final int tabIndex;

  const MenuPage({Key? key, required this.role, this.tabIndex = 0})
    : super(key: key);

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _TabItem {
  final String label;
  final IconData icon;
  final Widget? widget;
  _TabItem(this.label, this.icon, this.widget);
}

class _MenuPageState extends State<MenuPage> {
  int _idx = 0;
  List<_TabItem> tabs = [];
  String langCodes = '';
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

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    langCodes = prefs.getString('languageCode') ?? 'en';
    debugPrint('Language code: $langCodes');
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

  @override
  void initState() {
    super.initState();
    _loadTheme();
    getLanguage().then((_) {
      setState(() {
        tabs = [_homeTab(), ..._getTabs(widget.role)];
        _idx = widget.tabIndex;
      });
    });
  }

  _TabItem _homeTab() {
    return _TabItem(
      SimpleTranslations.get(langCodes, 'history'),
      Icons.history,
      booklist_ctrl.BookingListPage(),
    );
  }

  List<_TabItem> _getTabs(String role) {
    final t = (String key) => SimpleTranslations.get(langCodes, key);

    switch (role.toLowerCase()) {
      case 'driver':
      default:
        return [
          _TabItem(t('driver_dashboard'), Icons.home, driver_ctrl.DriverPage()),
          _TabItem(t('message'), Icons.message, message_ctrl.MessagePage()),
          // _TabItem(t('my_car'), Icons.directions_car, CarListPage()),
          // _TabItem(t('my_car'), Icons.directions_car, const CarListPage()),
          _TabItem(t('car'), Icons.directions_car, mycar_ctrl.MyCarPage()),
          _TabItem(t('setting'), Icons.settings, profile_ctrl.ProfilePage()),
        ];
    }
  }

  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: selectedTheme.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: selectedTheme.primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                SimpleTranslations.get(langCodes, 'logout'),
                style: TextStyle(
                  color: selectedTheme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            SimpleTranslations.get(langCodes, 'logout_confirm'),
            style: TextStyle(color: selectedTheme.textColor, fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                SimpleTranslations.get(langCodes, 'cancel'),
                style: TextStyle(
                  color: selectedTheme.textColor.withOpacity(0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('access_token');
                if (!mounted) return;
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (r) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedTheme.primaryColor,
                foregroundColor: selectedTheme.buttonTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(SimpleTranslations.get(langCodes, 'logout')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: selectedTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: selectedTheme.primaryColor,
          foregroundColor: selectedTheme.buttonTextColor,
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              selectedTheme.primaryColor,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: selectedTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          tabs[_idx].label,
          style: TextStyle(
            color: selectedTheme.buttonTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: selectedTheme.primaryColor,
        foregroundColor: selectedTheme.buttonTextColor,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selectedTheme.buttonTextColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.logout,
                  color: selectedTheme.buttonTextColor,
                  size: 20,
                ),
              ),
              tooltip: SimpleTranslations.get(langCodes, 'logout'),
              onPressed: _showLogoutDialog,
            ),
          ),
        ],
      ),
      body: Container(
        color: selectedTheme.backgroundColor,
        child: tabs[_idx].widget ?? const SizedBox.shrink(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: selectedTheme.primaryColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _idx,
          onTap: (i) {
            setState(() => _idx = i);
          },
          selectedItemColor: selectedTheme.primaryColor,
          unselectedItemColor: selectedTheme.textColor.withOpacity(0.5),
          backgroundColor: selectedTheme.backgroundColor,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: selectedTheme.primaryColor,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: selectedTheme.textColor.withOpacity(0.5),
          ),
          items: tabs
              .map(
                (t) => BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Icon(
                      t.icon,
                      size: tabs.indexOf(t) == _idx ? 26 : 24,
                    ),
                  ),
                  activeIcon: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: selectedTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      t.icon,
                      size: 26,
                      color: selectedTheme.primaryColor,
                    ),
                  ),
                  label: t.label,
                ),
              )
              .toList(),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      ),
    );
  }
}
