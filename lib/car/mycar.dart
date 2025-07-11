// your imports...
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
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

  int _selectedIndex = 0;

  File? _picture_id;
  File? _picture1;
  File? _picture2;
  File? _picture3;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndFetchCar();
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
    bool isCircular = true,
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
              border: Border.all(color: Colors.grey),
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: imageProvider == null
                ? const Icon(Icons.image, size: 40)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        readOnly: true,
      ),
    );
  }

  Widget _buildCarInfo() {
    if (carData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _imagePreview(
                SimpleTranslations.get(langCode, "picture1"),
                imageFile: _picture1,
                imageUrl: carData!['picture1'] as String?,
                onTap: () => _pickImage('picture1'),
                isCircular: false,
              ),
              _imagePreview(
                SimpleTranslations.get(langCode, "picture2"),
                imageFile: _picture2,
                imageUrl: carData!['picture2'] as String?,
                onTap: () => _pickImage('picture2'),
                isCircular: false,
              ),
              _imagePreview(
                SimpleTranslations.get(langCode, "picture3"),
                imageFile: _picture3,
                imageUrl: carData!['picture3'] as String?,
                onTap: () => _pickImage('picture3'),
                isCircular: false,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: 150,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.yellow,
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    carData!['pr_name'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    carData!['license_plate'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ New Fields: insurance_no, insurance_date, car_status
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
    );
  }

  Widget _buildProfilePage() {
    return Center(child: Text(SimpleTranslations.get(langCode, 'profilePage')));
  }

  Widget _buildSettingsPage() {
    return Center(
      child: Text(SimpleTranslations.get(langCode, 'settingsPage')),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (loading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      bodyContent = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.directions_car, size: 28),
              label: Text(
                SimpleTranslations.get(langCode, 'addCar'),
                style: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CarAddPage()),
                );
              },
            ),
          ],
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

    return Scaffold(body: bodyContent);
  }
}
