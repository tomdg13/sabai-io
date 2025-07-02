import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:kupcar/config/config.dart' show AppConfig;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';

class CarAddPage extends StatefulWidget {
  const CarAddPage({Key? key}) : super(key: key);

  @override
  State<CarAddPage> createState() => _CarAddPageState();
}

class _CarAddPageState extends State<CarAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _licensePlateController = TextEditingController();

  File? _picture1;
  File? _picture2;
  File? _picture3;
  File? picture_id;

  List<dynamic> _carTypes = [];
  int? _selectedCarTypeId;

  List<dynamic> _provinces = [];
  int? _selectedProvinceId;

  String langCode = 'en';
  int? _driverId;
  bool _languageLoaded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getLanguageAndDriverId();
    await _fetchCarTypes();
    await _fetchProvinces();
    setState(() => _languageLoaded = true);
  }

  Future<void> _getLanguageAndDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('languageCode') ?? 'en';
    final driverString = prefs.getString('user');
    int? driver = driverString != null ? int.tryParse(driverString) : null;

    setState(() {
      langCode = code;
      _driverId = driver;
    });
<<<<<<< HEAD

    debugPrint('Retrieved langCode: $langCode');
    debugPrint('Retrieved driver ID: $_driverId');
=======
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
  }

  String _getMimeType(File? file) {
    final ext = file?.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
      default:
        return 'png';
    }
  }

  Future<void> _fetchCarTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/user/carType');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _carTypes = data['data'] ?? []);
<<<<<<< HEAD
      } else {
        debugPrint('Failed to load car types: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching car types: $e');
    }
=======
      }
    } catch (_) {}
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
  }

  Future<void> _fetchProvinces() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/user/province');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _provinces = data['data'] ?? []);
<<<<<<< HEAD
      } else {
        debugPrint('Failed to load provinces: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching provinces: $e');
    }
=======
      }
    } catch (_) {}
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
  }

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
<<<<<<< HEAD
    final picked = await picker.pickImage(source: ImageSource.gallery);
=======
    final picked = await picker.pickImage(
      source: ImageSource.camera,
    ); // <-- camera only
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
    if (picked != null) {
      setState(() {
        final file = File(picked.path);
        switch (type) {
          case 'picture1':
            _picture1 = file;
            break;
          case 'picture2':
            _picture2 = file;
            break;
          case 'picture3':
            _picture3 = file;
            break;
          case 'picture_id':
            picture_id = file;
            break;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_picture1 == null ||
        _picture2 == null ||
        _picture3 == null ||
        picture_id == null) {
<<<<<<< HEAD
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              SimpleTranslations.get(langCode, 'no_image_selected'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
=======
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SimpleTranslations.get(langCode, 'no_image_selected')),
          backgroundColor: Colors.red,
        ),
      );
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
      return;
    }

    if (_selectedProvinceId == null ||
        _selectedCarTypeId == null ||
<<<<<<< HEAD
        _driverId == null) {
      debugPrint(
        'Missing required selections: province $_selectedProvinceId, carType $_selectedCarTypeId, driver $_driverId',
      );
      return;
    }
=======
        _driverId == null)
      return;
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95

    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = Uri.parse("http://209.97.172.105:3000/api/car/carAdd");
    final body = {
      "brand": _brandController.text,
      "model": _modelController.text,
<<<<<<< HEAD
      "license_plate":
          _licensePlateController.text, // license plate can be empty
=======
      "license_plate": _licensePlateController.text,
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
      "car_province_id": _selectedProvinceId.toString(),
      "car_type_id": _selectedCarTypeId.toString(),
      "driver_id": _driverId.toString(),
      "picture1":
          "data:image/${_getMimeType(_picture1)};base64,${base64Encode(_picture1!.readAsBytesSync())}",
      "picture2":
          "data:image/${_getMimeType(_picture2)};base64,${base64Encode(_picture2!.readAsBytesSync())}",
      "picture3":
          "data:image/${_getMimeType(_picture3)};base64,${base64Encode(_picture3!.readAsBytesSync())}",
      "picture_id":
          "data:image/${_getMimeType(picture_id)};base64,${base64Encode(picture_id!.readAsBytesSync())}",
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

<<<<<<< HEAD
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

=======
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['status'] == 'success') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/menu');
        }
