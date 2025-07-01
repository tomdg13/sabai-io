import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kupcar/config/config.dart';
import 'package:kupcar/login/CameraWithOverlayPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'package:crypto/crypto.dart';

// Import your CameraWithOverlayPage (make sure path is correct)
// ignore: unused_import
import 'camera_with_overlay_page.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({Key? key}) : super(key: key);

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _accountNameController = TextEditingController();

  String langCodes = 'en';

  String _getMimeType(File? file) {
    final ext = file?.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      default:
        return 'png';
    }
  }

  bool _loading = false;
  File? _photoFile;
  File? _photoIdFile;

  List<dynamic> _banks = [];
  int? _selectedBankId;

  List<dynamic> _provinces = [];
  int? _selectedProvinceId;

  List<dynamic> _districts = [];
  int? _selectedDistrictId;

  List<dynamic> _villages = [];
  int? _selectedVillageId;

  @override
  void initState() {
    super.initState();
    getLanguage();
    _fetchBanks();
    _fetchProvinces();
  }

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCodes = prefs.getString('languageCode') ?? 'en';
    });
  }

  Future<void> _fetchBanks() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/customer/bank');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _banks = data['data'] ?? [];
        });
      } else {
        _showError('Failed to load banks: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error loading banks: $e');
    }
  }

  Future<void> _fetchProvinces() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/customer/province');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _provinces = data['data'] ?? [];
        });
      } else {
        _showError('Failed to load provinces: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error loading provinces: $e');
    }
  }

  Future<void> _fetchDistricts(int provinceId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/customer/district');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"pr_id": provinceId}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _districts = data['data'];
            _selectedDistrictId = null;
            _villages = [];
            _selectedVillageId = null;
          });
        }
      } else {
        _showError('Failed to load districts: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error loading districts: $e');
    }
  }

  Future<void> _fetchVillages(int provinceId, int districtId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/customer/villages');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"pr_id": provinceId, "dr_id": districtId}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _villages = data['data'];
            _selectedVillageId = null;
          });
        }
      } else {
        _showError('Failed to load villages: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error loading villages: $e');
    }
  }

  // Updated: open camera with front or back camera depending on isPhotoId
  Future<void> _pickImage(bool isPhotoId) async {
    final cameraDirection = isPhotoId
        ? CameraLensDirection
              .back // ID card: back camera
        : CameraLensDirection.front; // Selfie: front camera

    final File? photo = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CameraWithOverlayPage(cameraLensDirection: cameraDirection),
      ),
    );

    if (photo != null) {
      setState(() {
        if (isPhotoId) {
          _photoIdFile = photo;
        } else {
          _photoFile = photo;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoFile == null || _photoIdFile == null) {
      _showError(SimpleTranslations.get(langCodes, 'PleaseSelectSelfieAndID'));
      return;
    }
    if (_selectedBankId == null ||
        _selectedProvinceId == null ||
        _selectedDistrictId == null ||
        _selectedVillageId == null) {
      _showError(
        SimpleTranslations.get(
          langCodes,
          'PleaseSelectBankProvinceDistrictVillage',
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final url = AppConfig.api('/api/customer/addDriver');
    final body = {
      "name": _nameController.text,
      "username": _usernameController.text,
      "email": _emailController.text,
      "password": md5.convert(utf8.encode(_passwordController.text)).toString(),
      "phone": _usernameController.text,
      "document_id": _documentIdController.text,
      "photo":
          "data:image/${_getMimeType(_photoFile)};base64,${base64Encode(_photoFile!.readAsBytesSync())}",
      "photo_id":
          "data:image/${_getMimeType(_photoIdFile)};base64,${base64Encode(_photoIdFile!.readAsBytesSync())}",
      "vinllage_id": _selectedVillageId,
      "district_id": _selectedDistrictId,
      "province_id": _selectedProvinceId,
      "role": "customer",
      "account_bank_id": _selectedBankId,
      "account_no": _accountNoController.text,
      "account_name": _accountNameController.text,
      "status": "unactive",
      "online": "online",
      "language": langCodes.toUpperCase(),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  SimpleTranslations.get(
                    langCodes,
                    'UserRegisteredSuccessfully',
                  ),
                ),
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          _showError(
            data['message'] ??
                SimpleTranslations.get(langCodes, 'UnknownError'),
          );
        }
      } else {
        _showError(
          '${SimpleTranslations.get(langCodes, 'Failed')}: ${response.statusCode}',
        );
      }
    } catch (e) {
      _showError('${SimpleTranslations.get(langCodes, 'Error')}: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCodes, 'RegisterPage')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _imagePreview(
                              SimpleTranslations.get(langCodes, 'SelfiePhoto'),
                              _photoFile,
                              () => _pickImage(false),
                              SimpleTranslations.get(langCodes, 'TakeSelfie'),
                              isSquare: false,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _imagePreview(
                              SimpleTranslations.get(langCodes, 'IDCardPhoto'),
                              _photoIdFile,
                              () => _pickImage(true),
                              SimpleTranslations.get(langCodes, 'UploadID'),
                              isSquare: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(_usernameController, 'phone', true),
                    _buildTextField(
                      _passwordController,
                      'password',
                      true,
                      isPassword: true,
                    ),
                    _buildTextField(_nameController, 'name', true),
                    _buildTextField(
                      _emailController,
                      'email',
                      true,
                      isEmail: true,
                    ),
                    _buildTextField(_documentIdController, 'DocumentID', false),
                    _buildDropdown(
                      _provinces,
                      _selectedProvinceId,
                      'province',
                      (val) {
                        setState(() {
                          _selectedProvinceId = val;
                          _districts = [];
                          _villages = [];
                          _selectedDistrictId = null;
                          _selectedVillageId = null;
                        });
                        if (val != null) _fetchDistricts(val);
                      },
                    ),
                    _buildDropdown(
                      _districts,
                      _selectedDistrictId,
                      'district',
                      (val) {
                        setState(() {
                          _selectedDistrictId = val;
                          _villages = [];
                          _selectedVillageId = null;
                        });
                        if (val != null && _selectedProvinceId != null) {
                          _fetchVillages(_selectedProvinceId!, val);
                        }
                      },
                    ),
                    _buildDropdown(
                      _villages,
                      _selectedVillageId,
                      'village',
                      (val) => setState(() => _selectedVillageId = val),
                    ),
                    _buildDropdown(
                      _banks,
                      _selectedBankId,
                      'bank',
                      (val) => setState(() => _selectedBankId = val),
                    ),
                    _buildTextField(
                      _accountNoController,
                      'AccountNumber',
                      false,
                    ),
                    _buildTextField(
                      _accountNameController,
                      'AccountName',
                      false,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: Text(
                              SimpleTranslations.get(langCodes, 'Register'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              SimpleTranslations.get(langCodes, 'Back'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelKey,
    bool required, {
    bool isPassword = false,
    bool isEmail = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: SimpleTranslations.get(langCodes, labelKey),
        ),
        obscureText: isPassword,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        validator: (v) {
          if (!required) return null;
          if (v == null || v.isEmpty)
            return '${SimpleTranslations.get(langCodes, 'Enter')} $labelKey';
          if (isEmail && !v.contains('@'))
            return SimpleTranslations.get(langCodes, 'EnterValidEmail');
          if (isPassword && v.length < 6)
            return SimpleTranslations.get(langCodes, 'PasswordMin6Chars');
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(
    List items,
    int? selected,
    String labelKey,
    Function(int?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<int>(
        value: selected,
        decoration: InputDecoration(
          labelText: SimpleTranslations.get(langCodes, labelKey),
        ),
        items: items.map<DropdownMenuItem<int>>((item) {
          int value;
          String name;

          switch (labelKey) {
            case 'province':
              value = item['pr_id'];
              name = item['pr_name'];
              break;
            case 'district':
              value = item['dr_id'];
              name = item['dr_name'];
              break;
            case 'village':
              value = item['vill_id'];
              name = item['vill_name'];
              break;
            case 'bank':
              value = item['bank_id'];
              name = item['bank_name'];
              break;
            default:
              value = item['id'];
              name = item['name'];
          }

          return DropdownMenuItem<int>(value: value, child: Text(name));
        }).toList(),
        onChanged: onChanged,
        validator: (v) => v == null
            ? '${SimpleTranslations.get(langCodes, 'Select')} $labelKey'
            : null,
      ),
    );
  }

  Widget _imagePreview(
    String label,
    File? file,
    VoidCallback onPick,
    String subtitle, {
    bool isSquare = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: isSquare ? BoxShape.rectangle : BoxShape.rectangle,
              image: file != null
                  ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                  : null,
            ),
            child: file == null
                ? Icon(Icons.camera_alt, color: Colors.white70, size: 30)
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [TextSpan(text: subtitle)],
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }
}
