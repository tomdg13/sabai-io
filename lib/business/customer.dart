// customer.dart
import 'package:flutter/material.dart';
import 'package:inventory/config/theme.dart';
import '../utils/simple_translations.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
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
          SimpleTranslations.get(langCode, 'customers') ?? 'Customers',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Text(
          'Customer Management Page',
          style: TextStyle(fontSize: 20, color: textColor),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new customer
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

