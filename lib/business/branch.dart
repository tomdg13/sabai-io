// branch.dart
import 'package:flutter/material.dart';
import 'package:sabaicub/config/theme.dart';
import '../utils/simple_translations.dart';

class BranchPage extends StatefulWidget {
  const BranchPage({super.key});

  @override
  State<BranchPage> createState() => _BranchPageState();
}

class _BranchPageState extends State<BranchPage> {
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
          SimpleTranslations.get(langCode, 'branches') ?? 'Branches',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Text(
          'Branch Management Page',
          style: TextStyle(fontSize: 20, color: textColor),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new branch
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

