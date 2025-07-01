import 'package:flutter/material.dart';
import 'package:kupcar/driver/DriverPage.dart' as driver_ctrl;
import 'package:kupcar/history/ProfilePage.dart';
import 'package:kupcar/history/bookingListPage.dart' as booklist_ctrl;
import 'package:kupcar/history/bookingPage.dart' as book_ctrl;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';

class MenuPage extends StatefulWidget {
  final String role;

  const MenuPage({super.key, required this.role});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _TabItem {
  final String label;
  final IconData icon;
  final Widget? widget;
  final bool isSetting; // <-- Add this flag to track "setting" tab
  _TabItem(this.label, this.icon, this.widget, {this.isSetting = false});
}

class _MenuPageState extends State<MenuPage> {
  int _idx = 0;
  List<_TabItem> tabs = [];
  String langCodes = '';

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    langCodes = prefs.getString('languageCode') ?? 'en';
    debugPrint('Language code: $langCodes');
  }

  @override
  void initState() {
    super.initState();
    getLanguage().then((_) {
      setState(() {
        tabs = [_homeTab(), ..._getTabs(widget.role)];
      });
    });
  }

  _TabItem _homeTab() {
    return _TabItem(
      SimpleTranslations.get(langCodes, 'driver_dashboard'),
      Icons.home,
      booklist_ctrl.BookingListPage(),
    );
  }

  List<_TabItem> _getTabs(String role) {
    switch (role.toLowerCase()) {
      case 'user':
      default:
        return [
          _TabItem(
            SimpleTranslations.get(langCodes, 'history'),
            Icons.history,
            driver_ctrl.DriverPage(),
          ),
          _TabItem(
            SimpleTranslations.get(langCodes, 'user'),
            Icons.people,
            book_ctrl.BookingPage(),
          ),
          _TabItem(
            SimpleTranslations.get(langCodes, 'notification'),
            Icons.car_repair,
            book_ctrl.BookingPage(),
          ),
          _TabItem(
            SimpleTranslations.get(langCodes, 'setting'),
            Icons.settings,
            null,
            isSetting: true, // ✅ Mark this as the setting tab
          ),
        ];
    }
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage()));
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_idx].label),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: SimpleTranslations.get(langCodes, 'logout'),
            onPressed: _logout,
          ),
        ],
      ),
      body: tabs[_idx].widget ?? const SizedBox.shrink(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) {
          if (tabs[i].isSetting) {
            _openSettings(); // go to ProfilePage
          } else {
            setState(() => _idx = i);
          }
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: tabs
            .map(
              (t) =>
                  BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
            )
            .toList(),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
