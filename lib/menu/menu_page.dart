import 'package:flutter/material.dart';
import 'package:kupcar/car/CarListPage.dart';
import 'package:kupcar/driver/DriverPage.dart' as driver_ctrl;
import 'package:kupcar/history/ProfilePage.dart' as profile_ctrl;
import 'package:kupcar/history/bookingListPage.dart' as booklist_ctrl;
import 'package:kupcar/history/MessagePage.dart' as message_ctrl;

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';

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
          _TabItem(t('my_car'), Icons.directions_car, const CarListPage()),
          _TabItem(t('setting'), Icons.settings, profile_ctrl.ProfilePage()),
        ];
    }
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
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('access_token');
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
            },
          ),
        ],
      ),
      body: tabs[_idx].widget ?? const SizedBox.shrink(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) {
          setState(() => _idx = i);
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
