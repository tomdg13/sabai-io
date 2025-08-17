import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/config/theme.dart'; // Use main ThemeConfig
import 'package:sabaicub/car/carAddPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'package:image_picker/image_picker.dart';

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
  String currentTheme = ThemeConfig.defaultTheme; // Use ThemeConfig default

  int _selectedIndex = 0;

  File? _picture_id;
  File? _picture1;
  File? _picture2;
  File? _picture3;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadPrefsAndFetchCar();
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

    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

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
                color: primaryColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
              color: backgroundColor,
            ),
            child: imageProvider == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: size * 0.3,
                        color: primaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SimpleTranslations.get(langCode, 'tap_to_add'),
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withOpacity(0.6),
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
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
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
            color: primaryColor,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: backgroundColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(color: textColor, fontSize: 16),
        readOnly: true,
      ),
    );
  }

  Widget _buildLicensePlate() {
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            SimpleTranslations.get(langCode, 'license_plate'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.yellowAccent,
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 75, 67, 2).withOpacity(0.3),
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

    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);

    return Container(
      color: backgroundColor,
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
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_car, size: 48, color: buttonTextColor),
                  const SizedBox(height: 8),
                  Text(
                    SimpleTranslations.get(langCode, 'my_car'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: buttonTextColor,
                    ),
                  ),
                  Text(
                    '${carData!['brand'] ?? ''} ${carData!['model'] ?? ''}',
                    style: TextStyle(
                      fontSize: 16,
                      color: buttonTextColor.withOpacity(0.9),
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
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
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
                      color: textColor,
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
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
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
                      color: textColor,
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
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.1),
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
                      Icon(Icons.info_outline, color: primaryColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        SimpleTranslations.get(langCode, 'car_details'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
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
                icon: Icon(Icons.refresh, color: buttonTextColor),
                label: Text(
                  SimpleTranslations.get(langCode, 'refresh'),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Container(
      color: backgroundColor,
      child: Center(
        child: Text(
          SimpleTranslations.get(langCode, 'profilePage'),
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }

  Widget _buildSettingsPage() {
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return Container(
      color: backgroundColor,
      child: Center(
        child: Text(
          SimpleTranslations.get(langCode, 'settingsPage'),
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);

    Widget bodyContent;

    if (loading) {
      bodyContent = Container(
        color: backgroundColor,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    } else if (error != null) {
      bodyContent = Container(
        color: backgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  size: 64,
                  color: primaryColor.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                SimpleTranslations.get(langCode, 'no_car_found'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                SimpleTranslations.get(langCode, 'add_car_desc'),
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.6),
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
                  backgroundColor: primaryColor,
                  foregroundColor: buttonTextColor,
                  elevation: 4,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                icon: Icon(Icons.add, color: buttonTextColor, size: 24),
                label: Text(
                  SimpleTranslations.get(langCode, 'addCar'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: buttonTextColor,
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

    return Scaffold(backgroundColor: backgroundColor, body: bodyContent);
  }
}
