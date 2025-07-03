import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kupcar/login/regiteruser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../l10n/app_localizations.dart';
import '../config/config.dart';
import '../utils/simple_translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedLangCode = prefs.getString('languageCode') ?? 'en';

  runApp(MyApp(initialLocale: Locale(savedLangCode)));
}

class MyApp extends StatefulWidget {
  final Locale initialLocale;
  const MyApp({super.key, required this.initialLocale});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  Future<void> _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login App',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('la')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginPage(
        key: ValueKey(_locale.languageCode),
        setLocale: _setLocale,
      ),
      builder: (context, child) {
        return KeyedSubtree(key: ValueKey(_locale.languageCode), child: child!);
      },
    );
  }
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
  String msg = '';
  String currecntl = 'en';

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
    userCtrl.text = prefs.getString('user') ?? '';
    passCtrl.text = prefs.getString('pass') ?? '';
    rememberMe = prefs.getBool('remember') ?? false;
    setState(() {});
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('user', userCtrl.text);
      await prefs.setString('pass', passCtrl.text);
      await prefs.setBool('remember', true);
    } else {
      await prefs.clear();
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
    await prefs.setString('access_token', token ?? '');

    if (code == '00' && token != null) {
      final role = _decodeRole(token);
      await _savePrefs();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/menu',
        arguments: {'role': role ?? 'unknown', 'token': token},
      );
    } else {
      final message =
          data['message'] ?? AppLocalizations.of(context)!.login_failed;

      setState(() => msg = message);
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context).languageCode;
    final activeStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    final inactiveStyle = TextStyle(
      color: Colors.white.withOpacity(0.6),
      fontWeight: FontWeight.normal,
      fontSize: 16,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_getText('loginTitle')),
        actions: [
          Row(
            children: [
              InkWell(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('languageCode', 'en');
                  widget.setLocale?.call(const Locale('en'));
                  setState(() => currecntl = 'en');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Text(
                    '🇺🇸',
                    style: currentLocale == 'en' ? activeStyle : inactiveStyle,
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('languageCode', 'la');
                  widget.setLocale?.call(const Locale('la'));
                  setState(() => currecntl = 'la');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Text(
                    '🇱🇦',
                    style: currentLocale == 'la' ? activeStyle : inactiveStyle,
                  ),
                ),
              ),
            ],
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
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: _getText('password')),
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
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterUserPage(),
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
          ],
        ),
      ),
    );
  }
}
