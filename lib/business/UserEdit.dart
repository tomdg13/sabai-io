import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Inventory/config/config.dart';
import 'package:Inventory/config/theme.dart'; // Add this import
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

class UserEditPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const UserEditPage({Key? key, required this.userData}) : super(key: key);

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme; // Add theme variable
  
  // Image picker and photo handling
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _photoBase64;

  // Controllers for form fields
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _photoController;
  late TextEditingController _photoIdController;
  late TextEditingController _documentIdController;
  late TextEditingController _bankNameController;
  late TextEditingController _provinceNameController;
  late TextEditingController _districtNameController;
  late TextEditingController _villageNameController;
  late TextEditingController _accountNoController;
  late TextEditingController _accountNameController;

  @override
  void initState() {
    super.initState();
    _loadLangCode();
    _loadCurrentTheme(); // Add theme loading
    _initializeControllers();
  }

  void _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  // Add theme loading method
  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _photoController = TextEditingController(text: widget.userData['photo'] ?? '');
    _photoIdController = TextEditingController(text: widget.userData['photo_id'] ?? '');
    _documentIdController = TextEditingController(text: widget.userData['document_id'] ?? '');
    _bankNameController = TextEditingController(text: widget.userData['bank_name'] ?? '');
    _provinceNameController = TextEditingController(text: widget.userData['province_name'] ?? '');
    _districtNameController = TextEditingController(text: widget.userData['district_name'] ?? '');
    _villageNameController = TextEditingController(text: widget.userData['village_name'] ?? '');
    _accountNoController = TextEditingController(text: widget.userData['account_no'] ?? '');
    _accountNameController = TextEditingController(text: widget.userData['account_name'] ?? '');
  }

  // Image picker methods
  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (image != null) {
      await _processSelectedImage(File(image.path));
    }
  }

  Future<void> _pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (image != null) {
      await _processSelectedImage(File(image.path));
    }
  }

  Future<void> _processSelectedImage(File imageFile) async {
    setState(() => _isLoading = true);
    
    try {
      // Read image as bytes
      Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Convert to base64
      String base64String = base64Encode(imageBytes);
      
      // Add data URL prefix for web compatibility (optional)
      String base64WithPrefix = 'data:image/jpeg;base64,$base64String';
      
      setState(() {
        _selectedImage = imageFile;
        _photoBase64 = base64WithPrefix;
        _photoController.text = base64WithPrefix; // Update the controller
      });
      
      print('Image converted to base64, size: ${base64String.length} characters');
      
    } catch (e) {
      print('Error processing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process image: $e'),
          backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(SimpleTranslations.get(langCode, 'select_image_source')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                ),
                title: Text(SimpleTranslations.get(langCode, 'gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
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
                  _pickImageFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _photoController.dispose();
    _photoIdController.dispose();
    _documentIdController.dispose();
    _bankNameController.dispose();
    _provinceNameController.dispose();
    _districtNameController.dispose();
    _villageNameController.dispose();
    _accountNoController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _deleteUser() async {
    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(SimpleTranslations.get(langCode, 'confirm_delete')),
          content: Text(SimpleTranslations.get(langCode, 'delete_user_confirmation')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(SimpleTranslations.get(langCode, 'cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
              ),
              child: Text(SimpleTranslations.get(langCode, 'delete')),
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
      
      final phone = widget.userData['phone']; // Use original phone for API endpoint
      final url = Uri.parse('${AppConfig.baseUrl}/api/iouser/update/$phone');

      final deleteData = {
        'status': 'delete',
      };

      // Console logging for debugging
      print('=== DELETE API REQUEST DEBUG ===');
      print('URL: $url');
      print('Request Body: ${jsonEncode(deleteData)}');
      print('Token: Bearer $token');
      print('================================');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(deleteData),
      );

      // Log response details
      print('=== DELETE API RESPONSE DEBUG ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('=================================');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' || data['status'] == 'delete') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(SimpleTranslations.get(langCode, 'user_deleted_successfully')),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
            ),
          );
          Navigator.pop(context, 'deleted'); // Return 'deleted' to indicate user was deleted
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Delete failed'),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
          ),
        );
      }
    } catch (e) {
      print('=== DELETE ERROR DEBUG ===');
      print('Error: $e');
      print('==========================');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: $e'),
          backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final phone = widget.userData['phone']; // Use original phone for API endpoint
      final url = Uri.parse('${AppConfig.baseUrl}/api/iouser/update/$phone');

      final updateData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'photo': _photoBase64 ?? _photoController.text.trim(), // Use base64 if available, otherwise use URL
        'photo_id': _photoIdController.text.trim(),
        'document_id': _documentIdController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'province_name': _provinceNameController.text.trim(),
        'district_name': _districtNameController.text.trim(),
        'village_name': _villageNameController.text.trim(),
        'account_no': _accountNoController.text.trim(),
        'account_name': _accountNameController.text.trim(),
      };

      // Console logging for debugging
      print('=== API REQUEST DEBUG ===');
      print('URL: $url');
      print('Request Body: ${jsonEncode(updateData)}');
      print('Token: Bearer $token');
      print('========================');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      // Log response details
      print('=== API RESPONSE DEBUG ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('==========================');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(SimpleTranslations.get(langCode, 'user_updated_successfully')),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green, // Use theme color
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Update failed'),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
          ),
        );
      }
    } catch (e) {
      print('=== ERROR DEBUG ===');
      print('Error: $e');
      print('==================');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user: $e'),
          backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelKey,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: SimpleTranslations.get(langCode, labelKey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
              width: 2,
            ),
          ),
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return SimpleTranslations.get(langCode, 'field_required');
                }
                return null;
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'edit_user')),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme), // Use theme color
        actions: [
          IconButton(
            onPressed: _deleteUser,
            icon: const Icon(Icons.delete),
            tooltip: SimpleTranslations.get(langCode, 'delete_user'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Profile photo section with selection capability
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Photo display
                  GestureDetector(
                    onTap: _showImagePickerDialog,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                          width: 2,
                        ),
                        color: Colors.grey[200],
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
                          : (widget.userData['photo'] != null && widget.userData['photo'].isNotEmpty)
                              ? ClipOval(
                                  child: Image.network(
                                    widget.userData['photo'],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey,
                                      );
                                    },
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _showImagePickerDialog,
                    icon: Icon(
                      Icons.camera_alt,
                      color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                    ),
                    label: Text(
                      SimpleTranslations.get(langCode, 'change_photo'),
                      style: TextStyle(
                        color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                      ),
                    ),
                  ),
                  if (_photoBase64 != null)
                    Text(
                      SimpleTranslations.get(langCode, 'new_photo_selected'),
                      style: TextStyle(
                        color: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green, // Use theme color
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    labelKey: 'name',
                    required: true,
                  ),
                  _buildTextField(
                    controller: _emailController,
                    labelKey: 'email',
                    keyboardType: TextInputType.emailAddress,
                    required: true,
                  ),
                  _buildTextField(
                    controller: _photoIdController,
                    labelKey: 'photo_id',
                  ),
                  _buildTextField(
                    controller: _documentIdController,
                    labelKey: 'document_id',
                  ),
                  _buildTextField(
                    controller: _provinceNameController,
                    labelKey: 'province',
                  ),
                  _buildTextField(
                    controller: _districtNameController,
                    labelKey: 'district',
                  ),
                  _buildTextField(
                    controller: _villageNameController,
                    labelKey: 'village',
                  ),
                  _buildTextField(
                    controller: _bankNameController,
                    labelKey: 'bank_name',
                  ),
                  _buildTextField(
                    controller: _accountNoController,
                    labelKey: 'account_no',
                  ),
                  _buildTextField(
                    controller: _accountNameController,
                    labelKey: 'account_name',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateUser,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme), // Use theme color
        tooltip: SimpleTranslations.get(langCode, 'update_user'),
        child: const Icon(Icons.save),
      ),
    );
  }
}