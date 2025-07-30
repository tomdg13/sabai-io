import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/config/theme.dart'; // Add theme import
import 'package:sabaicub/login/CameraWithOverlayPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'package:crypto/crypto.dart';

// Import your CameraWithOverlayPage (make sure path is correct)
// ignore: unused_import

class RegisterUserPage extends StatefulWidget {
  final String phone;
  const RegisterUserPage({Key? key, required this.phone}) : super(key: key);

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phoneController;
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _accountNameController = TextEditingController();

  String langCodes = 'en';
  String currentTheme = ThemeConfig.defaultTheme; // Add theme state

  bool _isPasswordStrong = false;
  double _passwordStrength = 0.0;
  Color _strengthColor = Colors.red;
  String _passwordStrengthLabel = '';

  double _confirmPasswordMatchStrength = 0.0;
  Color _confirmPasswordColor = Colors.red;
  String _confirmPasswordLabel = '';

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
    _phoneController = TextEditingController(text: widget.phone);
    // _usernameController = TextEditingController(text: widget.phone);

    // Add password listeners
    _passwordController.addListener(() {
      _checkPasswordStrength(_passwordController.text);
      _checkConfirmPasswordMatch();
    });
    _confirmPasswordController.addListener(() {
      _checkConfirmPasswordMatch();
    });

    // Add phone listener to sync with username
    _phoneController.addListener(() {
      _usernameController.text = _phoneController.text;
    });

