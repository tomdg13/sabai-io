import 'package:flutter/material.dart';
import 'package:sabaicub/login/verifyOtp.dart';
import 'package:sabaicub/login/VerifyOtpforgetpassPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../l10n/app_localizations.dart';
import '../config/config.dart';
import '../utils/simple_translations.dart';
// import 'package:Sabaikee/login/verifyOtp.dart';

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
  bool _obscurePassword = true; // Added for password visibility toggle
  String msg = '';
  String currecntl = 'en';

  final Map<String, String> languages = {'en': '🇺🇸', 'la': '🇱🇦'};

  String _getText(String key) {
    return SimpleTranslations.get(currecntl, key);
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLangCode = prefs.getString('languageCode') ?? 'en';
    userCtrl.text = prefs.getString('user') ?? '';
    rememberMe = prefs.getBool('remember') ?? false;
    if (rememberMe) {
      passCtrl.text = prefs.getString('pass') ?? '';
    } else {
      passCtrl.text = '';
    }

    setState(() {
      currecntl = savedLangCode;
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

    // ✅ Use loginDriver endpoint here
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getText('loginTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: currecntl,
              dropdownColor: Colors.blue,
              underline: const SizedBox(),
              iconEnabledColor: Colors.white,
              items: languages.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: const TextStyle(color: Colors.white, fontSize: 28),
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
              decoration: InputDecoration(labelText: _getText('phone')),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: _getText('password'),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
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
                  onChanged: (v) => setState(() => rememberMe = v!),
                ),
                Text(_getText('rememberMe')),
              ],
            ),
            const SizedBox(height: 12),
            loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: login,
                      child: Text(_getText('login')),
                    ),
                  ),
            if (msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(msg, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            // Register (left) and Forget Password (right) buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Register Button (left)
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
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                // Separator
                const Text(
                  ' | ',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                // Forget Password Button (right)
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
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
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
