import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/car/carAddPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'package:image_picker/image_picker.dart';

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

class MyCarPage extends StatefulWidget {
  const MyCarPage({super.key});

  @override
  State<MyCarPage> createState() => _MyCarPageState();
}

class _MyCarPageState extends State<MyCarPage> {
  bool loading = true;
  String? error;
  String langCode = 'en';
  String? token;
  String? phone;
  Map<String, dynamic>? carData;
  String currentTheme = 'green'; // Default theme

  int _selectedIndex = 0;

  File? _picture_id;
  File? _picture1;
  File? _picture2;
  File? _picture3;

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

  AppTheme get selectedTheme => themes[currentTheme] ?? themes['green']!;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadPrefsAndFetchCar();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('selectedTheme') ?? 'green';
    if (mounted) {
      setState(() {
        currentTheme = savedTheme;
      });
    }
  }

  Future<void> _loadPrefsAndFetchCar() async {
    final prefs = await SharedPreferences.getInstance();
    langCode = prefs.getString('languageCode') ?? 'en';
    token = prefs.getString('access_token');
    phone = prefs.getString('user');

    if (token == null || phone == null) {
      setState(() {
        loading = false;
        error = 'Token or phone not found. Please login again.';
      });
      return;
    }

    await _fetchCarData();
  }

  Future<void> _fetchCarData() async {
    try {
      final url = AppConfig.api('/api/car/myCar');
      final body = jsonEncode({'driver_id': phone});

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'success' &&
            res['data'] != null &&
            res['data'].isNotEmpty) {
          setState(() {
            carData = res['data'][0];
            loading = false;
            error = null;
          });
        } else {
          setState(() {
            error = SimpleTranslations.get(langCode, 'noCarFound');
            loading = false;
          });
        }
      } else {
        setState(() {
          error = 'Error: ${response.statusCode}';
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

  Future<void> _pickImage(String type) async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        final file = File(pickedFile.path);
        switch (type) {
          case 'picture_id':
            _picture_id = file;
            break;
          case 'picture1':
            _picture1 = file;
            break;
          case 'picture2':
            _picture2 = file;
            break;
          case 'picture3':
            _picture3 = file;
            break;
        }
      });
    }
  }

  Widget _imagePreview(
    String label, {
    File? imageFile,
    String? imageUrl,
    required VoidCallback onTap,
    double size = 100,
    bool isCircular = false,
  }) {
    ImageProvider? imageProvider;

    if (imageFile != null) {
      imageProvider = FileImage(imageFile);
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageProvider = NetworkImage(imageUrl);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular ? null : BorderRadius.circular(12),
              border: Border.all(
                color: selectedTheme.primaryColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: selectedTheme.primaryColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
              color: selectedTheme.backgroundColor,
            ),
            child: imageProvider == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: size * 0.3,
                        color: selectedTheme.primaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SimpleTranslations.get(langCode, 'tap_to_add'),
                        style: TextStyle(
                          fontSize: 10,
                          color: selectedTheme.textColor.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: isCircular
                          ? null
                          : BorderRadius.circular(10),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selectedTheme.textColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: selectedTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selectedTheme.primaryColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: selectedTheme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: selectedTheme.backgroundColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(color: selectedTheme.textColor, fontSize: 16),
        readOnly: true,
      ),
    );
  }

  Widget _buildLicensePlate() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            SimpleTranslations.get(langCode, 'license_plate'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selectedTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  carData!['pr_name'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.directions_car,
                      color: Colors.black87,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      carData!['license_plate'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 2,
                        color: Colors.black87,
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

  Widget _buildCarInfo() {
    if (carData == null) return const SizedBox();

    return Container(
      color: selectedTheme.backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    selectedTheme.primaryColor,
                    selectedTheme.accentColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: selectedTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 48,
                    color: selectedTheme.buttonTextColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    SimpleTranslations.get(langCode, 'my_car'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: selectedTheme.buttonTextColor,
                    ),
                  ),
                  Text(
                    '${carData!['brand'] ?? ''} ${carData!['model'] ?? ''}',
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedTheme.buttonTextColor.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Main car document image
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selectedTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedTheme.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selectedTheme.primaryColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    SimpleTranslations.get(langCode, 'car_documents'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: selectedTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _imagePreview(
                    SimpleTranslations.get(langCode, "picture_Id"),
                    imageFile: _picture_id,
                    imageUrl: carData!['picture_id'] as String?,
                    onTap: () => _pickImage('picture_id'),
                    size: 200,
                    isCircular: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Car photos
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selectedTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedTheme.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selectedTheme.primaryColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    SimpleTranslations.get(langCode, 'car_photos'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: selectedTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _imagePreview(
                        SimpleTranslations.get(langCode, "picture1"),
                        imageFile: _picture1,
                        imageUrl: carData!['picture1'] as String?,
                        onTap: () => _pickImage('picture1'),
                        size: 90,
                        isCircular: false,
                      ),
                      _imagePreview(
                        SimpleTranslations.get(langCode, "picture2"),
                        imageFile: _picture2,
                        imageUrl: carData!['picture2'] as String?,
                        onTap: () => _pickImage('picture2'),
                        size: 90,
                        isCircular: false,
                      ),
                      _imagePreview(
                        SimpleTranslations.get(langCode, "picture3"),
                        imageFile: _picture3,
                        imageUrl: carData!['picture3'] as String?,
                        onTap: () => _pickImage('picture3'),
                        size: 90,
                        isCircular: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Car details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selectedTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedTheme.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selectedTheme.primaryColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: selectedTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        SimpleTranslations.get(langCode, 'car_details'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: selectedTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildReadOnlyField(
                    label: SimpleTranslations.get(langCode, 'brand'),
                    value: carData!['brand'] ?? '',
                  ),
                  _buildReadOnlyField(
                    label: SimpleTranslations.get(langCode, 'model'),
                    value: carData!['model'] ?? '',
                  ),
                  _buildReadOnlyField(
                    label: SimpleTranslations.get(langCode, 'car_type_id'),
                    value: carData!['car_type_la'] ?? '',
                  ),

                  _buildLicensePlate(),

                  _buildReadOnlyField(
                    label: SimpleTranslations.get(langCode, 'insurance_no'),
                    value: carData!['insurance_no'] ?? '',
                  ),
                  _buildReadOnlyField(
                    label: SimpleTranslations.get(langCode, 'insurance_date'),
                    value: (carData!['insurance_date'] ?? '')
                        .toString()
                        .split('T')
                        .first,
                  ),
                  _buildReadOnlyField(
                    label: SimpleTranslations.get(langCode, 'car_status'),
                    value: carData!['car_status'] ?? '',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Refresh button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    loading = true;
                  });
                  _fetchCarData();
                },
                icon: Icon(Icons.refresh, color: selectedTheme.buttonTextColor),
                label: Text(
                  SimpleTranslations.get(langCode, 'refresh'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selectedTheme.buttonTextColor,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedTheme.primaryColor,
                  foregroundColor: selectedTheme.buttonTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: selectedTheme.primaryColor.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    return Container(
      color: selectedTheme.backgroundColor,
      child: Center(
        child: Text(
          SimpleTranslations.get(langCode, 'profilePage'),
          style: TextStyle(color: selectedTheme.textColor),
        ),
      ),
    );
  }

  Widget _buildSettingsPage() {
    return Container(
      color: selectedTheme.backgroundColor,
      child: Center(
        child: Text(
          SimpleTranslations.get(langCode, 'settingsPage'),
          style: TextStyle(color: selectedTheme.textColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (loading) {
      bodyContent = Container(
        color: selectedTheme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              selectedTheme.primaryColor,
            ),
          ),
        ),
      );
    } else if (error != null) {
      bodyContent = Container(
        color: selectedTheme.backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: selectedTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  size: 64,
                  color: selectedTheme.primaryColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                SimpleTranslations.get(langCode, 'no_car_found'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: selectedTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                SimpleTranslations.get(langCode, 'add_car_desc'),
                style: TextStyle(
                  fontSize: 14,
                  color: selectedTheme.textColor.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: selectedTheme.primaryColor,
                  foregroundColor: selectedTheme.buttonTextColor,
                  elevation: 4,
                  shadowColor: selectedTheme.primaryColor.withOpacity(0.4),
                ),
                icon: Icon(
                  Icons.add,
                  color: selectedTheme.buttonTextColor,
                  size: 24,
                ),
                label: Text(
                  SimpleTranslations.get(langCode, 'addCar'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: selectedTheme.buttonTextColor,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CarAddPage()),
                  ).then((_) {
                    // Refresh when returning from CarAddPage
                    setState(() {
                      loading = true;
                    });
                    _fetchCarData();
                  });
                },
              ),
            ],
          ),
        ),
      );
    } else {
      switch (_selectedIndex) {
        case 0:
          bodyContent = _buildCarInfo();
          break;
        case 1:
          bodyContent = _buildProfilePage();
          break;
        case 2:
          bodyContent = _buildSettingsPage();
          break;
        default:
          bodyContent = _buildCarInfo();
      }
    }

    return Scaffold(
      backgroundColor: selectedTheme.backgroundColor,
      body: bodyContent,
    );
  }
}
