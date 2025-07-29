import 'package:flutter/material.dart';
import 'package:sabaicub/login/verifyOtp.dart';
import 'package:sabaicub/login/VerifyOtpforgetpassPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/config.dart';
import '../config/theme.dart';
import '../utils/simple_translations.dart';

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
  String currentTheme = ThemeConfig.defaultTheme;

  final Map<String, String> languages = {'en': '🇺🇸', 'la': '🇱🇦'};

  String _getText(String key) {
    return SimpleTranslations.get(currecntl, key);
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload theme when page becomes visible
    _reloadTheme();
  }

  Future<void> _reloadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    if (mounted && currentTheme != savedTheme) {
      setState(() {
        currentTheme = savedTheme;
      });
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLangCode = prefs.getString('languageCode') ?? 'en';
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;

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

    setState(() {
      currentTheme = themeKey;
    });
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
      final errorMessage = data['message'] ?? _getText('login_failed');
      setState(() => msg = errorMessage);
    }

    setState(() => loading = false);
  }

  void _showThemeSelector() {
    final availableThemes = ThemeConfig.getAvailableThemes();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Select Theme',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: availableThemes.length,
              itemBuilder: (context, index) {
                return _buildThemeColorTile(availableThemes[index]);
              },
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(
                  currentTheme,
                ).withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeColorTile(String themeKey) {
    final isSelected = currentTheme == themeKey;
    final primaryColor = ThemeConfig.getPrimaryColor(themeKey);
    final buttonTextColor = ThemeConfig.getButtonTextColor(themeKey);

    return GestureDetector(
      onTap: () async {
        await _saveTheme(themeKey);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isSelected
            ? Icon(Icons.check_circle, color: buttonTextColor, size: 28)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors using ThemeConfig
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        elevation: 2,
        title: Text(
          _getText('loginTitle'),
          style: TextStyle(color: buttonTextColor, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Theme selector button
          IconButton(
            icon: Icon(Icons.palette, color: buttonTextColor),
            onPressed: _showThemeSelector,
            tooltip: 'Select Theme',
          ),
          // Language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: currecntl,
              dropdownColor: primaryColor,
              underline: const SizedBox(),
              iconEnabledColor: buttonTextColor,
              items: languages.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: TextStyle(color: buttonTextColor, fontSize: 28),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundColor, primaryColor.withOpacity(0.05)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // App logo/title area
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(Icons.local_taxi, size: 64, color: primaryColor),
              ),

              const SizedBox(height: 40),

              // Phone input
              TextField(
                controller: userCtrl,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  labelText: _getText('phone'),
                  labelStyle: TextStyle(color: primaryColor),
                  prefixIcon: Icon(Icons.phone, color: primaryColor),
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),

              // Password input
              TextField(
                controller: passCtrl,
                obscureText: _obscurePassword,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  labelText: _getText('password'),
                  labelStyle: TextStyle(color: primaryColor),
                  prefixIcon: Icon(Icons.lock, color: primaryColor),
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Remember me checkbox
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    activeColor: primaryColor,
                    onChanged: (v) => setState(() => rememberMe = v!),
                  ),
                  Text(
                    _getText('rememberMe'),
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Login button
              loading
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: buttonTextColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: login,
                          child: Text(
                            _getText('login'),
                            style: TextStyle(
                              color: buttonTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

              // Error message
              if (msg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            msg,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

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
                        fontSize: 14,
                        color: primaryColor,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    ' | ',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.6),
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
                        fontSize: 14,
                        color: primaryColor,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
