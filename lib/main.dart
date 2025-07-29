import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login/login_page.dart';
import 'menu/menu_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String currentTheme = 'green'; // Default theme
  Locale currentLocale = const Locale('en');

  // Theme colors mapping (same as in LoginPage)
  final Map<String, Map<String, Color>> themeColors = {
    'green': {
      'primary': Colors.green,
      'accent': Colors.green,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'blue': {
      'primary': Colors.blue,
      'accent': Colors.blue,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'purple': {
      'primary': Colors.purple,
      'accent': Colors.purple,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'orange': {
      'primary': Colors.orange,
      'accent': Colors.orange,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'teal': {
      'primary': Colors.teal,
      'accent': Colors.teal,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'dark': {
      'primary': Colors.grey.shade800,
      'accent': Colors.grey.shade800,
      'background': Colors.grey.shade100,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('selectedTheme') ?? 'green';
    final savedLangCode = prefs.getString('languageCode') ?? 'en';

    setState(() {
      currentTheme = savedTheme;
      currentLocale = Locale(savedLangCode);
    });
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    setState(() {
      currentLocale = locale;
    });
  }

  ThemeData _buildTheme() {
    final colors = themeColors[currentTheme] ?? themeColors['green']!;
    final primaryColor = colors['primary']!;
    final buttonTextColor = colors['buttonText']!;

    return ThemeData(
      primarySwatch: _createMaterialColor(primaryColor),
      primaryColor: primaryColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 2,
        titleTextStyle: TextStyle(
          color: buttonTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: buttonTextColor),
        actionsIconTheme: IconThemeData(color: buttonTextColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: buttonTextColor,
          textStyle: const TextStyle(fontSize: 16),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.all(primaryColor),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primaryColor),
      scaffoldBackgroundColor: colors['background'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
    );
  }

  // Helper method to create MaterialColor from Color
  MaterialColor _createMaterialColor(Color color) {
    final List<double> strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Main',
      theme: _buildTheme(),
      locale: currentLocale,
      initialRoute: '/',
      routes: {
        '/': (ctx) => LoginPage(setLocale: setLocale),
        '/menu': (ctx) {
          final args =
              ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
          final role = args?['role'] ?? 'customer';

          return MenuPage(role: role);
        },
      },
    );
  }
}
