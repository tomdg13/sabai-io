import 'package:flutter/material.dart';
import 'package:sabaicub/business/ProductPage.dart' show ProductPage;
import 'package:sabaicub/business/UserPage.dart';
import 'package:sabaicub/business/branch.dart';


import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart'; // Import your existing ThemeConfig


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

  final List<String> languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
  ];

  // Get available themes from ThemeConfig
  List<String> get themes => ThemeConfig.getAvailableThemes();

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload theme if needed to avoid unnecessary rebuilds
    _reloadThemeIfChanged();
  }

  /// Load all saved settings from SharedPreferences
  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load theme
      final savedTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      final validTheme = ThemeConfig.isValidTheme(savedTheme)
          ? savedTheme
          : ThemeConfig.defaultTheme;

      // Load language
      final savedLanguage = prefs.getString('selectedLanguage') ?? 'English';
      final validLanguage = languages.contains(savedLanguage)
          ? savedLanguage
          : 'English';

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
      // Use defaults if loading fails
      if (mounted) {
        setState(() {
          selectedTheme = ThemeConfig.defaultTheme;
          currentTheme = ThemeConfig.defaultTheme;
          selectedLanguage = 'English';
          isLoading = false;
        });
      }
    }
  }

  /// Reload theme only if it changed externally
  Future<void> _reloadThemeIfChanged() async {
    if (isLoading) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;

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

  /// Save theme to SharedPreferences
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
      _showErrorSnackBar('Failed to save theme setting');
    }
  }

  /// Save language to SharedPreferences
  Future<void> _saveLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedLanguage', language);

      if (mounted) {
        setState(() {
          selectedLanguage = language;
        });
      }
    } catch (e) {
      debugPrint('Error saving language: $e');
      _showErrorSnackBar('Failed to save language setting');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
          children: [
            _buildGridItem(
              icon: Icons.group,
              title: 'Branch',
              color: Colors.blue,
              onTap: _navigateToBranchPage,
            ),

            _buildGridItem(
              icon: Icons.store,
              title: 'Vender',
              color: Colors.green,
              onTap: _navigateToVenderPage,
            ),
            _buildGridItem(
              icon: Icons.storefront,
              title: 'Store',
              color: Colors.orange,
              onTap: _navigateToStorePage,
            ),
            _buildGridItem(
              icon: Icons.computer,
              title: 'Product',
              color: Colors.purple,
              onTap: _navigateToProductPage,  // ✅ Fixed: Use specific method
            ),
            // NEW: User menu item
            _buildGridItem(
              icon: Icons.person,
              title: 'User',
              color: Colors.cyan,
              onTap: _navigateToUserPage ,
            ),
            _buildLanguageGridItem(),
            _buildThemeGridItem(),
            // Future settings placeholders
            _buildPlaceholderGridItem('Reports', Icons.analytics),

            _buildPlaceholderGridItem('Help', Icons.help_outline),
          ],
        ),
      ),
    );
  }

  /// Build a standard grid item
  Widget _buildGridItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
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

  /// Build the language selection grid item
  Widget _buildLanguageGridItem() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _showLanguageDialog,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.language, color: Colors.teal, size: 28),
              ),
              const SizedBox(height: 4),
              const Text(
                'Language',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  selectedLanguage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the theme selection grid item
  Widget _buildThemeGridItem() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _showThemeDialog,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette,
                  color: Colors.indigo,
                  size: 28,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Theme',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  ThemeConfig.getThemeDisplayName(selectedTheme),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build placeholder grid items for future features
  Widget _buildPlaceholderGridItem(String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: InkWell(
        onTap: () => _showSnackBar('$title feature coming soon'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey.withOpacity(0.6), size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NAVIGATION METHODS - Each with specific purpose

  /// Navigate to Branch page
  void _navigateToBranchPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BranchPage()),
    );
  }

  /// Navigate to User page
  void _navigateToUserPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => userpage()),
    );
  }

  /// Navigate to Product page
  void _navigateToProductPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductPage()),
    );
  }

  /// Navigate to Vender page (placeholder)
  void _navigateToVenderPage() {
    _showSnackBar('Vender feature coming soon');
    // TODO: Replace with actual VenderPage when implemented
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => const VenderPage()),
    // );
  }

  /// Navigate to Store page (placeholder)
  void _navigateToStorePage() {
    _showSnackBar('Store feature coming soon');
    // TODO: Replace with actual StorePage when implemented
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => const StorePage()),
    // );
  }

  /// Show language selection dialog
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final language = languages[index];
                return ListTile(
                  title: Text(language),
                  leading: Radio<String>(
                    value: language,
                    groupValue: selectedLanguage,
                    onChanged: (String? value) async {
                      if (value != null) {
                        await _saveLanguage(value);
                        if (mounted) {
                          Navigator.of(context).pop();
                          _showSnackBar('Language changed to $value');
                        }
                      }
                    },
                  ),
                  onTap: () async {
                    await _saveLanguage(language);
                    if (mounted) {
                      Navigator.of(context).pop();
                      _showSnackBar('Language changed to $language');
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Show theme selection dialog
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: SizedBox(
            width: double.minPositive,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: themes.map((theme) {
                final displayName = ThemeConfig.getThemeDisplayName(theme);
                final primaryColor = ThemeConfig.getPrimaryColor(theme);

                return ListTile(
                  title: Text(displayName),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: theme,
                        groupValue: selectedTheme,
                        onChanged: (String? value) async {
                          if (value != null) {
                            await _saveTheme(value);
                            if (mounted) {
                              Navigator.of(context).pop();
                              _showSnackBar(
                                'Theme changed to ${ThemeConfig.getThemeDisplayName(value)}',
                              );
                            }
                          }
                        },
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await _saveTheme(theme);
                    if (mounted) {
                      Navigator.of(context).pop();
                      _showSnackBar(
                        'Theme changed to ${ThemeConfig.getThemeDisplayName(theme)}',
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Show success snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  /// Show error snackbar
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
}