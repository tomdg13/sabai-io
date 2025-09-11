import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:html' as html; // For web file picker

class branchEditPage extends StatefulWidget {
  final Map<String, dynamic> branchData;

  const branchEditPage({Key? key, required this.branchData}) : super(key: key);

  @override
  State<branchEditPage> createState() => _branchEditPageState();
}

class _branchEditPageState extends State<branchEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _branchNameController;
  late final TextEditingController _branchCodeController;
  late final TextEditingController _provinceNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _managerNameController;

  String? _base64Image;
  String? _currentImageUrl;
  File? _imageFile; // For mobile
  Uint8List? _webImageBytes; // For web
  String? _webImageName; // For web
  bool _isLoading = false;
  bool _isDeleting = false;
  String currentTheme = ThemeConfig.defaultTheme;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _initializeControllers();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    _branchNameController = TextEditingController(text: widget.branchData['branch_name'] ?? '');
    _branchCodeController = TextEditingController(text: widget.branchData['branch_code'] ?? '');
    _provinceNameController = TextEditingController(text: widget.branchData['province_name'] ?? '');
    _addressController = TextEditingController(text: widget.branchData['address'] ?? '');
    _phoneController = TextEditingController(text: widget.branchData['phone'] ?? '');
    _emailController = TextEditingController(text: widget.branchData['email'] ?? '');
    _managerNameController = TextEditingController(text: widget.branchData['manager_name'] ?? '');
    _currentImageUrl = widget.branchData['image_url'];
    
    print('🔧 DEBUG: Initialized edit form with branch: ${widget.branchData['branch_name']}');
    print('🔧 DEBUG: Branch ID: ${widget.branchData['branch_id']}');
    print('🔧 DEBUG: Branch Code: ${widget.branchData['branch_code']}');
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _branchCodeController.dispose();
    _provinceNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerNameController.dispose();
    super.dispose();
  }

  // Web-specific image picker
  Future<void> _pickImageWeb() async {
    try {
      final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();

      await uploadInput.onChange.first;
      final files = uploadInput.files;
      if (files!.isEmpty) return;

      final html.File file = files[0];
      if (!file.type.startsWith('image/')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Please select an image file'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check file size (limit to 5MB)
      if (file.size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('File size should be less than 5MB'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final html.FileReader reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final Uint8List bytes = Uint8List.fromList(reader.result as List<int>);
      final String base64String = base64Encode(bytes);
      
      setState(() {
        _webImageBytes = bytes;
        _webImageName = file.name;
        _base64Image = 'data:${file.type};base64,$base64String';
      });

      print('📷 DEBUG: Web image selected for branch update');
    } catch (e) {
      print('❌ DEBUG: Error picking web image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error selecting image: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mobile-specific image picker
  Future<void> _pickImageMobile() async {
    try {
      // Show image source selection dialog
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_camera,
                    label: 'Camera',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        
        setState(() {
          _imageFile = imageFile;
          _base64Image = 'data:image/jpeg;base64,$base64String';
        });

        print('📷 DEBUG: Mobile image selected for branch update');
      }
    } catch (e) {
      print('❌ DEBUG: Error picking mobile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error selecting image: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Platform-agnostic image picker
  Future<void> _pickImage() async {
    if (kIsWeb) {
      await _pickImageWeb();
    } else {
      await _pickImageMobile();
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatebranch() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final branchId = widget.branchData['branch_id'];

      final url = AppConfig.api('/api/iobranch/$branchId');
      print('🌐 DEBUG: Updating branch at: $url');

      final branchData = <String, dynamic>{
        'company_id': CompanyConfig.getCompanyId(), // Keep original company_id
      };
      
      // Only include fields that have values or have been changed
      if (_branchNameController.text.trim().isNotEmpty) {
        branchData['branch_name'] = _branchNameController.text.trim();
      }
      
      if (_branchCodeController.text.trim().isNotEmpty) {
        branchData['branch_code'] = _branchCodeController.text.trim();
      }
      
      if (_provinceNameController.text.trim().isNotEmpty) {
        branchData['province_name'] = _provinceNameController.text.trim();
      }
      
      if (_addressController.text.trim().isNotEmpty) {
        branchData['address'] = _addressController.text.trim();
      }
      
      if (_phoneController.text.trim().isNotEmpty) {
        branchData['phone'] = _phoneController.text.trim();
      }
      
      if (_emailController.text.trim().isNotEmpty) {
        branchData['email'] = _emailController.text.trim();
      }
      
      if (_managerNameController.text.trim().isNotEmpty) {
        branchData['manager_name'] = _managerNameController.text.trim();
      }
      
      if (_base64Image != null) {
        branchData['image'] = _base64Image;
      }

      print('📝 DEBUG: Update data: ${branchData.toString()}');

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(branchData),
      );

      print('📡 DEBUG: Update Response Status: ${response.statusCode}');
      print('📝 DEBUG: Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Branch updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error updating branch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error updating branch: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletebranch() async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Delete Branch'),
            ],
          ),
          content: Text('Are you sure you want to delete "${_branchNameController.text}" (${_branchCodeController.text})? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final branchId = widget.branchData['branch_id'];

      final url = AppConfig.api('/api/iobranch/$branchId');
      print('🗑️ DEBUG: Deleting branch at: $url');

      final response = await http.delete(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📡 DEBUG: Delete Response Status: ${response.statusCode}');
      print('📝 DEBUG: Delete Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Branch deleted successfully!'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context, 'deleted'); // Return 'deleted' to indicate deletion
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error deleting branch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error deleting branch: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.image,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Branch Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_imageFile != null || _webImageBytes != null)
                          ? ThemeConfig.getPrimaryColor(currentTheme)
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildImageContent(),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              kIsWeb 
                  ? 'Click to change image'
                  : 'Tap to change image',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    // Show new selected image
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(
              _webImageBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (!kIsWeb && _imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.file(
              _imageFile!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Show existing image
    else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.network(
              _currentImageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return _buildImagePlaceholder();
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Show placeholder
    else {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo,
          size: 48,
          color: ThemeConfig.getPrimaryColor(currentTheme),
        ),
        SizedBox(height: 12),
        Text(
          kIsWeb ? 'Click to add image' : 'Tap to add image',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Branch'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _deletebranch,
            icon: _isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeConfig.getButtonTextColor(currentTheme),
                      ),
                    ),
                  )
                : Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Branch',
          ),
          if (_isLoading)
            Container(
              margin: EdgeInsets.all(16),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getButtonTextColor(currentTheme),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Branch Image Section
              _buildImageSection(),
              
              SizedBox(height: 20),

              // Branch Information
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Branch Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      
                      _buildTextField(
                        controller: _branchNameController,
                        label: 'Branch Name',
                        icon: Icons.business,
                        hint: 'Enter branch name',
                        required: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Branch name is required';
                          }
                          return null;
                        },
                      ),

                      _buildTextField(
                        controller: _branchCodeController,
                        label: 'Branch Code',
                        icon: Icons.qr_code,
                        hint: 'Enter branch code',
                        required: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Branch code is required';
                          }
                          return null;
                        },
                      ),

                      _buildTextField(
                        controller: _provinceNameController,
                        label: 'Province',
                        icon: Icons.location_city,
                        hint: 'Enter province name',
                      ),

                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on,
                        hint: 'Enter full address',
                      ),

                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone',
                        icon: Icons.phone,
                        hint: 'Enter phone number',
                        keyboardType: TextInputType.phone,
                      ),

                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email,
                        hint: 'Enter email address',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Please enter a valid email address';
                            }
                          }
                          return null;
                        },
                      ),

                      _buildTextField(
                        controller: _managerNameController,
                        label: 'Manager Name',
                        icon: Icons.person,
                        hint: 'Enter manager name',
                      ),
                      
                      // Display read-only company ID
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business_center,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Company ID: ${CompanyConfig.getCompanyId()}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30),

              // Update Button
              Container(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || _isDeleting ? null : _updatebranch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                    foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ThemeConfig.getButtonTextColor(currentTheme),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Updating Branch...',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Update Branch',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}