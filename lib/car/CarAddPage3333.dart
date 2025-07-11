import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sabaicub/config/config.dart' show AppConfig;
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

  String langCodes = '';
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
    langCodes = prefs.getString('languageCode') ?? 'en';
    final driverString = prefs.getString('user');
    int? driver = driverString != null ? int.tryParse(driverString) : null;

    setState(() {
      _driverId = driver;
    });
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

  Future<File> _resizeImage(File file, {int maxWidth = 800}) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return file;

    final resized = img.copyResize(image, width: maxWidth);
    final resizedBytes = img.encodeJpg(resized, quality: 85);
    final resizedFile = await file.writeAsBytes(resizedBytes);
    return resizedFile;
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
      }
    } catch (_) {}
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
      }
    } catch (_) {}
  }

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      final file = File(picked.path);
      final resized = await _resizeImage(file);

      setState(() {
        switch (type) {
          case 'picture1':
            _picture1 = resized;
            break;
          case 'picture2':
            _picture2 = resized;
            break;
          case 'picture3':
            _picture3 = resized;
            break;
          case 'picture_id':
            picture_id = resized;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SimpleTranslations.get(langCodes, 'no_image_selected')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedProvinceId == null ||
        _selectedCarTypeId == null ||
        _driverId == null)
      return;

    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final url = AppConfig.api('/api/car/carAdd');
    final body = {
      "brand": _brandController.text,
      "model": _modelController.text,
      "license_plate": _licensePlateController.text,
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

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['status'] == 'success') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/menu');
        }
      }
    } catch (_) {
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
    if (image is File) imageProvider = FileImage(image);

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
        title: Text(SimpleTranslations.get(langCodes, 'CarAddPage')),
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
                            SimpleTranslations.get(langCodes, "picture_Id"),
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
                                SimpleTranslations.get(langCodes, "picture1"),
                                _picture1,
                                () => _pickImage('picture1'),
                                isCircular: false,
                              ),
                              _imagePreview(
                                SimpleTranslations.get(langCodes, "picture2"),
                                _picture2,
                                () => _pickImage('picture2'),
                                isCircular: false,
                              ),
                              _imagePreview(
                                SimpleTranslations.get(langCodes, "picture3"),
                                _picture3,
                                () => _pickImage('picture3'),
                                isCircular: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<int>(
                            value: _selectedProvinceId,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCodes,
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
                                    langCodes,
                                    'select_province',
                                  )
                                : null,
                          ),
                          TextFormField(
                            controller: _licensePlateController,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCodes,
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
                                langCodes,
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
                                    langCodes,
                                    'select_car_type',
                                  )
                                : null,
                          ),
                          TextFormField(
                            controller: _brandController,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCodes,
                                'brand',
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? SimpleTranslations.get(
                                    langCodes,
                                    'enter_brand',
                                  )
                                : null,
                          ),
                          TextFormField(
                            controller: _modelController,
                            decoration: InputDecoration(
                              labelText: SimpleTranslations.get(
                                langCodes,
                                'model',
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? SimpleTranslations.get(
                                    langCodes,
                                    'enter_model',
                                  )
                                : null,
                          ),
                          const SizedBox(height: 40),
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
                        child: Text(SimpleTranslations.get(langCodes, 'Save')),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(SimpleTranslations.get(langCodes, 'Back')),
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
    if (raw.length <= 2) return newValue.copyWith(text: raw);
    if (raw.length <= 6) {
      final formatted = '${raw.substring(0, 2)} ${raw.substring(2)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return oldValue;
  }
}