<<<<<<< HEAD
      } else {
        debugPrint('Failed to add car: ${data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('Error submitting car: $e');
=======
      }
    } catch (_) {
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _imagePreview(
    String label,
    dynamic image,
    VoidCallback onTap, {
    double size = 80,
    bool isCircular = true,
  }) {
    ImageProvider? imageProvider;
<<<<<<< HEAD

    if (image is File) {
      imageProvider = FileImage(image);
    }
=======
    if (image is File) imageProvider = FileImage(image);
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular ? null : BorderRadius.circular(8),
              color: Colors.grey.shade300,
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: imageProvider == null
                ? Icon(Icons.camera_alt, size: size / 2, color: Colors.white70)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_languageLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'CarAddPage')),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _imagePreview(
                            SimpleTranslations.get(langCode, "picture_Id"),
                            picture_id,
                            () => _pickImage('picture_id'),
                            size: 200,
                            isCircular: false,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _imagePreview(
                                SimpleTranslations.get(langCode, "picture1"),
                                _picture1,
                                () => _pickImage('picture1'),
                                isCircular: false,
                              ),
                              _imagePreview(
                                SimpleTranslations.get(langCode, "picture2"),
                                _picture2,
                                () => _pickImage('picture2'),
                                isCircular: false,
                              ),
                              _imagePreview(
                                SimpleTranslations.get(langCode, "picture3"),
                                _picture3,
                                () => _pickImage('picture3'),
                                isCircular: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
<<<<<<< HEAD
=======
                          DropdownButtonFormField<int>(
                            value: _selectedProvinceId,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCode,
                                'Carprovince',
                              ),
                            ),
                            items: _provinces
                                .map<DropdownMenuItem<int>>(
                                  (prov) => DropdownMenuItem<int>(
                                    value: prov['pr_id'],
                                    child: Text(prov['pr_name']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedProvinceId = val),
                            validator: (v) => v == null
                                ? SimpleTranslations.get(
                                    langCode,
                                    'select_province',
                                  )
                                : null,
                          ),
                          TextFormField(
                            controller: _licensePlateController,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCode,
                                'license_plate',
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[ເ-ໄກ-ຮ0-9\s]'),
                              ),
                              LengthLimitingTextInputFormatter(7),
                              _LaoPlateFormatter(),
                            ],
                          ),
                          DropdownButtonFormField<int>(
                            value: _selectedCarTypeId,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCode,
                                'car_type',
                              ),
                            ),
                            items: _carTypes
                                .map<DropdownMenuItem<int>>(
                                  (type) => DropdownMenuItem<int>(
                                    value: type['car_type_id'],
                                    child: Text(type['car_type_la']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedCarTypeId = val),
                            validator: (v) => v == null
                                ? SimpleTranslations.get(
                                    langCode,
                                    'select_car_type',
                                  )
                                : null,
                          ),
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
                          TextFormField(
                            controller: _brandController,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCode,
                                'brand',
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? SimpleTranslations.get(
                                    langCode,
                                    'enter_brand',
                                  )
                                : null,
                          ),
                          TextFormField(
                            controller: _modelController,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCode,
                                'model',
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? SimpleTranslations.get(
                                    langCode,
                                    'enter_model',
                                  )
                                : null,
                          ),
<<<<<<< HEAD
                          // license_plate field without validation - user can skip it
                          TextFormField(
                            controller: _licensePlateController,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCode,
                                'license_plate',
                              ),
                            ),
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[ເ-ໄກ-ຮ0-9\s]'),
                              ),
                              LengthLimitingTextInputFormatter(7),
                              _LaoPlateFormatter(),
                            ],
                          ),
                          DropdownButtonFormField<int>(
                            value: _selectedProvinceId,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCode,
                                'Carprovince',
                              ),
                            ),
                            items: _provinces
                                .map<DropdownMenuItem<int>>(
                                  (prov) => DropdownMenuItem<int>(
                                    value: prov['pr_id'] ?? 0,
                                    child: Text(
                                      prov['pr_name'] ?? 'Unknown name',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedProvinceId = val),
                            validator: (v) => v == null
                                ? SimpleTranslations.get(
                                    langCode,
                                    'select_province',
                                  )
                                : null,
                          ),
                          DropdownButtonFormField<int>(
                            value: _selectedCarTypeId,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCode,
                                'car_type',
                              ),
                            ),
                            items: _carTypes
                                .map<DropdownMenuItem<int>>(
                                  (type) => DropdownMenuItem<int>(
                                    value: type['car_type_id'],
                                    child: Text(type['car_type_la']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedCarTypeId = val),
                            validator: (v) => v == null
                                ? SimpleTranslations.get(
                                    langCode,
                                    'select_car_type',
                                  )
                                : null,
                          ),
=======
                          const SizedBox(height: 40),
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: Text(SimpleTranslations.get(langCode, 'Save')),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(SimpleTranslations.get(langCode, 'Back')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaoPlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(' ', '');
<<<<<<< HEAD

    if (raw.length <= 2) {
      return newValue.copyWith(text: raw);
    } else if (raw.length <= 6) {
      final letters = raw.substring(0, 2);
      final numbers = raw.substring(2);
      final formatted = '$letters $numbers';
=======
    if (raw.length <= 2) return newValue.copyWith(text: raw);
    if (raw.length <= 6) {
      final formatted = '${raw.substring(0, 2)} ${raw.substring(2)}';
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
<<<<<<< HEAD

=======
>>>>>>> 0d04b9071e082b16868912fd964bd2e2d6fdcf95
    return oldValue;
  }
}
