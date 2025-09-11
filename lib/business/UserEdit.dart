import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../utils/simple_translations.dart';

class UserEditPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const UserEditPage({Key? key, required this.userData}) : super(key: key);

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = _Controllers();
  
  bool _isLoading = false;
  String _langCode = 'en';
  String _currentTheme = ThemeConfig.defaultTheme;
  
  // Image handling - compatible with both mobile and web
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  File? _selectedIdImage;
  String _base64Image = '';
  String _base64IdImage = '';

  // Dropdown selections
  String _selectedRole = 'office';
  String _selectedStatus = 'active';

  // Branch data
  List<Map<String, dynamic>> _branches = [];
  Map<String, dynamic>? _selectedBranch;
  bool _isLoadingBranches = false;

  final List<String> _roles = ['office', 'admin', 'user'];
  final List<String> _statuses = ['active', 'inactive'];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPreferences();
    _initializeControllers();
    await _loadBranches();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _langCode = prefs.getString('languageCode') ?? 'en';
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    _controllers.name.text = widget.userData['name'] ?? '';
    _controllers.username.text = widget.userData['username'] ?? '';
    _controllers.email.text = widget.userData['email'] ?? '';
    _controllers.phone.text = widget.userData['phone'] ?? '';
    _controllers.documentId.text = widget.userData['document_id'] ?? '';
    _controllers.accountNo.text = widget.userData['account_no'] ?? '';
    _controllers.accountName.text = widget.userData['account_name'] ?? '';
    _controllers.bio.text = widget.userData['bio'] ?? '';
    
    _selectedRole = widget.userData['role'] ?? 'office';
    _selectedStatus = widget.userData['status'] ?? 'active';
  }

  Future<void> _loadBranches() async {
  setState(() => _isLoadingBranches = true);

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final companyId = CompanyConfig.getCompanyId();
    
    final uri = AppConfig.api('/api/iobranch').replace(queryParameters: {
      'status': 'admin',
      'company_id': companyId.toString(),
    });

    final response = await http.get(
      uri,
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
          
          // Find and set the user's current branch
          final userBranchId = widget.userData['branch_id'];
          if (userBranchId != null) {
            _selectedBranch = _branches.firstWhere(
              (branch) => branch['id'].toString() == userBranchId.toString(),
              orElse: () => _branches.isNotEmpty ? _branches[0] : {},
            );
          } else if (_branches.isNotEmpty) {
            _selectedBranch = _branches[0];
          }
          
          _isLoadingBranches = false;
        });
      }
    }
  } catch (e) {
    setState(() => _isLoadingBranches = false);
    _showErrorSnackBar('Error loading branches: $e');
  }
}

  // Future<void> _loadBranches() async {
  //   setState(() => _isLoadingBranches = true);

  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString('access_token');
  //     final url = AppConfig.api('/api/iobranch');

  //     final response = await http.get(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
        
  //       if (data['status'] == 'success' && data['data'] != null) {
  //         final List<dynamic> branchList = data['data'];
          
  //         setState(() {
  //           _branches = branchList.map((branch) => {
  //             'id': branch['branch_id'],
  //             'branch_name': branch['branch_name'] ?? 'Unknown Branch',
  //             'branch_code': branch['branch_code'] ?? '',
  //             'address': branch['address'] ?? '',
  //             'image_url': branch['image_url'] ?? '',
  //           }).toList();
            
  //           // Find and set the user's current branch
  //           final userBranchId = widget.userData['branch_id'];
  //           if (userBranchId != null) {
  //             _selectedBranch = _branches.firstWhere(
  //               (branch) => branch['id'].toString() == userBranchId.toString(),
  //               orElse: () => _branches.isNotEmpty ? _branches[0] : {},
  //             );
  //           } else if (_branches.isNotEmpty) {
  //             _selectedBranch = _branches[0];
  //           }
            
  //           _isLoadingBranches = false;
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     setState(() => _isLoadingBranches = false);
  //     _showErrorSnackBar('Error loading branches: $e');
  //   }
  // }

  // Image picker compatible with both mobile and web
  Future<void> _pickImage({bool isIdImage = false}) async {
    if (kIsWeb) {
      await _pickImageFromSource(ImageSource.gallery, isIdImage: isIdImage);
    } else {
      _showImageSourceBottomSheet(isIdImage);
    }
  }

  void _showImageSourceBottomSheet(bool isIdImage) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: ThemeConfig.getPrimaryColor(_currentTheme)),
              title: Text(_translate('gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery, isIdImage: isIdImage);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: ThemeConfig.getPrimaryColor(_currentTheme)),
              title: Text(_translate('camera')),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera, isIdImage: isIdImage);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source, {bool isIdImage = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      
      if (imageBytes.length > 500000) {
        _showErrorSnackBar(_translate('image_too_large'));
        return;
      }

      final base64String = base64Encode(imageBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      setState(() {
        if (isIdImage) {
          _selectedIdImage = kIsWeb ? null : File(image.path);
          _base64IdImage = dataUrl;
        } else {
          _selectedImage = kIsWeb ? null : File(image.path);
          _base64Image = dataUrl;
        }
      });

      _showSuccessSnackBar(_translate('image_selected_successfully'));
    } catch (e) {
      _showErrorSnackBar(_translate('error_selecting_image'));
    }
  }

  // Responsive layout helpers
  bool get _isWebWideScreen => kIsWeb && MediaQuery.of(context).size.width > 600;
  
  Widget _buildResponsiveContainer({required Widget child}) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: kIsWeb && MediaQuery.of(context).size.width > 800 ? 800 : double.infinity,
        ),
        padding: EdgeInsets.all(kIsWeb ? 32 : 16),
        child: child,
      ),
    );
  }

  Widget _buildImagePicker({
    required String title,
    required String subtitle,
    required File? selectedImage,
    required String base64Image,
    required String? existingImageUrl,
    required VoidCallback onTap,
    IconData icon = Icons.add_a_photo,
  }) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
              border: Border.all(
                color: ThemeConfig.getPrimaryColor(_currentTheme),
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
            child: _buildImageContent(selectedImage, base64Image, existingImageUrl, icon),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImageContent(File? selectedImage, String base64Image, String? existingImageUrl, IconData icon) {
    // Handle new image selection
    if (selectedImage != null || base64Image.isNotEmpty) {
      return ClipOval(
        child: kIsWeb && base64Image.isNotEmpty
            ? Image.memory(
                base64Decode(base64Image.split(',')[1]),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              )
            : selectedImage != null
                ? Image.file(
                    selectedImage,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : const SizedBox(),
      );
    }

    // Handle existing image
    if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          existingImageUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultImageContent(icon),
        ),
      );
    }

    // Default placeholder
    return _buildDefaultImageContent(icon);
  }

  Widget _buildDefaultImageContent(IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 30,
          color: ThemeConfig.getPrimaryColor(_currentTheme),
        ),
        const SizedBox(height: 4),
        Text(
          'Add',
          style: TextStyle(
            fontSize: 10,
            color: ThemeConfig.getPrimaryColor(_currentTheme),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool required = false,
    int maxLines = 1,
    IconData? icon,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(_currentTheme),
              width: 2,
            ),
          ),
          prefixIcon: icon != null ? Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(_currentTheme),
          ) : null,
          filled: true,
          fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                if (label.toLowerCase().contains('email')) {
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                }
                if (label.toLowerCase().contains('phone') && value.trim().length < 8) {
                  return 'Phone number must be at least 8 digits';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_translate('branch')} *',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
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
                            ThemeConfig.getPrimaryColor(_currentTheme),
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
                    value: _selectedBranch != null && _branches.contains(_selectedBranch) ? _selectedBranch : null,
                    hint: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Select branch'),
                    ),
                    isExpanded: true,
                    items: _branches.map((branch) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: branch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: branch['image_url'] != null &&
                                        branch['image_url'].toString().isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.network(
                                          branch['image_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[100],
                                              child: Icon(
                                                Icons.location_on,
                                                color: Colors.grey[400],
                                                size: 16,
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

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: '$label *',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(_currentTheme),
              width: 2,
            ),
          ),
          prefixIcon: icon != null ? Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(_currentTheme),
          ) : null,
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item.toUpperCase()),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate() || _selectedBranch == null) {
      if (_selectedBranch == null) {
        _showErrorSnackBar('Please select a branch');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final phone = widget.userData['phone'];
      final url = AppConfig.api('/api/iouser/update/$phone');

      final updateData = <String, dynamic>{
        'name': _controllers.name.text.trim(),
        'username': _controllers.phone.text.trim(), // Username same as phone
        'email': _controllers.email.text.trim(),
        'phone': _controllers.phone.text.trim(),
        'role': _selectedRole,
        'status': _selectedStatus,
        'branch_id': _selectedBranch?['id'],
        'company_id': CompanyConfig.getCompanyId(),
        'document_id': _controllers.documentId.text.trim().isEmpty ? null : _controllers.documentId.text.trim(),
        'account_no': _controllers.accountNo.text.trim().isEmpty ? null : _controllers.accountNo.text.trim(),
        'account_name': _controllers.accountName.text.trim().isEmpty ? null : _controllers.accountName.text.trim(),
        'bio': _controllers.bio.text.trim().isEmpty ? null : _controllers.bio.text.trim(),
        'language': _langCode,
      };

      // Add photos only if new ones were selected
      if (_base64Image.isNotEmpty) {
        updateData['photo'] = _base64Image;
      }
      if (_base64IdImage.isNotEmpty) {
        updateData['photo_id'] = _base64IdImage;
      }

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessSnackBar('User updated successfully');
          Navigator.pop(context, true);
        } else {
          _showErrorSnackBar(data['message'] ?? 'Update failed');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update user: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser() async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_translate('confirm_delete')),
          content: Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_translate('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: ThemeConfig.getThemeColors(_currentTheme)['error'] ?? Colors.red,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final phone = widget.userData['phone'];
      final url = AppConfig.api('/api/iouser/update/$phone');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': 'delete'}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessSnackBar('User deleted successfully');
          Navigator.pop(context, 'deleted');
        } else {
          _showErrorSnackBar(data['message'] ?? 'Delete failed');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to delete user: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _translate(String key) => SimpleTranslations.get(_langCode, key);

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeConfig.getThemeColors(_currentTheme)['success'] ?? Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeConfig.getThemeColors(_currentTheme)['error'] ?? Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_translate('edit_user')),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _deleteUser,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete User',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: _buildResponsiveContainer(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Selection Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImagePicker(
                      title: 'Profile Photo',
                      subtitle: 'Tap to change profile image',
                      selectedImage: _selectedImage,
                      base64Image: _base64Image,
                      existingImageUrl: widget.userData['photo'],
                      onTap: () => _pickImage(isIdImage: false),
                      icon: Icons.person,
                    ),
                    _buildImagePicker(
                      title: 'ID Document',
                      subtitle: 'Tap to change ID photo',
                      selectedImage: _selectedIdImage,
                      base64Image: _base64IdImage,
                      existingImageUrl: widget.userData['photo_id'],
                      onTap: () => _pickImage(isIdImage: true),
                      icon: Icons.badge,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Form Fields
                if (_isWebWideScreen) ...[
                  // Web Layout - Two columns
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _controllers.name,
                          label: 'Full Name',
                          required: true,
                          icon: Icons.person,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _controllers.username,
                          label: 'Username',
                          hint: 'Auto-filled from phone',
                          icon: Icons.account_circle,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _controllers.phone,
                          label: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          required: true,
                          icon: Icons.phone,
                          onChanged: (value) => _controllers.username.text = value.trim(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _controllers.email,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          required: true,
                          icon: Icons.email,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          label: 'Role',
                          value: _selectedRole,
                          items: _roles,
                          onChanged: (value) => setState(() => _selectedRole = value!),
                          icon: Icons.work,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownField(
                          label: 'Status',
                          value: _selectedStatus,
                          items: _statuses,
                          onChanged: (value) => setState(() => _selectedStatus = value!),
                          icon: Icons.info,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Mobile Layout - Single column
                  _buildTextField(
                    controller: _controllers.name,
                    label: 'Full Name',
                    required: true,
                    icon: Icons.person,
                  ),
                  _buildTextField(
                    controller: _controllers.username,
                    label: 'Username',
                    hint: 'Auto-filled from phone',
                    icon: Icons.account_circle,
                    readOnly: true,
                  ),
                  _buildTextField(
                    controller: _controllers.phone,
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    required: true,
                    icon: Icons.phone,
                    onChanged: (value) => _controllers.username.text = value.trim(),
                  ),
                  _buildTextField(
                    controller: _controllers.email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    required: true,
                    icon: Icons.email,
                  ),
                  _buildDropdownField(
                    label: 'Role',
                    value: _selectedRole,
                    items: _roles,
                    onChanged: (value) => setState(() => _selectedRole = value!),
                    icon: Icons.work,
                  ),
                  _buildDropdownField(
                    label: 'Status',
                    value: _selectedStatus,
                    items: _statuses,
                    onChanged: (value) => setState(() => _selectedStatus = value!),
                    icon: Icons.info,
                  ),
                ],

                // Branch Selection
                const SizedBox(height: 8),
                _buildBranchDropdown(),

                // Additional Fields
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _controllers.documentId,
                  label: 'Document ID',
                  icon: Icons.badge,
                ),
                _buildTextField(
                  controller: _controllers.accountName,
                  label: 'Account Name',
                  icon: Icons.account_balance,
                ),
                _buildTextField(
                  controller: _controllers.accountNo,
                  label: 'Account Number',
                  icon: Icons.credit_card,
                ),
                _buildTextField(
                  controller: _controllers.bio,
                  label: 'Bio',
                  maxLines: 3,
                  icon: Icons.description,
                ),

                const SizedBox(height: 32),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                      foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
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
                                ThemeConfig.getButtonTextColor(_currentTheme),
                              ),
                            ),
                          )
                        : Text(
                            'UPDATE USER',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel Button
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                  child: Text(
                    'CANCEL',
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
      ),
    );
  }
}

// Controllers class for managing text editing controllers
class _Controllers {
  final phone = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final documentId = TextEditingController();
  final accountNo = TextEditingController();
  final accountName = TextEditingController();
  final username = TextEditingController();
  final bio = TextEditingController();

  void dispose() {
    phone.dispose();
    name.dispose();
    email.dispose();
    documentId.dispose();
    accountNo.dispose();
    accountName.dispose();
    username.dispose();
    bio.dispose();
  }
}