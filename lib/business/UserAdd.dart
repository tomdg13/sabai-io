import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../config/config.dart';
import '../config/theme.dart'; // Add this import
import '../utils/simple_translations.dart';

class UserAddPage extends StatefulWidget {
  const UserAddPage({Key? key}) : super(key: key);

  @override
  State<UserAddPage> createState() => _UserAddPageState();
}

class _UserAddPageState extends State<UserAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _selectedRole = 'office';
  File? _selectedImage;
  String _base64Image = '';
  bool _isLoading = false;
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme; // Add theme variable
  
  // Company data
  int? _companyId;
  String _companyName = '';
  bool _isLoadingCompany = true;

  final List<String> _roles = ['office', 'admin', 'user'];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadLangCode();
    _loadCurrentTheme(); // Add theme loading
    _loadCompanyData();
  }

  Future<void> _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  // Add theme loading method
  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _loadCompanyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = prefs.getInt('company_id');
      final companyName = prefs.getString('company_name') ?? 'Unknown Company';
      
      setState(() {
        _companyId = companyId;
        _companyName = companyName;
        _isLoadingCompany = false;
      });

      if (_companyId == null) {
        _showErrorSnackBar(SimpleTranslations.get(langCode, 'no_company_found_login_again'));
      }
    } catch (e) {
      setState(() {
        _isLoadingCompany = false;
      });
      _showErrorSnackBar(SimpleTranslations.get(langCode, 'error_loading_company_info'));
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                ),
                title: Text(SimpleTranslations.get(langCode, 'gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                ),
                title: Text(SimpleTranslations.get(langCode, 'camera')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        final List<int> imageBytes = await imageFile.readAsBytes();
        
        // Check file size (limit to ~500KB)
        if (imageBytes.length > 500000) {
          _showErrorSnackBar(SimpleTranslations.get(langCode, 'image_too_large'));
          return;
        }
        
        final String base64String = base64Encode(imageBytes);
        final String dataUrl = 'data:image/jpeg;base64,$base64String';
        
        setState(() {
          _selectedImage = imageFile;
          _base64Image = dataUrl;
        });
        
        _showSuccessSnackBar(SimpleTranslations.get(langCode, 'image_selected_successfully'));
      }
    } catch (e) {
      _showErrorSnackBar(SimpleTranslations.get(langCode, 'error_selecting_image'));
    }
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_companyId == null) {
      _showErrorSnackBar(SimpleTranslations.get(langCode, 'company_id_required_login_again'));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final url = AppConfig.api('/api/iouser/add');
      
      final requestBody = <String, dynamic>{
        'phone': _phoneController.text.trim(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'company_id': _companyId,
        'photo': _base64Image,
        'status': 'active',
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
          _showSuccessSnackBar(
            '${SimpleTranslations.get(langCode, 'user_added_successfully')} $_companyName!'
          );
          Navigator.pop(context, true);
        } else {
          _showErrorSnackBar(data['message'] ?? SimpleTranslations.get(langCode, 'unknown_error_occurred'));
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? errorData['error'] ?? SimpleTranslations.get(langCode, 'unknown_server_error');
          _showErrorSnackBar('${SimpleTranslations.get(langCode, 'server_error')} (${response.statusCode}): $errorMessage');
        } catch (e) {
          _showErrorSnackBar('${SimpleTranslations.get(langCode, 'error')} ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      _showErrorSnackBar(SimpleTranslations.get(langCode, 'network_error_occurred'));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green, // Use theme color
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'add_user')),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme), // Use theme color
        elevation: 0,
      ),
      body: _isLoadingCompany
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Image Section
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _selectedImage != null
                              ? ClipOval(
                                  child: Image.file(
                                    _selectedImage!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      SimpleTranslations.get(langCode, 'add_photo'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        SimpleTranslations.get(langCode, 'tap_to_select_profile_image'),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(langCode, 'full_name_required'),
                        hintText: SimpleTranslations.get(langCode, 'enter_full_name'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.person,
                          color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return SimpleTranslations.get(langCode, 'please_enter_name');
                        }
                        if (value.trim().length < 2) {
                          return SimpleTranslations.get(langCode, 'name_must_be_at_least_2_characters');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(langCode, 'phone_number_required'),
                        hintText: SimpleTranslations.get(langCode, 'enter_phone_number'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.phone,
                          color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return SimpleTranslations.get(langCode, 'please_enter_phone_number');
                        }
                        if (value.trim().length < 8) {
                          return SimpleTranslations.get(langCode, 'phone_number_must_be_at_least_8_digits');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(langCode, 'email_required'),
                        hintText: SimpleTranslations.get(langCode, 'enter_email_address'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.email,
                          color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return SimpleTranslations.get(langCode, 'please_enter_email_address');
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value.trim())) {
                          return SimpleTranslations.get(langCode, 'please_enter_valid_email_address');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(langCode, 'role_required'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.work,
                          color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _roles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedRole = newValue;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return SimpleTranslations.get(langCode, 'please_select_role');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Add User Button
                    ElevatedButton(
                      onPressed: (_isLoading || _companyId == null) ? null : _addUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _companyId != null 
                            ? ThemeConfig.getPrimaryColor(currentTheme) // Use theme color
                            : Colors.grey,
                        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme), // Use theme color
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ThemeConfig.getButtonTextColor(currentTheme), // Use theme color
                                ),
                              ),
                            )
                          : Text(
                              _companyId != null 
                                  ? SimpleTranslations.get(langCode, 'add_user').toUpperCase()
                                  : SimpleTranslations.get(langCode, 'no_company_selected').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Cancel Button
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pop(context, false);
                            },
                      child: Text(
                        SimpleTranslations.get(langCode, 'cancel').toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}