    getLanguage();
    _loadTheme(); // Load current theme
    _fetchBanks();
    _fetchProvinces();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _documentIdController.dispose();
    _accountNoController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCodes = prefs.getString('languageCode') ?? 'en';
    });
  }

  // Add method to load current theme
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _checkPasswordStrength(String password) {
    bool hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));

    setState(() {
      if (password.length < 4 || !hasLetter || !hasNumber) {
        _isPasswordStrong = false;
        _passwordStrength = 0.33;
        _strengthColor = Colors.red;
        _passwordStrengthLabel = SimpleTranslations.get(
          langCodes,
          'PasswordTooEasy',
        );
      } else if (password.length < 6) {
        _isPasswordStrong = true;
        _passwordStrength = 0.66;
        _strengthColor = Colors.orange;
        _passwordStrengthLabel = SimpleTranslations.get(
          langCodes,
          'PasswordMedium',
        );
      } else {
        _isPasswordStrong = true;
        _passwordStrength = 1.0;
        _strengthColor = Colors.green;
        _passwordStrengthLabel = SimpleTranslations.get(
          langCodes,
          'PasswordStrong',
        );
      }
    });
  }

  void _checkConfirmPasswordMatch() {
    setState(() {
      if (_confirmPasswordController.text == _passwordController.text &&
          _confirmPasswordController.text.isNotEmpty) {
        _confirmPasswordMatchStrength = 1.0;
        _confirmPasswordColor = Colors.green;
        _confirmPasswordLabel = SimpleTranslations.get(
          langCodes,
          'PasswordsMatch',
        );
      } else {
        _confirmPasswordMatchStrength = 0.33;
        _confirmPasswordColor = Colors.red;
        _confirmPasswordLabel = SimpleTranslations.get(
          langCodes,
          'PasswordsDoNotMatch',
        );
      }
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

    // Password validation checks
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError(SimpleTranslations.get(langCodes, 'PasswordsDoNotMatch'));
      return;
    }
    if (!_isPasswordStrong) {
      _showError(SimpleTranslations.get(langCodes, 'PasswordTooEasy'));
      return;
    }

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
      "username": _phoneController.text,
      "email": _emailController.text,
      "password": md5.convert(utf8.encode(_passwordController.text)).toString(),
      "phone": _phoneController.text,
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
      "status": "active",
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
                backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
              ),
            );
            // Navigate to login page after successful registration
            Navigator.popUntil(context, (route) => route.isFirst);
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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(
        currentTheme,
      ), // Use theme background
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCodes, 'RegisterPage'),
          style: TextStyle(color: ThemeConfig.getButtonTextColor(currentTheme)),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(
          currentTheme,
        ), // Use theme primary color
        iconTheme: IconThemeData(
          color: ThemeConfig.getButtonTextColor(currentTheme),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
            )
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
                    _buildTextField(_phoneController, 'phone', true),
                    // _buildTextField(
                    //   _usernameController,
                    //   'username',
                    //   true,
                    //   readOnly: true,
                    // ),
                    _buildPasswordField(),
                    _buildConfirmPasswordField(),
                    _buildTextField(_nameController, 'name', true),
                    _buildTextField(
                      _emailController,
                      'email',
                      false,
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ),
                              foregroundColor: ThemeConfig.getButtonTextColor(
                                currentTheme,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              SimpleTranslations.get(langCodes, 'Register'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ),
                              side: BorderSide(
                                color: ThemeConfig.getPrimaryColor(
                                  currentTheme,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
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

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _passwordController,
            style: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
            decoration: InputDecoration(
              labelText: SimpleTranslations.get(langCodes, 'password'),
              labelStyle: TextStyle(
                color: ThemeConfig.getTextColor(currentTheme),
              ),
              prefixIcon: Icon(
                Icons.lock,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(
                    currentTheme,
                  ).withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  width: 2,
                ),
              ),
            ),
            obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return '${SimpleTranslations.get(langCodes, 'Enter')} password';
              }
              if (v.length < 6) {
                return SimpleTranslations.get(langCodes, 'PasswordMin6Chars');
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
          ),
          const SizedBox(height: 4),
          Text(
            _passwordStrengthLabel,
            style: TextStyle(
              fontSize: 12,
              color: _strengthColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _confirmPasswordController,
            style: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
            decoration: InputDecoration(
              labelText: SimpleTranslations.get(langCodes, 'ConfirmPassword'),
              labelStyle: TextStyle(
                color: ThemeConfig.getTextColor(currentTheme),
              ),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(
                    currentTheme,
                  ).withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  width: 2,
                ),
              ),
            ),
            obscureText: true,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return SimpleTranslations.get(langCodes, 'ConfirmYourPassword');
              }
              if (v != _passwordController.text) {
                return SimpleTranslations.get(langCodes, 'PasswordsDoNotMatch');
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          if (_confirmPasswordController.text.isNotEmpty) ...[
            LinearProgressIndicator(
              value: _confirmPasswordMatchStrength,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_confirmPasswordColor),
            ),
            const SizedBox(height: 4),
            Text(
              _confirmPasswordLabel,
              style: TextStyle(
                fontSize: 12,
                color: _confirmPasswordColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelKey,
    bool required, {
    bool isPassword = false,
    bool isEmail = false,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
        decoration: InputDecoration(
          labelText: SimpleTranslations.get(langCodes, labelKey),
          labelStyle: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme),
              width: 2,
            ),
          ),
        ),
        obscureText: isPassword,
        readOnly: readOnly,
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
        style: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
        decoration: InputDecoration(
          labelText: SimpleTranslations.get(langCodes, labelKey),
          labelStyle: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme),
              width: 2,
            ),
          ),
        ),
        dropdownColor: ThemeConfig.getBackgroundColor(currentTheme),
        iconEnabledColor: ThemeConfig.getPrimaryColor(currentTheme),
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

          return DropdownMenuItem<int>(
            value: value,
            child: Text(
              name,
              style: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
            ),
          );
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
              color: file != null
                  ? Colors.grey.shade300
                  : ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
              border: Border.all(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
              shape: BoxShape.rectangle,
              image: file != null
                  ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                  : null,
            ),
            child: file == null
                ? Icon(
                    Icons.camera_alt,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                    size: 30,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ThemeConfig.getTextColor(currentTheme),
          ),
        ),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [TextSpan(text: subtitle)],
            style: TextStyle(
              color: ThemeConfig.getTextColor(currentTheme).withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}
