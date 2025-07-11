import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sabaicub/config/config.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLangAndProfile();
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
      _fetchProfile(token!, profileData!['phone']);
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
    return GestureDetector(
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
      child: Column(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.grey.shade300,
            child: ClipOval(
              child: Image.network(
                imageUrl ?? '',
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/default_profile.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profileData?['name'] ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            profileData?['email'] ?? '',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(value.toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    final villageName = getLocalizedValue('vill_name', 'vill_name_en');
    final districtName = getLocalizedValue('dr_name', 'dr_name_en');
    final provinceName = getLocalizedValue('pr_name', 'pr_name_en');

    // ignore: unused_local_variable
    String? formattedDate;
    if (profileData?['profile_date'] != null) {
      final dt = DateTime.tryParse(profileData!['profile_date']);
      formattedDate = dt != null
          ? DateFormat('yyyy-MM-dd – kk:mm').format(dt)
          : null;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
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
            _buildDetailCard(
              Icons.verified_user,
              SimpleTranslations.get(langCode, 'status'),
              profileData?['status'],
            ),
            _buildDetailCard(
              Icons.wifi_off,
              SimpleTranslations.get(langCode, 'online'),
              profileData?['online'],
            ),
          ],
        ),
      ),
    );
  }
}
