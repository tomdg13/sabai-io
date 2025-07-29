import 'package:flutter/material.dart';
// import 'package:sabaicub/car/CarListPage.dart';
import 'package:sabaicub/car/mycar.dart' as mycar_ctrl;
import 'package:sabaicub/driver/DriverPage.dart' as driver_ctrl;
import 'package:sabaicub/history/ProfilePage.dart' as profile_ctrl;
import 'package:sabaicub/history/bookingListPage.dart' as booklist_ctrl;
import 'package:sabaicub/history/MessagePage.dart' as message_ctrl;
// import 'package:sabaicub/car/CarListPage.dart';
import 'package:sabaicub/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';

class MenuPage extends StatefulWidget {
  final String role;
  final int tabIndex;
  final Function(String)? setTheme;
  final String Function()? getCurrentTheme;

  const MenuPage({
    Key? key,
    required this.role,
    this.tabIndex = 0,
    this.setTheme,
    this.getCurrentTheme,
  }) : super(key: key);

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
  String currentTheme = ThemeConfig.defaultTheme;

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    langCodes = prefs.getString('languageCode') ?? 'en';
    debugPrint('Language code: $langCodes');
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
          _TabItem(t('setting'), Icons.settings, _buildProfilePage()),
        ];
    }
  }

  // Enhanced ProfilePage with theme selector
  Widget _buildProfilePage() {
    return profile_ctrl.ProfilePage();
  }

  // ignore: unused_element
  Widget _buildThemeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeConfig.getBackgroundColor(currentTheme),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.palette,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  SimpleTranslations.get(langCodes, 'theme'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getTextColor(currentTheme),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...ThemeConfig.getAvailableThemes().map((themeName) {
            return ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: ThemeConfig.getPrimaryColor(themeName),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentTheme == themeName
                        ? ThemeConfig.getPrimaryColor(currentTheme)
                        : Colors.grey.shade300,
                    width: currentTheme == themeName ? 3 : 1,
                  ),
                ),
                child: currentTheme == themeName
                    ? Icon(
                        Icons.check,
                        color: ThemeConfig.getButtonTextColor(themeName),
                        size: 16,
                      )
                    : null,
              ),
              title: Text(
                ThemeConfig.getThemeDisplayName(themeName),
                style: TextStyle(
                  color: ThemeConfig.getTextColor(currentTheme),
                  fontWeight: currentTheme == themeName
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                ThemeConfig.getThemeCategory(themeName),
                style: TextStyle(
                  color: ThemeConfig.getTextColor(
                    currentTheme,
                  ).withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              trailing: currentTheme == themeName
                  ? Icon(
                      Icons.check_circle,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                    )
                  : null,
              onTap: () async {
                if (widget.setTheme != null) {
                  await widget.setTheme!(themeName);
                }
                setState(() {
                  currentTheme = themeName;
                });
              },
            );
          }).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout,
                color: ThemeConfig.getPrimaryColor(currentTheme),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                SimpleTranslations.get(langCodes, 'logout'),
                style: TextStyle(
                  color: ThemeConfig.getTextColor(currentTheme),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            SimpleTranslations.get(langCodes, 'logout_confirm'),
            style: TextStyle(
              color: ThemeConfig.getTextColor(currentTheme),
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                SimpleTranslations.get(langCodes, 'cancel'),
                style: TextStyle(
                  color: ThemeConfig.getTextColor(
                    currentTheme,
                  ).withOpacity(0.7),
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
                backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
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

  Future<void> _showThemeSelector() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: ThemeConfig.getBackgroundColor(currentTheme),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.palette,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select Theme',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getTextColor(currentTheme),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  children: ThemeConfig.getAvailableThemes().map((themeName) {
                    return ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: ThemeConfig.getPrimaryColor(themeName),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: currentTheme == themeName
                                ? ThemeConfig.getPrimaryColor(currentTheme)
                                : Colors.grey.shade300,
                            width: currentTheme == themeName ? 3 : 1,
                          ),
                        ),
                        child: currentTheme == themeName
                            ? Icon(
                                Icons.check,
                                color: ThemeConfig.getButtonTextColor(
                                  themeName,
                                ),
                                size: 18,
                              )
                            : null,
                      ),
                      title: Text(
                        ThemeConfig.getThemeDisplayName(themeName),
                        style: TextStyle(
                          color: ThemeConfig.getTextColor(currentTheme),
                          fontWeight: currentTheme == themeName
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        ThemeConfig.getThemeCategory(themeName),
                        style: TextStyle(
                          color: ThemeConfig.getTextColor(
                            currentTheme,
                          ).withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                      trailing: currentTheme == themeName
                          ? Icon(
                              Icons.check_circle,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            )
                          : null,
                      onTap: () async {
                        if (widget.setTheme != null) {
                          await widget.setTheme!(themeName);
                        }
                        setState(() {
                          currentTheme = themeName;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return Scaffold(
        backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          elevation: 0,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              ThemeConfig.getPrimaryColor(currentTheme),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
      appBar: AppBar(
        title: Text(
          tabs[_idx].label,
          style: TextStyle(
            color: ThemeConfig.getButtonTextColor(currentTheme),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          // Theme selector button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeConfig.getButtonTextColor(
                    currentTheme,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.palette,
                  color: ThemeConfig.getButtonTextColor(currentTheme),
                  size: 20,
                ),
              ),
              tooltip: 'Change Theme',
              onPressed: _showThemeSelector,
            ),
          ),
          // Logout button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeConfig.getButtonTextColor(
                    currentTheme,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.logout,
                  color: ThemeConfig.getButtonTextColor(currentTheme),
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
        color: ThemeConfig.getBackgroundColor(currentTheme),
        child: tabs[_idx].widget ?? const SizedBox.shrink(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
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
          selectedItemColor: ThemeConfig.getPrimaryColor(currentTheme),
          unselectedItemColor: ThemeConfig.getTextColor(
            currentTheme,
          ).withOpacity(0.5),
          backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: ThemeConfig.getTextColor(currentTheme).withOpacity(0.5),
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
                      color: ThemeConfig.getPrimaryColor(
                        currentTheme,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      t.icon,
                      size: 26,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
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
