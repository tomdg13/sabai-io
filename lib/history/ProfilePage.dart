import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/config/theme.dart'; // Use main ThemeConfig
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'ImagePreviewPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profileData;
  bool loading = true;
  String? error;
  String langCode = 'en';
  String? token;
  String currentTheme = ThemeConfig.defaultTheme; // Use ThemeConfig default

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadLangAndProfile();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    if (mounted) {
      setState(() {
        currentTheme = savedTheme;
      });
    }
  }

  Future<void> _loadLangAndProfile() async {
    final prefs = await SharedPreferences.getInstance();
    langCode = prefs.getString('languageCode') ?? 'en';
    token = prefs.getString('access_token');
    final phone = prefs.getString('user');

    if (token == null || phone == null) {
      setState(() {
        error = 'Token or phone not found. Please login again.';
        loading = false;
      });
      return;
    }

    await _fetchProfile(token!, phone);
  }

  Future<void> _fetchProfile(String token, String phone) async {
    try {
      final url = AppConfig.api('/api/user/getProfiledriver');
      final requestBody = {
        'phone': int.tryParse(phone) ?? phone,
        'role': 'driver',
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            profileData = data['data'];
            loading = false;
            error = null;
          });
        } else {
          setState(() {
            error = data['message'] ?? 'Failed to load profile';
            loading = false;
          });
        }
      } else {
        setState(() {
          error = 'Server error: ${response.statusCode}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error: $e';
        loading = false;
      });
    }
  }

  void _refreshProfile() {
    if (token != null && profileData != null) {
      setState(() {
        loading = true;
      });
      _fetchProfile(token!, profileData!['phone'].toString());
    }
  }

  String? getLocalizedValue(String keyLo, String keyEn) {
    final valueEn = profileData?[keyEn]?.toString();
    final valueLo = profileData?[keyLo]?.toString();

    if (langCode == 'en') {
      return (valueEn != null && valueEn.isNotEmpty) ? valueEn : valueLo;
    } else {
      return valueLo;
    }
  }

  Widget _buildProfileHeader() {
    final imageUrl = profileData?['profile_image_url'];
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (profileData != null && token != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImagePreviewPage(
                      imageUrl: imageUrl ?? '',
                      name: profileData!['name'] ?? '',
                      customerId: profileData!['customer_id'] ?? 0,
                      role: 'driver',
                      token: token!,
                      onUpdateProfile: _refreshProfile,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: buttonTextColor, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: buttonTextColor,
                    child: ClipOval(
                      child: Image.network(
                        imageUrl ?? '',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/default_profile.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: buttonTextColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: primaryColor,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profileData?['name'] ?? '',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: buttonTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profileData?['email'] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: buttonTextColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryColor, size: 24),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textColor,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            value.toString(),
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final status = profileData?['status']?.toString().toLowerCase();
    final isOnline =
        profileData?['online']?.toString().toLowerCase() == 'online';

    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOnline
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: isOnline ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SimpleTranslations.get(langCode, 'driver_status'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '• ${status ?? 'Active'}',
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);

    if (loading) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

    if (error != null) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 64),
              const SizedBox(height: 16),
              Text(
                error!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    loading = true;
                    error = null;
                  });
                  _loadLangAndProfile();
                },
                icon: Icon(Icons.refresh, color: buttonTextColor),
                label: Text('Retry', style: TextStyle(color: buttonTextColor)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: buttonTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final villageName = getLocalizedValue('vill_name', 'vill_name_en');
    final districtName = getLocalizedValue('dr_name', 'dr_name_en');
    final provinceName = getLocalizedValue('pr_name', 'pr_name_en');

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildStatusIndicator(),
              const SizedBox(height: 10),
              _buildDetailCard(
                Icons.phone,
                SimpleTranslations.get(langCode, 'phone'),
                profileData?['phone'],
              ),
              _buildDetailCard(
                Icons.credit_card,
                SimpleTranslations.get(langCode, 'document_id'),
                profileData?['document_id'],
              ),
              _buildDetailCard(
                Icons.account_balance,
                SimpleTranslations.get(langCode, 'account_no'),
                profileData?['account_no'],
              ),
              _buildDetailCard(
                Icons.person,
                SimpleTranslations.get(langCode, 'account_name'),
                profileData?['account_name'],
              ),
              _buildDetailCard(
                Icons.info_outline,
                SimpleTranslations.get(langCode, 'bio'),
                profileData?['bio'],
              ),
              _buildDetailCard(
                Icons.directions_car,
                SimpleTranslations.get(langCode, 'license_plate'),
                profileData?['license_plate'],
              ),
              _buildDetailCard(
                Icons.home,
                SimpleTranslations.get(langCode, 'village_name'),
                villageName,
              ),
              _buildDetailCard(
                Icons.apartment,
                SimpleTranslations.get(langCode, 'district_name'),
                districtName,
              ),
              _buildDetailCard(
                Icons.public,
                SimpleTranslations.get(langCode, 'province_name'),
                provinceName,
              ),
              const SizedBox(height: 20),
              // Refresh Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _refreshProfile,
                  icon: Icon(Icons.refresh, color: buttonTextColor),
                  label: Text(
                    SimpleTranslations.get(langCode, 'refresh_profile'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: buttonTextColor,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
