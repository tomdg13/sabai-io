import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class StoreEditPage extends StatefulWidget {
  final Map<String, dynamic> storeData;

  const StoreEditPage({Key? key, required this.storeData}) : super(key: key);

  @override
  State<StoreEditPage> createState() => _StoreEditPageState();
}

class _StoreEditPageState extends State<StoreEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _storeNameController;
  late final TextEditingController _storeCodeController;
  late final TextEditingController _storeManagerController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _storeTypeController;
  late final TextEditingController _statusController;
  late final TextEditingController _openingHoursController;
  late final TextEditingController _squareFootageController;
  late final TextEditingController _notesController;
  late final TextEditingController _upiPercentageController;
  late final TextEditingController _visaPercentageController;
  late final TextEditingController _masterPercentageController;
  late final TextEditingController _accountController;

  String? _base64Image;
  String? _currentImageUrl;
  File? _imageFile;
  Uint8List? _webImageBytes; // For web platform
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
    if (mounted) {
      setState(() {
        currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      });
    }
  }

  void _initializeControllers() {
    // Fixed: Use 'store_name' instead of 'store'
    _storeNameController = TextEditingController(text: widget.storeData['store_name'] ?? '');
    _currentImageUrl = widget.storeData['image_url'];

    _storeCodeController = TextEditingController(text: widget.storeData['store_code'] ?? '');
    _storeManagerController = TextEditingController(text: widget.storeData['store_manager'] ?? '');
    _emailController = TextEditingController(text: widget.storeData['email'] ?? '');
    _phoneController = TextEditingController(text: widget.storeData['phone'] ?? '');
    _addressController = TextEditingController(text: widget.storeData['address'] ?? '');
    _cityController = TextEditingController(text: widget.storeData['city'] ?? '');
    _stateController = TextEditingController(text: widget.storeData['state'] ?? '');
    _countryController = TextEditingController(text: widget.storeData['country'] ?? '');
    _postalCodeController = TextEditingController(text: widget.storeData['postal_code'] ?? '');
    _storeTypeController = TextEditingController(text: widget.storeData['store_type'] ?? '');
    _statusController = TextEditingController(text: widget.storeData['status'] ?? '');
    _openingHoursController = TextEditingController(text: widget.storeData['opening_hours'] ?? '');
    _squareFootageController = TextEditingController(text: widget.storeData['square_footage']?.toString() ?? '');
    _notesController = TextEditingController(text: widget.storeData['notes'] ?? '');
    _upiPercentageController = TextEditingController(text: widget.storeData['upi_percentage']?.toString() ?? '');
    _visaPercentageController = TextEditingController(text: widget.storeData['visa_percentage']?.toString() ?? '');
    _masterPercentageController = TextEditingController(text: widget.storeData['master_percentage']?.toString() ?? '');
    _accountController = TextEditingController(text: widget.storeData['account'] ?? '');
    
    print('🔧 DEBUG: Initialized edit form with store: ${widget.storeData['store_name']}');
    print('🔧 DEBUG: Store ID: ${widget.storeData['store_id']}');
    print('🔧 DEBUG: Company ID: ${widget.storeData['company_id']}');
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeCodeController.dispose();
    _storeManagerController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _storeTypeController.dispose();
    _statusController.dispose();
    _openingHoursController.dispose();
    _squareFootageController.dispose();
    _notesController.dispose();
    _upiPercentageController.dispose();
    _visaPercentageController.dispose();
    _masterPercentageController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
                  if (!kIsWeb) // Camera not available on web
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
        final Uint8List imageBytes = await image.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        
        setState(() {
          if (kIsWeb) {
            _webImageBytes = imageBytes;
            _imageFile = null;
          } else {
            _imageFile = File(image.path);
            _webImageBytes = null;
          }
          _base64Image = 'data:image/jpeg;base64,$base64String';
        });

        print('📷 DEBUG: New image selected for store update');
      }
    } catch (e) {
      print('❌ DEBUG: Error picking image: $e');
      if (mounted) {
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

  Future<void> _updateStore() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final storeId = widget.storeData['store_id'];

      final url = AppConfig.api('/api/iostore/$storeId');
      print('🌐 DEBUG: Updating store at: $url');

      final storeData = <String, dynamic>{
        'company_id': CompanyConfig.getCompanyId(),
      };
      
      // Only include fields that have values
      if (_storeNameController.text.trim().isNotEmpty) {
        storeData['store_name'] = _storeNameController.text.trim();
      }
      
      if (_base64Image != null) {
        storeData['image'] = _base64Image;
      }
      
      if (_storeCodeController.text.trim().isNotEmpty) {
        storeData['store_code'] = _storeCodeController.text.trim();
      }
      if (_storeManagerController.text.trim().isNotEmpty) {
        storeData['store_manager'] = _storeManagerController.text.trim();
      }
      if (_emailController.text.trim().isNotEmpty) {
        storeData['email'] = _emailController.text.trim();
      }
      if (_phoneController.text.trim().isNotEmpty) {
        storeData['phone'] = _phoneController.text.trim();
      }
      if (_addressController.text.trim().isNotEmpty) {
        storeData['address'] = _addressController.text.trim();
      }
      if (_cityController.text.trim().isNotEmpty) {
        storeData['city'] = _cityController.text.trim();
      }
      if (_stateController.text.trim().isNotEmpty) {
        storeData['state'] = _stateController.text.trim();
      }
      if (_countryController.text.trim().isNotEmpty) {
        storeData['country'] = _countryController.text.trim();
      }
      if (_postalCodeController.text.trim().isNotEmpty) {
        storeData['postal_code'] = _postalCodeController.text.trim();
      }
      if (_storeTypeController.text.trim().isNotEmpty) {
        storeData['store_type'] = _storeTypeController.text.trim();
      }
      if (_statusController.text.trim().isNotEmpty) {
        storeData['status'] = _statusController.text.trim();
      }
      if (_openingHoursController.text.trim().isNotEmpty) {
        storeData['opening_hours'] = _openingHoursController.text.trim();
      }
      if (_squareFootageController.text.trim().isNotEmpty) {
        storeData['square_footage'] = int.tryParse(_squareFootageController.text.trim());
      }
      if (_notesController.text.trim().isNotEmpty) {
        storeData['notes'] = _notesController.text.trim();
      }
      if (_upiPercentageController.text.trim().isNotEmpty) {
        storeData['upi_percentage'] = double.tryParse(_upiPercentageController.text.trim());
      }
      if (_visaPercentageController.text.trim().isNotEmpty) {
        storeData['visa_percentage'] = double.tryParse(_visaPercentageController.text.trim());
      }
      if (_masterPercentageController.text.trim().isNotEmpty) {
        storeData['master_percentage'] = double.tryParse(_masterPercentageController.text.trim());
      }
      if (_accountController.text.trim().isNotEmpty) {
        storeData['account'] = _accountController.text.trim();
      }

      print('📝 DEBUG: Update data: ${storeData.toString()}');

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      print('📡 DEBUG: Update Response Status: ${response.statusCode}');
      print('📝 DEBUG: Update Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Store updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error updating store: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Error updating store: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteStore() async {
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
              Text('Delete Store'),
            ],
          ),
          content: Text('Are you sure you want to delete "${_storeNameController.text}"? This action cannot be undone.'),
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

    if (!mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final storeId = widget.storeData['store_id'];

      final url = AppConfig.api('/api/iostore/$storeId');
      print('🗑️ DEBUG: Deleting store at: $url');

      final response = await http.delete(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📡 DEBUG: Delete Response Status: ${response.statusCode}');
      print('📝 DEBUG: Delete Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Store deleted successfully!'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context, 'deleted');
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error deleting store: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Error deleting store: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
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
                  'Store Image',
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
              'Tap to change image',
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
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
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
    } else {
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
          'Tap to add image',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveLayout(Widget child) {
    if (kIsWeb) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 800),
          child: child,
        ),
      );
    }
    return child;
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint ?? 'Enter $label',
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Store'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _deleteStore,
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
            tooltip: 'Delete Store',
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
      body: _buildResponsiveLayout(
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Store Image Section
                _buildImageSection(),
                
                SizedBox(height: 20),

                // Store Information
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
                              Icons.store,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Store Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.getPrimaryColor(currentTheme),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        
                        // Basic Information
                        _buildFormField(
                          controller: _storeNameController,
                          label: 'Store Name *',
                          icon: Icons.store,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Store name is required';
                            }
                            return null;
                          },
                        ),

                        if (isWideScreen) ...[
                          // Two-column layout for wide screens
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: _storeCodeController,
                                  label: 'Store Code',
                                  icon: Icons.qr_code,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: _storeManagerController,
                                  label: 'Store Manager',
                                  icon: Icons.person,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: _phoneController,
                                  label: 'Phone',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Single-column layout for mobile
                          _buildFormField(
                            controller: _storeCodeController,
                            label: 'Store Code',
                            icon: Icons.qr_code,
                          ),
                          _buildFormField(
                            controller: _storeManagerController,
                            label: 'Store Manager',
                            icon: Icons.person,
                          ),
                          _buildFormField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _buildFormField(
                            controller: _phoneController,
                            label: 'Phone',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                        ],

                        // Address Information
                        _buildFormField(
                          controller: _addressController,
                          label: 'Address',
                          icon: Icons.home,
                          maxLines: 2,
                        ),

                        if (isWideScreen) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: _cityController,
                                  label: 'City',
                                  icon: Icons.location_city,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: _stateController,
                                  label: 'State',
                                  icon: Icons.map,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: _countryController,
                                  label: 'Country',
                                  icon: Icons.public,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: _postalCodeController,
                                  label: 'Postal Code',
                                  icon: Icons.local_post_office,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildFormField(
                            controller: _cityController,
                            label: 'City',
                            icon: Icons.location_city,
                          ),
                          _buildFormField(
                            controller: _stateController,
                            label: 'State',
                            icon: Icons.map,
                          ),
                          _buildFormField(
                            controller: _countryController,
                            label: 'Country',
                            icon: Icons.public,
                          ),
                          _buildFormField(
                            controller: _postalCodeController,
                            label: 'Postal Code',
                            icon: Icons.local_post_office,
                          ),
                        ],

                        // Store Details
                        if (isWideScreen) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: _storeTypeController,
                                  label: 'Store Type',
                                  icon: Icons.category,
                                  hint: 'e.g., retail, warehouse',
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: _statusController,
                                  label: 'Status',
                                  icon: Icons.info,
                                  hint: 'e.g., active, inactive',
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildFormField(
                            controller: _storeTypeController,
                            label: 'Store Type',
                            icon: Icons.category,
                            hint: 'e.g., retail, warehouse',
                          ),
                          _buildFormField(
                            controller: _statusController,
                            label: 'Status',
                            icon: Icons.info,
                            hint: 'e.g., active, inactive',
                          ),
                        ],

                        _buildFormField(
                          controller: _openingHoursController,
                          label: 'Opening Hours',
                          icon: Icons.access_time,
                          hint: 'e.g., Mon-Fri: 9AM-6PM',
                        ),

                        _buildFormField(
                          controller: _squareFootageController,
                          label: 'Square Footage',
                          icon: Icons.square_foot,
                          keyboardType: TextInputType.number,
                          hint: 'Store size in sq ft',
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final num = int.tryParse(value.trim());
                              if (num == null || num <= 0) {
                                return 'Please enter a valid positive number';
                              }
                            }
                            return null;
                          },
                        ),

                        _buildFormField(
                          controller: _notesController,
                          label: 'Notes',
                          icon: Icons.note,
                          maxLines: 3,
                          hint: 'Additional notes',
                        ),

                        // Company ID (Read-only)
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
                                Icons.business,
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

                SizedBox(height: 20),

                // Payment Information Card
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
                              Icons.payment,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Payment Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.getPrimaryColor(currentTheme),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        if (isWideScreen) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: _upiPercentageController,
                                  label: 'UPI Percentage',
                                  icon: Icons.payment,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  hint: 'e.g., 2.5',
                                  validator: (value) {
                                    if (value != null && value.trim().isNotEmpty) {
                                      final num = double.tryParse(value.trim());
                                      if (num == null || num < 0) {
                                        return 'Please enter a valid non-negative number';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: _visaPercentageController,
                                  label: 'Visa Percentage',
                                  icon: Icons.credit_card,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  hint: 'e.g., 2.5',
                                  validator: (value) {
                                    if (value != null && value.trim().isNotEmpty) {
                                      final num = double.tryParse(value.trim());
                                      if (num == null || num < 0) {
                                        return 'Please enter a valid non-negative number';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  controller: _masterPercentageController,
                                  label: 'MasterCard Percentage',
                                  icon: Icons.credit_card,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  hint: 'e.g., 2.5',
                                  validator: (value) {
                                    if (value != null && value.trim().isNotEmpty) {
                                      final num = double.tryParse(value.trim());
                                      if (num == null || num < 0) {
                                        return 'Please enter a valid non-negative number';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _buildFormField(
                                  controller: _accountController,
                                  label: 'Account',
                                  icon: Icons.account_balance,
                                  hint: 'Account details',
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildFormField(
                            controller: _upiPercentageController,
                            label: 'UPI Percentage',
                            icon: Icons.payment,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            hint: 'e.g., 2.5',
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final num = double.tryParse(value.trim());
                                if (num == null || num < 0) {
                                  return 'Please enter a valid non-negative number';
                                }
                              }
                              return null;
                            },
                          ),
                          _buildFormField(
                            controller: _visaPercentageController,
                            label: 'Visa Percentage',
                            icon: Icons.credit_card,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            hint: 'e.g., 2.5',
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final num = double.tryParse(value.trim());
                                if (num == null || num < 0) {
                                  return 'Please enter a valid non-negative number';
                                }
                              }
                              return null;
                            },
                          ),
                          _buildFormField(
                            controller: _masterPercentageController,
                            label: 'MasterCard Percentage',
                            icon: Icons.credit_card,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            hint: 'e.g., 2.5',
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final num = double.tryParse(value.trim());
                                if (num == null || num < 0) {
                                  return 'Please enter a valid non-negative number';
                                }
                              }
                              return null;
                            },
                          ),
                          _buildFormField(
                            controller: _accountController,
                            label: 'Account',
                            icon: Icons.account_balance,
                            hint: 'Account details',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 30),

                // Update Button
                Container(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading || _isDeleting ? null : _updateStore,
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
                                'Updating Store...',
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
                                'Update Store',
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
      ),
    );
  }
}