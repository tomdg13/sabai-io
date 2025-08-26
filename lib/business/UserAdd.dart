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
  final _documentIdController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _usernameController = TextEditingController();

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

  // Branch data
  List<Map<String, dynamic>> _branches = [];
  Map<String, dynamic>? _selectedBranch;
  bool _isLoadingBranches = false;

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
      currentTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
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
        _showErrorSnackBar(
          SimpleTranslations.get(langCode, 'no_company_found_login_again'),
        );
      } else {
        // Load branches after company data is loaded
        _loadBranches();
      }
    } catch (e) {
      setState(() {
        _isLoadingCompany = false;
      });
      _showErrorSnackBar(
        SimpleTranslations.get(langCode, 'error_loading_company_info'),
      );
    }
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final url = AppConfig.api('/api/iobranch');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['data'] != null) {
          final List<dynamic> branchList = data['data'];
          
          setState(() {
            _branches = branchList.map((branch) => {
              'id': branch['branch_id'],
              'branch_name': branch['branch_name'] ?? 'Unknown Branch',
              'branch_code': branch['branch_code'] ?? '',
              'address': branch['address'] ?? '',
              'image_url': branch['image_url'] ?? '',
            }).toList();
            
            // Don't auto-select first branch, let user choose
            _isLoadingBranches = false;
          });
        } else {
          setState(() {
            _isLoadingBranches = false;
          });
          _showErrorSnackBar(
            SimpleTranslations.get(langCode, 'no_branches_found'),
          );
        }
      } else {
        setState(() {
          _isLoadingBranches = false;
        });
        _showErrorSnackBar(
          'Failed to load branches: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingBranches = false;
      });
      _showErrorSnackBar(
        'Error loading branches: $e',
      );
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
                  color: ThemeConfig.getPrimaryColor(
                    currentTheme,
                  ), // Use theme color
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
                  color: ThemeConfig.getPrimaryColor(
                    currentTheme,
                  ), // Use theme color
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
          _showErrorSnackBar(
            SimpleTranslations.get(langCode, 'image_too_large'),
          );
          return;
        }

        final String base64String = base64Encode(imageBytes);
        final String dataUrl = 'data:image/jpeg;base64,$base64String';

        setState(() {
          _selectedImage = imageFile;
          _base64Image = dataUrl;
        });

        _showSuccessSnackBar(
          SimpleTranslations.get(langCode, 'image_selected_successfully'),
        );
      }
    } catch (e) {
      _showErrorSnackBar(
        SimpleTranslations.get(langCode, 'error_selecting_image'),
      );
    }
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_companyId == null) {
      _showErrorSnackBar(
        SimpleTranslations.get(langCode, 'company_id_required_login_again'),
      );
      return;
    }

    if (_selectedBranch == null) {
      _showErrorSnackBar(
        'Please select a branch',
      );
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
        'branch_id': _selectedBranch!['id'], // Add branch_id to the request
        'photo': _base64Image,
        'status': 'active',
        'document_id': _documentIdController.text.trim().isEmpty ? null : _documentIdController.text.trim(),
        'username': _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
        'account_no': _accountNoController.text.trim().isEmpty ? null : _accountNoController.text.trim(),
        'account_name': _accountNameController.text.trim().isEmpty ? null : _accountNameController.text.trim(),
        'language': langCode, // Use current language
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
            '${SimpleTranslations.get(langCode, 'user_added_successfully')} $_companyName!',
          );
          Navigator.pop(context, true);
        } else {
          _showErrorSnackBar(
            data['message'] ??
                SimpleTranslations.get(langCode, 'unknown_error_occurred'),
          );
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['message'] ??
              errorData['error'] ??
              SimpleTranslations.get(langCode, 'unknown_server_error');
          _showErrorSnackBar(
            '${SimpleTranslations.get(langCode, 'server_error')} (${response.statusCode}): $errorMessage',
          );
        } catch (e) {
          _showErrorSnackBar(
            '${SimpleTranslations.get(langCode, 'error')} ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar(
        SimpleTranslations.get(langCode, 'network_error_occurred'),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${SimpleTranslations.get(langCode, 'branch') ?? 'Branch'} *',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _isLoadingBranches
              ? Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeConfig.getPrimaryColor(currentTheme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Loading branches...'),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedBranch,
                    hint: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Select branch'),
                    ),
                    isExpanded: true,
                    items: _branches.map((branch) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: branch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              // branch Image
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: branch['image_url'] != null &&
                                        branch['image_url']
                                            .toString()
                                            .isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.network(
                                          branch['image_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[100],
                                              child: Icon(
                                                Icons.location_on,
                                                color: Colors.grey[400],
                                                size: 16,
                                              ),
                                            );
                                          },
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              color: Colors.grey[100],
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 1.5,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[100],
                                        child: Icon(
                                          Icons.location_on,
                                          color: Colors.grey[400],
                                          size: 16,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              // branch Name
                              Expanded(
                                child: Text(
                                  branch['branch_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedBranch = value),
                  ),
                ),
        ),
        if (_selectedBranch == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              'Branch is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            ThemeConfig.getThemeColors(currentTheme)['success'] ??
            Colors.green, // Use theme color
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            ThemeConfig.getThemeColors(currentTheme)['error'] ??
            Colors.red, // Use theme color
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _documentIdController.dispose();
    _accountNoController.dispose();
    _accountNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'add_user')),
        backgroundColor: ThemeConfig.getPrimaryColor(
          currentTheme,
        ), // Use theme color
        foregroundColor: ThemeConfig.getButtonTextColor(
          currentTheme,
        ), // Use theme color
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
                              color: ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ), // Use theme color
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
                                      color: ThemeConfig.getPrimaryColor(
                                        currentTheme,
                                      ), // Use theme color
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      SimpleTranslations.get(
                                        langCode,
                                        'add_photo',
                                      ),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: ThemeConfig.getPrimaryColor(
                                          currentTheme,
                                        ), // Use theme color
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
                        SimpleTranslations.get(
                          langCode,
                          'tap_to_select_profile_image',
                        ),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(
                          langCode,
                          'full_name_required',
                        ),
                        hintText: SimpleTranslations.get(
                          langCode,
                          'enter_full_name',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ), // Use theme color
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.person,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ), // Use theme color
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return SimpleTranslations.get(
                            langCode,
                            'please_enter_name',
                          );
                        }
                        if (value.trim().length < 2) {
                          return SimpleTranslations.get(
                            langCode,
                            'name_must_be_at_least_2_characters',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Username Field (Optional)
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username (Optional)',
                        hintText: 'Enter username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ),
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.account_circle,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Document ID Field (Optional)
                    TextFormField(
                      controller: _documentIdController,
                      decoration: InputDecoration(
                        labelText: 'Document ID (Optional)',
                        hintText: 'Enter document/ID number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ),
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.badge,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account Name Field (Optional)
                    TextFormField(
                      controller: _accountNameController,
                      decoration: InputDecoration(
                        labelText: 'Account Name (Optional)',
                        hintText: 'Enter bank account name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ),
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.account_balance,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account Number Field (Optional)
                    TextFormField(
                      controller: _accountNoController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: 'Account Number (Optional)',
                        hintText: 'Enter bank account number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ),
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.credit_card,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(
                          langCode,
                          'phone_number_required',
                        ),
                        hintText: SimpleTranslations.get(
                          langCode,
                          'enter_phone_number',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ), // Use theme color
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.phone,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ), // Use theme color
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return SimpleTranslations.get(
                            langCode,
                            'please_enter_phone_number',
                          );
                        }
                        if (value.trim().length < 8) {
                          return SimpleTranslations.get(
                            langCode,
                            'phone_number_must_be_at_least_8_digits',
                          );
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
                        labelText: SimpleTranslations.get(
                          langCode,
                          'email_required',
                        ),
                        hintText: SimpleTranslations.get(
                          langCode,
                          'enter_email_address',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ), // Use theme color
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.email,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ), // Use theme color
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return SimpleTranslations.get(
                            langCode,
                            'please_enter_email_address',
                          );
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                          return SimpleTranslations.get(
                            langCode,
                            'please_enter_valid_email_address',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Branch Dropdown
                    _buildBranchDropdown(),
                    const SizedBox(height: 16),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(
                          langCode,
                          'role_required',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(
                              currentTheme,
                            ), // Use theme color
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.work,
                          color: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ), // Use theme color
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
                          return SimpleTranslations.get(
                            langCode,
                            'please_select_role',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Add User Button
                    ElevatedButton(
                      onPressed: (_isLoading || _companyId == null || _selectedBranch == null)
                          ? null
                          : _addUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_companyId != null && _selectedBranch != null)
                            ? ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ) // Use theme color
                            : Colors.grey,
                        foregroundColor: ThemeConfig.getButtonTextColor(
                          currentTheme,
                        ), // Use theme color
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
                                  ThemeConfig.getButtonTextColor(
                                    currentTheme,
                                  ), // Use theme color
                                ),
                              ),
                            )
                          : Text(
                              (_companyId != null && _selectedBranch != null)
                                  ? SimpleTranslations.get(
                                      langCode,
                                      'add_user',
                                    ).toUpperCase()
                                  : 'SELECT COMPANY & BRANCH',
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
                        SimpleTranslations.get(
                          langCode,
                          'cancel',
                        ).toUpperCase(),
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