import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory/business/ApprovalPage.dart';
import 'package:inventory/business/ListTerminalPage.dart';
import 'package:inventory/monitor/ProductPage.dart';
import 'package:inventory/monitor/StockPage.dart';
import 'package:inventory/monitor/ExpirePage.dart' show ExpirePage;
import 'package:inventory/monitor/locationPage.dart';
import 'package:inventory/report/StoreReportPage.dart' show StoreReportPage;
import 'package:inventory/upload/SettlementViewPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../utils/simple_translations.dart';

class MenuHomePage extends StatefulWidget {
  const MenuHomePage({Key? key}) : super(key: key);

  @override
  State<MenuHomePage> createState() => _MenuHomePageState();
}

class _MenuHomePageState extends State<MenuHomePage> {
  String selectedLanguage = 'English';
  String selectedTheme = ThemeConfig.defaultTheme;
  String currentTheme = ThemeConfig.defaultTheme;
  bool isLoading = true;
  
  String _langCode = 'en';
  Color get _primaryColor => Theme.of(context).primaryColor;

  final List<String> languages = ['English', 'Lao'];
  List<String> get themes => ThemeConfig.getAvailableThemes();

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadThemeIfChanged();
  }

  // Get responsive layout parameters
  bool get _isWebDesktop => kIsWeb && MediaQuery.of(context).size.width > 800;
  bool get _isTablet => MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 800;
  
  int get _crossAxisCount {
    if (_isWebDesktop) return 5;
    if (_isTablet) return 3;
    return 3; // Changed to 3 columns for mobile
  }
  
  double get _childAspectRatio {
    if (_isWebDesktop) return 1.1;
    if (_isTablet) return 1.0;
    return 0.8; // Reduced to make items taller on mobile with 3 columns
  }
  
  double get _maxWidth {
    if (_isWebDesktop) return 1200;
    return double.infinity;
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      final validTheme = ThemeConfig.isValidTheme(savedTheme) ? savedTheme : ThemeConfig.defaultTheme;

      final savedLanguage = prefs.getString('selectedLanguage') ?? 'English';
      final validLanguage = languages.contains(savedLanguage) ? savedLanguage : 'English';

      _langCode = prefs.getString('languageCode') ?? 'en';

      if (mounted) {
        setState(() {
          selectedTheme = validTheme;
          currentTheme = validTheme;
          selectedLanguage = validLanguage;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() {
          selectedTheme = ThemeConfig.defaultTheme;
          currentTheme = ThemeConfig.defaultTheme;
          selectedLanguage = 'English';
          _langCode = 'en';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _reloadThemeIfChanged() async {
    if (isLoading) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;

      if (mounted && currentTheme != savedTheme) {
        setState(() {
          currentTheme = savedTheme;
          selectedTheme = savedTheme;
        });
      }
    } catch (e) {
      debugPrint('Error reloading theme: $e');
    }
  }

  Future<void> _saveTheme(String theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedTheme', theme);

      if (mounted) {
        setState(() {
          selectedTheme = theme;
          currentTheme = theme;
        });
      }
    } catch (e) {
      debugPrint('Error saving theme: $e');
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'error_save_theme'));
    }
  }

  Future<void> _saveLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedLanguage', language);

      String langCode = language == 'Lao' ? 'la' : 'en';
      await prefs.setString('languageCode', langCode);
      
      if (mounted) {
        setState(() {
          selectedLanguage = language;
          _langCode = langCode;
        });
      }
    } catch (e) {
      debugPrint('Error saving language: $e');
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'error_save_language'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      // Add drawer for web if needed
      drawer: _isWebDesktop ? null : _buildDrawer(),
    );
  }

  Widget _buildBody() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: _maxWidth),
        child: Padding(
          padding: EdgeInsets.all(_isWebDesktop ? 24.0 : 16.0),
          child: Column(
            children: [
              // Add welcome section for web
              if (_isWebDesktop) _buildWelcomeSection(),
              Expanded(child: _buildGridView()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SimpleTranslations.get(_langCode, 'welcome_inventory'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SimpleTranslations.get(_langCode, 'inventory_description'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildGridView() {
  return GridView.count(
    crossAxisCount: _crossAxisCount,
    crossAxisSpacing: _isWebDesktop ? 24 : 12,
    mainAxisSpacing: _isWebDesktop ? 24 : 12,
    childAspectRatio: _childAspectRatio,
    children: [
      _buildGridItem(
        icon: Icons.storefront, // Approval
        title: SimpleTranslations.get(_langCode, 'Store'),
        color: const Color.fromARGB(255, 211, 23, 198),
        onTap: _navigateToStoreReportService,
      ),
      _buildGridItem(
        icon: Icons.library_add_check, // Approval
        title: SimpleTranslations.get(_langCode, 'Approve'),
        color: Colors.green,
        onTap: _navigateToApprovePage,
      ),
      _buildGridItem(
        icon: Icons.computer, // Terminal
        title: SimpleTranslations.get(_langCode, 'Terminal'),
        color: Colors.blue,
        onTap: _navigateToTerminalPage,
      ),
      _buildGridItem(
        icon: Icons.schedule, // Expiry
        title: SimpleTranslations.get(_langCode, 'expiry'),
        color: Colors.red,
        onTap: _navigateToExpiryPage,
      ),
      _buildGridItem(
        icon: Icons.inventory_2, // Stock
        title: SimpleTranslations.get(_langCode, 'stock'),
        color: Colors.orange,
        onTap: _navigateToStockPage,
      ),
      _buildGridItem(
        icon: Icons.location_on, // Location
        title: SimpleTranslations.get(_langCode, 'location'),
        color: Colors.teal,
        onTap: _navigateToLocationPage,
      ),
      _buildGridItem(
        icon: Icons.shopping_bag, // Product
        title: SimpleTranslations.get(_langCode, 'product'),
        color: Colors.amber.shade700,
        onTap: _navigateToProductsPage,
      ),
      _buildGridItem(
        icon: Icons.account_balance_wallet, // Settlement
        title: SimpleTranslations.get(_langCode, 'Settle'),
        color: Colors.indigo,
        onTap: _navigateToSettlementViewPage,
      ),
    ],
  );
}

  Widget _buildGridItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isLargeScreen = _isWebDesktop || _isTablet;
    
    return Card(
      elevation: _isWebDesktop ? 4 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16), // Match settings page radius
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16),
        child: Container(
          padding: EdgeInsets.all(isLargeScreen ? 16 : 8), // Match settings page padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isLargeScreen ? 20 : 12), // Match settings page padding
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12), // Match settings page radius
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isLargeScreen ? 40 : 28, // Match settings page icon size
                ),
              ),
              SizedBox(height: isLargeScreen ? 12 : 6), // Match settings page spacing
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isLargeScreen ? 14 : 11, // Match settings page font size
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildDrawer() {
    // Optional: Add drawer for mobile navigation or settings
    return null;
  }

  // Navigation methods remain the same
  void _navigateToTerminalPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ListterminalPage()),
    );
  }

  void _navigateToApprovePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApprovalPage()),
    );
  }

  void _navigateToStoreReportService() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StoreReportPage()),
    );
  }

  void _navigateToExpiryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpirePage()),
    );
  }

  void _navigateToStockPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StockPage()),
    );
  }

  void _navigateToLocationPage() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LocationPage()),
    );
  }

  void _navigateToProductsPage() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductPage()),
    );
  }

  void _navigateToSettlementViewPage() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettlementViewPage()),
    );
  }


  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        SimpleTranslations.get(_langCode, 'home_menu'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      // Add settings button for web
      actions: _isWebDesktop ? [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsDialog,
          tooltip: SimpleTranslations.get(_langCode, 'settings'),
        ),
        const SizedBox(width: 8),
      ] : null,
    );
  }

  // Settings dialog for web
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(SimpleTranslations.get(_langCode, 'settings')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(SimpleTranslations.get(_langCode, 'language')),
                subtitle: Text(selectedLanguage),
                onTap: () => _showLanguageDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.palette),
                title: Text(SimpleTranslations.get(_langCode, 'theme')),
                subtitle: Text(selectedTheme),
                onTap: () => _showThemeDialog(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(SimpleTranslations.get(_langCode, 'close')),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(SimpleTranslations.get(_langCode, 'select_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages
              .map((lang) => RadioListTile<String>(
                    title: Text(lang),
                    value: lang,
                    groupValue: selectedLanguage,
                    onChanged: (value) {
                      if (value != null) {
                        _saveLanguage(value);
                        Navigator.pop(context);
                        Navigator.pop(context); // Close settings dialog too
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(SimpleTranslations.get(_langCode, 'select_theme')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themes
              .map((theme) => RadioListTile<String>(
                    title: Text(theme),
                    value: theme,
                    groupValue: selectedTheme,
                    onChanged: (value) {
                      if (value != null) {
                        _saveTheme(value);
                        Navigator.pop(context);
                        Navigator.pop(context); // Close settings dialog too
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}