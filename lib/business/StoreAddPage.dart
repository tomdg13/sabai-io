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

class storeAddPage extends StatefulWidget {
  const storeAddPage({Key? key}) : super(key: key);

  @override
  State<storeAddPage> createState() => _storeAddPageState();
}

class _storeAddPageState extends State<storeAddPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // All form controllers to match API columns
  final _storeNameController = TextEditingController();
  final _storeCodeController = TextEditingController();
  final _storeManagerController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _storeTypeController = TextEditingController();
  final _statusController = TextEditingController();
  final _openingHoursController = TextEditingController();
  final _squareFootageController = TextEditingController();
  final _notesController = TextEditingController();
   // New payment-related controllers
  final _upiPercentageController = TextEditingController();
  final _visaPercentageController = TextEditingController();
  final _masterPercentageController = TextEditingController();
  final _accountController = TextEditingController();

  String? _base64Image;
  File? _imageFile;
  bool _isLoading = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Focus nodes for better keyboard navigation
  final _storeNameFocus = FocusNode();
  final _storeCodeFocus = FocusNode();
  final _storeManagerFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _stateFocus = FocusNode();
  final _countryFocus = FocusNode();
  final _postalCodeFocus = FocusNode();
  final _storeTypeFocus = FocusNode();
  final _statusFocus = FocusNode();
  final _openingHoursFocus = FocusNode();
  final _squareFootageFocus = FocusNode();
  final _notesFocus = FocusNode();

  // New payment-related focus nodes
  final _upiPercentageFocus = FocusNode();
  final _visaPercentageFocus = FocusNode();
  final _masterPercentageFocus = FocusNode();
  final _accountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  @override
  void dispose() {
    // Dispose all controllers
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
    
    // Dispose all focus nodes
    _storeNameFocus.dispose();
    _storeCodeFocus.dispose();
    _storeManagerFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _cityFocus.dispose();
    _stateFocus.dispose();
    _countryFocus.dispose();
    _postalCodeFocus.dispose();
    _storeTypeFocus.dispose();
    _statusFocus.dispose();
    _openingHoursFocus.dispose();
    _squareFootageFocus.dispose();
    _notesFocus.dispose();
    _upiPercentageFocus.dispose();
    _visaPercentageFocus.dispose();
    _masterPercentageFocus.dispose();
    _accountFocus.dispose();
    
    _fadeController.dispose();
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

        print('📷 DEBUG: Image selected and converted to base64');
        
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Image selected successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ DEBUG: Error picking image: $e');
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

  Future<void> _createstore() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please fill in all required fields'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      final url = AppConfig.api('/api/iostore');
      print('🌐 DEBUG: Creating store at: $url');

      // ✅ COMPLETE: Send all available fields to match API/database schema
      final storeData = {
        'company_id': companyId,
        'store_name': _storeNameController.text.trim(),
        'store_code': _storeCodeController.text.trim().isEmpty ? null : _storeCodeController.text.trim(),
        'store_manager': _storeManagerController.text.trim().isEmpty ? null : _storeManagerController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        'country': _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        'postal_code': _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
        'store_type': _storeTypeController.text.trim().isEmpty ? null : _storeTypeController.text.trim(),
        'status': _statusController.text.trim().isEmpty ? null : _statusController.text.trim(),
        'opening_hours': _openingHoursController.text.trim().isEmpty ? null : _openingHoursController.text.trim(),
        'square_footage': _squareFootageController.text.trim().isEmpty ? null : int.tryParse(_squareFootageController.text.trim()),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'image': _base64Image,

          // New payment fields
        'upi_percentage': _upiPercentageController.text.trim().isEmpty ? null : double.tryParse(_upiPercentageController.text.trim()),
        'visa_percentage': _visaPercentageController.text.trim().isEmpty ? null : double.tryParse(_visaPercentageController.text.trim()),
        'master_percentage': _masterPercentageController.text.trim().isEmpty ? null : double.tryParse(_masterPercentageController.text.trim()),
        'account': _accountController.text.trim().isEmpty ? null : _accountController.text.trim(),
     
      };

      print('📝 DEBUG: store data: ${storeData.toString()}');

      final response = await http.post(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      print('📡 DEBUG: Response Status: ${response.statusCode}');
      print('📝 DEBUG: Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          // Show success dialog instead of just snackbar
          _showSuccessDialog();
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error creating store: $e');
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Text('Store "${_storeNameController.text}" has been created successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to store list
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text('Failed to create store:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Try Again',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
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
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
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
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Add New Store'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          if (_isLoading)
            Container(
              margin: EdgeInsets.all(16),
              width: 24,
              height: 24,
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
              // Store Image Section
              _buildSectionCard(
                title: 'Store Image',
                icon: Icons.image,
                children: [
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
                            color: _imageFile != null 
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
                        child: _imageFile != null
                            ? ClipRRect(
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
                              )
                            : Column(
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
                                  SizedBox(height: 4),
                                  Text(
                                    'Recommended: 800x800px',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),

              // Basic Information Section
              _buildSectionCard(
                title: 'Store Information',
                icon: Icons.store,
                children: [
                  _buildEnhancedTextField(
                    controller: _storeNameController,
                    label: 'Store Name *',
                    icon: Icons.store,
                    focusNode: _storeNameFocus,
                    hint: 'Enter store name',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Store name is required';
                      }
                      return null;
                    },
                  ),
                  _buildEnhancedTextField(
                    controller: _storeCodeController,
                    label: 'Store Code',
                    icon: Icons.qr_code,
                    focusNode: _storeCodeFocus,
                    hint: 'Enter store code (optional)',
                  ),
                  _buildEnhancedTextField(
                    controller: _storeManagerController,
                    label: 'Store Manager',
                    icon: Icons.person,
                    focusNode: _storeManagerFocus,
                    hint: 'Enter manager name (optional)',
                  ),
                ],
              ),
              
              SizedBox(height: 20),

              // Contact Information Section
              _buildSectionCard(
                title: 'Contact Information',
                icon: Icons.contact_phone,
                children: [
                  _buildEnhancedTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    focusNode: _emailFocus,
                    hint: 'Enter email address (optional)',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                      }
                      return null;
                    },
                  ),
                  _buildEnhancedTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    icon: Icons.phone,
                    focusNode: _phoneFocus,
                    hint: 'Enter phone number (optional)',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              
              SizedBox(height: 20),

              // Address Information Section
              _buildSectionCard(
                title: 'Address Information',
                icon: Icons.location_on,
                children: [
                  _buildEnhancedTextField(
                    controller: _addressController,
                    label: 'Address',
                    icon: Icons.home,
                    focusNode: _addressFocus,
                    hint: 'Enter full address (optional)',
                    maxLines: 2,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _cityController,
                          label: 'City',
                          icon: Icons.location_city,
                          focusNode: _cityFocus,
                          hint: 'City',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _stateController,
                          label: 'State',
                          icon: Icons.map,
                          focusNode: _stateFocus,
                          hint: 'State/Province',
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _countryController,
                          label: 'Country',
                          icon: Icons.public,
                          focusNode: _countryFocus,
                          hint: 'Country',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _postalCodeController,
                          label: 'Postal Code',
                          icon: Icons.local_post_office,
                          focusNode: _postalCodeFocus,
                          hint: 'ZIP/Postal',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 20),

              _buildSectionCard(
                title: 'Payment Information',
                icon: Icons.payment,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _upiPercentageController,
                          label: 'UPI Percentage',
                          icon: Icons.percent,
                          focusNode: _upiPercentageFocus,
                          hint: 'e.g., 1.5',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final num = double.tryParse(value.trim());
                              if (num == null || num < 0 || num > 100) {
                                return 'Enter a valid percentage (0-100)';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _visaPercentageController,
                          label: 'Visa Percentage',
                          icon: Icons.percent,
                          focusNode: _visaPercentageFocus,
                          hint: 'e.g., 2.0',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final num = double.tryParse(value.trim());
                              if (num == null || num < 0 || num > 100) {
                                return 'Enter a valid percentage (0-100)';
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
                        child: _buildEnhancedTextField(
                          controller: _masterPercentageController,
                          label: 'Master Percentage',
                          icon: Icons.percent,
                          focusNode: _masterPercentageFocus,
                          hint: 'e.g., 1.8',
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final num = double.tryParse(value.trim());
                              if (num == null || num < 0 || num > 100) {
                                return 'Enter a valid percentage (0-100)';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _accountController,
                          label: 'Account Number',
                          icon: Icons.account_balance,
                          focusNode: _accountFocus,
                          hint: 'Enter account number',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 20),

              // Store Details Section
              _buildSectionCard(
                title: 'Store Details',
                icon: Icons.business,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _storeTypeController,
                          label: 'Store Type',
                          icon: Icons.category,
                          focusNode: _storeTypeFocus,
                          hint: 'e.g., retail, warehouse',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildEnhancedTextField(
                          controller: _statusController,
                          label: 'Status',
                          icon: Icons.info,
                          focusNode: _statusFocus,
                          hint: 'e.g., active, inactive',
                        ),
                      ),
                    ],
                  ),
                  _buildEnhancedTextField(
                    controller: _openingHoursController,
                    label: 'Opening Hours',
                    icon: Icons.access_time,
                    focusNode: _openingHoursFocus,
                    hint: 'e.g., Mon-Fri: 9AM-6PM (optional)',
                  ),
                  _buildEnhancedTextField(
                    controller: _squareFootageController,
                    label: 'Square Footage',
                    icon: Icons.square_foot,
                    focusNode: _squareFootageFocus,
                    hint: 'Store size in sq ft (optional)',
                    keyboardType: TextInputType.number,
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
                  _buildEnhancedTextField(
                    controller: _notesController,
                    label: 'Notes',
                    icon: Icons.note,
                    focusNode: _notesFocus,
                    hint: 'Additional notes (optional)',
                    maxLines: 3,
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Create Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createstore,
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
                                'Creating Store...',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Create Store',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
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