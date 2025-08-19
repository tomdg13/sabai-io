// vendor.dart
import 'package:flutter/material.dart';
import 'package:sabaicub/config/theme.dart';
import '../utils/simple_translations.dart';

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});

  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  String currentTheme = ThemeConfig.defaultTheme;
  String langCode = 'en';

  @override
  Widget build(BuildContext context) {
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          SimpleTranslations.get(langCode, 'vendors') ?? 'Vendors',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Text(
          'Vendor Management Page',
          style: TextStyle(fontSize: 20, color: textColor),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new vendor
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

