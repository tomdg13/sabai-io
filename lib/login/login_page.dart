import 'package:flutter/material.dart';
import 'package:sabaicub/login/verifyOtp.dart';
import 'package:sabaicub/login/VerifyOtpforgetpassPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../l10n/app_localizations.dart';
import '../config/config.dart';
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

class LoginPage extends StatefulWidget {
  final Future<void> Function(Locale)? setLocale;
  const LoginPage({super.key, this.setLocale});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool rememberMe = false;
  bool loading = false;
  bool _obscurePassword = true;
  String msg = '';
  String currecntl = 'en';
  String currentTheme = 'green'; // Default theme

  final Map<String, String> languages = {'en': '🇺🇸', 'la': '🇱🇦'};

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

  String _getText(String key) {
    return SimpleTranslations.get(currecntl, key);
  }

  AppTheme get selectedTheme => themes[currentTheme] ?? themes['green']!;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLangCode = prefs.getString('languageCode') ?? 'en';
    final savedTheme = prefs.getString('selectedTheme') ?? 'green';

    userCtrl.text = prefs.getString('user') ?? '';
    rememberMe = prefs.getBool('remember') ?? false;
    if (rememberMe) {
      passCtrl.text = prefs.getString('pass') ?? '';
    } else {
      passCtrl.text = '';
    }

    setState(() {
      currecntl = savedLangCode;
      currentTheme = savedTheme;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', userCtrl.text);
    await prefs.setBool('remember', rememberMe);
    if (rememberMe) {
      await prefs.setString('pass', passCtrl.text);
    } else {
      await prefs.remove('pass');
    }
  }

  Future<void> _saveTheme(String themeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTheme', themeKey);
  }

  String? _decodeRole(String token) {
    try {
      final parts = token.split('.');
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return json.decode(payload)['role']?.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  Future<void> login() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loading = true;
      msg = '';
    });

    final url = AppConfig.api('/api/auth/loginDriver');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userName': userCtrl.text.trim(),
        'password': passCtrl.text.trim(),
      }),
    );

    final data = jsonDecode(response.body);
    final code = data['responseCode'];
    final token = data['data']?['access_token'];

    if (code == '00' && token != null) {
      await prefs.setString('access_token', token);
      final role = _decodeRole(token);
      await _savePrefs();

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/menu',
        arguments: {'role': role ?? 'unknown', 'token': token},
      );
    } else {
      final errorMessage =
          data['message'] ?? AppLocalizations.of(context)!.login_failed;
      setState(() => msg = errorMessage);
    }

    setState(() => loading = false);
  }

  void _showThemeSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Theme',
            style: TextStyle(color: selectedTheme.textColor),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: themes.length,
              itemBuilder: (context, index) {
                final themeKey = themes.keys.elementAt(index);
                final theme = themes[themeKey]!;
                final isSelected = currentTheme == themeKey;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.accentColor, width: 2),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: theme.buttonTextColor,
                              size: 20,
                            )
                          : null,
                    ),
                    title: Text(
                      theme.name,
                      style: TextStyle(
                        color: selectedTheme.textColor,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.radio_button_checked,
                            color: theme.primaryColor,
                          )
                        : Icon(
                            Icons.radio_button_unchecked,
                            color: Colors.grey,
                          ),
                    onTap: () async {
                      setState(() {
                        currentTheme = themeKey;
                      });
                      await _saveTheme(themeKey);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: selectedTheme.primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: selectedTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: selectedTheme.primaryColor,
        foregroundColor: selectedTheme.buttonTextColor,
        title: Text(
          _getText('loginTitle'),
          style: TextStyle(color: selectedTheme.buttonTextColor),
        ),
        actions: [
          // Theme selector button
          IconButton(
            icon: Icon(Icons.palette, color: selectedTheme.buttonTextColor),
            onPressed: _showThemeSelector,
            tooltip: 'Select Theme',
          ),
          // Language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: currecntl,
              dropdownColor: selectedTheme.primaryColor,
              underline: const SizedBox(),
              iconEnabledColor: selectedTheme.buttonTextColor,
              items: languages.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: selectedTheme.buttonTextColor,
                      fontSize: 28,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newLang) async {
                if (newLang == null) return;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('languageCode', newLang);
                widget.setLocale?.call(Locale(newLang));
                setState(() => currecntl = newLang);
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: userCtrl,
              style: TextStyle(color: selectedTheme.textColor),
              decoration: InputDecoration(
                labelText: _getText('phone'),
                labelStyle: TextStyle(color: selectedTheme.primaryColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: selectedTheme.primaryColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: selectedTheme.primaryColor.withOpacity(0.5),
                  ),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: _obscurePassword,
              style: TextStyle(color: selectedTheme.textColor),
              decoration: InputDecoration(
                labelText: _getText('password'),
                labelStyle: TextStyle(color: selectedTheme.primaryColor),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: selectedTheme.primaryColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: selectedTheme.primaryColor.withOpacity(0.5),
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: selectedTheme.primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  activeColor: selectedTheme.primaryColor,
                  onChanged: (v) => setState(() => rememberMe = v!),
                ),
                Text(
                  _getText('rememberMe'),
                  style: TextStyle(color: selectedTheme.textColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            loading
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      selectedTheme.primaryColor,
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTheme.primaryColor,
                        foregroundColor: selectedTheme.buttonTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: login,
                      child: Text(
                        _getText('login'),
                        style: TextStyle(
                          color: selectedTheme.buttonTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
            if (msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(msg, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            // Register and Forget Password buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyOtpPage(),
                      ),
                    );
                  },
                  child: Text(
                    _getText('register'),
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedTheme.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' | ',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedTheme.textColor.withOpacity(0.6),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyOtpforgetpassPage(),
                      ),
                    );
                  },
                  child: Text(
                    _getText('forget password'),
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedTheme.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
