import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class StoreEditPage extends StatefulWidget {
  final Map<String, dynamic> storeData;

  const StoreEditPage({Key? key, required this.storeData}) : super(key: key);

  @override
  State<StoreEditPage> createState() => _StoreEditPageState();
}

class _StoreEditPageState extends State<StoreEditPage> with TickerProviderStateMixin {
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
  late final TextEditingController _account2Controller;
  late final TextEditingController _webController;
  late final TextEditingController _email1Controller;
  late final TextEditingController _email2Controller;
  late final TextEditingController _email3Controller;
  late final TextEditingController _email4Controller;
  late final TextEditingController _email5Controller;
  late final TextEditingController _storeModeController;

  String? _base64Image;
  String? _currentImageUrl;
  File? _imageFile;
  Uint8List? _webImageBytes;
  bool _isLoading = false;
  bool _isDeleting = false;
  String currentTheme = ThemeConfig.defaultTheme;
  String? _storeMode;

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _initializeControllers();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
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
    _account2Controller = TextEditingController(text: widget.storeData['account2'] ?? '');
    _webController = TextEditingController(text: widget.storeData['web'] ?? '');
    _email1Controller = TextEditingController(text: widget.storeData['email1'] ?? '');
    _email2Controller = TextEditingController(text: widget.storeData['email2'] ?? '');
    _email3Controller = TextEditingController(text: widget.storeData['email3'] ?? '');
    _email4Controller = TextEditingController(text: widget.storeData['email4'] ?? '');
    _email5Controller = TextEditingController(text: widget.storeData['email5'] ?? '');
    
    // Initialize store mode
    _storeMode = widget.storeData['store_mode'];
    _storeModeController = TextEditingController(text: widget.storeData['store_mode'] ?? '');
    
    print('🔧 DEBUG: Initialized edit form with store: ${widget.storeData['store_name']}');
    print('🔧 DEBUG: Store ID: ${widget.storeData['store_id']}');
    print('🔧 DEBUG: Store Mode: $_storeMode');
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
    _account2Controller.dispose();
    _webController.dispose();
    _email1Controller.dispose();
    _email2Controller.dispose();
    _email3Controller.dispose();
    _email4Controller.dispose();
    _email5Controller.dispose();
    _storeModeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        await _pickImageWeb();
      } else {
        await _pickImageMobile();
      }
    } catch (e) {
      _showSnackBar(message: 'Error selecting image: $e', isError: true);
    }
  }

  Future<void> _pickImageWeb() async {
    // Web image picking implementation
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      final Uint8List imageBytes = await image.readAsBytes();
      final String base64String = base64Encode(imageBytes);
      
      setState(() {
        _webImageBytes = imageBytes;
        _base64Image = 'data:image/jpeg;base64,$base64String';
      });
      
      _showSnackBar(message: 'Image selected successfully', isError: false);
    }
  }

  Future<void> _pickImageMobile() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null && mounted) {
      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);
      
      setState(() {
        _imageFile = imageFile;
        _base64Image = 'data:image/jpeg;base64,$base64String';
      });
      
      _showSnackBar(message: 'Image selected successfully', isError: false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showModalBottomSheet<ImageSource>(
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
            Icon(icon, size: 32, color: ThemeConfig.getPrimaryColor(currentTheme)),
            SizedBox(height: 8),
            Text(label, style: TextStyle(
              fontWeight: FontWeight.w500,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          _webImageBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 400,
        ),
      );
    } else if (!kIsWeb && _imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          _imageFile!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 400,
        ),
      );
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          _currentImageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 400,
          errorBuilder: (context, error, stackTrace) {
            return _buildImagePlaceholder();
          },
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
        Icon(Icons.add_a_photo, size: 48, color: ThemeConfig.getPrimaryColor(currentTheme)),
        SizedBox(height: 12),
        Text('Tap to add image', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        Text('Recommended: 800x800px', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }

  Future<void> _updateStore() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(message: 'Please fix the form errors', isError: true);
      return;
    }

    // Validate online store requirements
    if (_storeMode == 'online' || _storeMode == 'hybrid') {
      if (_webController.text.trim().isEmpty) {
        _showSnackBar(message: 'Website is required for online stores', isError: true);
        return;
      }

      bool hasEmail = _email1Controller.text.trim().isNotEmpty ||
                     _email2Controller.text.trim().isNotEmpty ||
                     _email3Controller.text.trim().isNotEmpty ||
                     _email4Controller.text.trim().isNotEmpty ||
                     _email5Controller.text.trim().isNotEmpty;

      if (!hasEmail) {
        _showSnackBar(message: 'At least one email is required for online stores', isError: true);
        return;
      }
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final storeId = widget.storeData['store_id'];

      final url = AppConfig.api('/api/iostore/$storeId');
      
      final storeData = {
        'company_id': CompanyConfig.getCompanyId(),
        'store_name': _storeNameController.text.trim(),
        'store_code': _getTextOrNull(_storeCodeController),
        'store_manager': _getTextOrNull(_storeManagerController),
        'email': _getTextOrNull(_emailController),
        'phone': _getTextOrNull(_phoneController),
        'address': _getTextOrNull(_addressController),
        'city': _getTextOrNull(_cityController),
        'state': _getTextOrNull(_stateController),
        'country': _getTextOrNull(_countryController),
        'postal_code': _getTextOrNull(_postalCodeController),
        'store_type': _getTextOrNull(_storeTypeController),
        'status': _getTextOrNull(_statusController),
        'opening_hours': _getTextOrNull(_openingHoursController),
        'square_footage': _parseIntOrNull(_squareFootageController),
        'notes': _getTextOrNull(_notesController),
        'upi_percentage': _parseDoubleOrNull(_upiPercentageController),
        'visa_percentage': _parseDoubleOrNull(_visaPercentageController),
        'master_percentage': _parseDoubleOrNull(_masterPercentageController),
        'account': _getTextOrNull(_accountController),
        'account2': _getTextOrNull(_account2Controller),
        'store_mode': _storeMode,
        'web': _getTextOrNull(_webController),
        'email1': _getTextOrNull(_email1Controller),
        'email2': _getTextOrNull(_email2Controller),
        'email3': _getTextOrNull(_email3Controller),
        'email4': _getTextOrNull(_email4Controller),
        'email5': _getTextOrNull(_email5Controller),
      };

      if (_base64Image != null) {
        storeData['image'] = _base64Image!;
      }

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          _showSuccessDialog();
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStore() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
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
      ),
    );

    if (confirm != true) return;

    if (mounted) setState(() => _isDeleting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final storeId = widget.storeData['store_id'];

      final url = AppConfig.api('/api/iostore/$storeId');

      final response = await http.delete(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          _showSnackBar(message: 'Store deleted successfully!', isError: false);
          Navigator.pop(context, 'deleted');
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // Utility methods
  String? _getTextOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  double? _parseDoubleOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  int? _parseIntOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;
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
        content: Text('Store "${_storeNameController.text}" has been updated successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: Text('OK', style: TextStyle(color: ThemeConfig.getPrimaryColor(currentTheme))),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    if (!mounted) return;
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
        content: Text('Failed to update store:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Try Again', style: TextStyle(color: ThemeConfig.getPrimaryColor(currentTheme))),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
    bool enabled = true,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: ThemeConfig.getPrimaryColor(currentTheme)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ThemeConfig.getPrimaryColor(currentTheme), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStoreModeRadio() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            title: Text('Online'),
            value: 'online',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          Divider(height: 1),
          RadioListTile<String>(
            title: Text('Offline'),
            value: 'offline',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          Divider(height: 1),
          RadioListTile<String>(
            title: Text('Online + Offline'),
            value: 'hybrid',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Row(
                children: [
                  Icon(icon, color: ThemeConfig.getPrimaryColor(currentTheme)),
                  SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            else
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(List<Widget> children) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    
    if (isWideScreen && children.length == 2) {
      return Row(
        children: [
          Expanded(child: children[0]),
          SizedBox(width: 16),
          Expanded(child: children[1]),
        ],
      );
    }
    return Column(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final maxWidth = isWideScreen ? 800.0 : double.infinity;
    final imageSize = isWideScreen ? 160.0 : 140.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _isLoading 
            ? Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, 
                      valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.getButtonTextColor(currentTheme)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Updating Store...'),
                ],
              )
            : Text('Edit Store'),
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
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Store Image
                  _buildSectionCard(
                    title: 'Store Image (Optional)',
                    icon: Icons.image,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: _buildImageDisplay(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Store Information
                  _buildSectionCard(
                    title: 'Store Information',
                    icon: Icons.store,
                    children: [
                      _buildTextField(
                        controller: _storeNameController,
                        label: 'Store Name *',
                        icon: Icons.store,
                        hint: 'Enter store name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Store name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Store name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      _buildResponsiveRow([
                        _buildTextField(
                          controller: _storeCodeController,
                          label: 'Store Code',
                          icon: Icons.qr_code,
                          hint: 'Enter store code',
                        ),
                        _buildTextField(
                          controller: _storeManagerController,
                          label: 'Store Manager',
                          icon: Icons.person,
                          hint: 'Enter manager name',
                        ),
                      ]),
                    ],
                  ),

                  // Contact Information
                  _buildSectionCard(
                    title: 'Contact Information',
                    icon: Icons.contact_phone,
                    children: [
                      _buildResponsiveRow([
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Enter email address',
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                            }
                            return null;
                          },
                        ),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          hint: 'Enter phone number',
                        ),
                      ]),
                    ],
                  ),

                  // Address Information
                  _buildSectionCard(
                    title: 'Address Information',
                    icon: Icons.location_on,
                    children: [
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.home,
                        hint: 'Enter full address',
                        maxLines: 2,
                      ),
                      _buildResponsiveRow([
                        _buildTextField(
                          controller: _cityController,
                          label: 'City',
                          icon: Icons.location_city,
                          hint: 'Enter city',
                        ),
                        _buildTextField(
                          controller: _stateController,
                          label: 'State/Province',
                          icon: Icons.map,
                          hint: 'Enter state/province',
                        ),
                      ]),
                      _buildResponsiveRow([
                        _buildTextField(
                          controller: _countryController,
                          label: 'Country',
                          icon: Icons.public,
                          hint: 'Enter country',
                        ),
                        _buildTextField(
                          controller: _postalCodeController,
                          label: 'Postal Code',
                          icon: Icons.local_post_office,
                          hint: 'Enter postal code',
                        ),
                      ]),
                    ],
                  ),

                  // Store Details
                  _buildSectionCard(
                    title: 'Store Details',
                    icon: Icons.business_center,
                    children: [
                      _buildStoreModeRadio(),
                      _buildResponsiveRow([
                        _buildTextField(
                          controller: _storeTypeController,
                          label: 'Store Type',
                          icon: Icons.category,
                          hint: 'e.g., retail, warehouse',
                        ),
                        _buildTextField(
                          controller: _statusController,
                          label: 'Status',
                          icon: Icons.info,
                          hint: 'e.g., active, inactive',
                        ),
                      ]),
                      _buildTextField(
                        controller: _openingHoursController,
                        label: 'Opening Hours',
                        icon: Icons.access_time,
                        hint: 'e.g., Mon-Fri: 9AM-6PM',
                      ),
                      _buildTextField(
                        controller: _squareFootageController,
                        label: 'Square Footage',
                        icon: Icons.square_foot,
                        keyboardType: TextInputType.number,
                        hint: 'Store size in sq ft',
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final num = int.tryParse(value.trim());
                            if (num == null || num <= 0) {
                              return 'Enter a valid positive number';
                            }
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        icon: Icons.note,
                        hint: 'Additional notes',
                        maxLines: 3,
                      ),
                    ],
                  ),

                  // Payment Information
                  _buildSectionCard(
                    title: 'Payment Information',
                    icon: Icons.payment,
                    children: [
                      _buildResponsiveRow([
                        _buildTextField(
                          controller: _masterPercentageController,
                          label: 'MDR Master %',
                          icon: Icons.credit_card,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          hint: '3.0 MAX',
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
                        _buildTextField(
                          controller: _upiPercentageController,
                          label: 'MDR UPI %',
                          icon: Icons.credit_card,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          hint: '3.0 MAX',
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
                      ]),
                      _buildTextField(
                        controller: _visaPercentageController,
                        label: 'MDR Visa %',
                        icon: Icons.credit_card,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        hint: '3.0 MAX',
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
                      _buildResponsiveRow([
                        _buildTextField(
                          controller: _storeTypeController,
                          label: 'Account Name',
                          icon: Icons.account_circle,
                          hint: 'e.g., Abc DEF...',
                        ),
                        _buildTextField(
                          controller: _accountController,
                          label: 'Account LAK Number',
                          icon: Icons.account_balance,
                          hint: 'e.g., 03XXXXX41XXXXXXX',
                        ),
                      ]),
                      _buildTextField(
                        controller: _account2Controller,
                        label: 'Account USD Number',
                        icon: Icons.account_balance_wallet,
                        hint: 'e.g., 03XXXXX41XXXXXXX',
                      ),
                    ],
                  ),

                  // Online Store Information (conditional)
                  if (_storeMode == 'online' || _storeMode == 'hybrid')
                    _buildSectionCard(
                      title: 'Online Store Information',
                      icon: Icons.web,
                      children: [
                        _buildTextField(
                          controller: _webController,
                          label: 'Website',
                          icon: Icons.link,
                          hint: 'www.example.com',
                          keyboardType: TextInputType.url,
                        ),
                        _buildResponsiveRow([
                          _buildTextField(
                            controller: _email1Controller,
                            label: 'Email 1',
                            icon: Icons.email,
                            hint: 'primary@example.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _buildTextField(
                            controller: _email2Controller,
                            label: 'Email 2',
                            icon: Icons.email,
                            hint: 'secondary@example.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ]),
                        _buildResponsiveRow([
                          _buildTextField(
                            controller: _email3Controller,
                            label: 'Email 3',
                            icon: Icons.email,
                            hint: 'support@example.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _buildTextField(
                            controller: _email4Controller,
                            label: 'Email 4',
                            icon: Icons.email,
                            hint: 'sales@example.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ]),
                        _buildTextField(
                          controller: _email5Controller,
                          label: 'Email 5',
                          icon: Icons.email,
                          hint: 'info@example.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),

                  // Update Button
                  Container(
                    width: double.infinity,
                    height: 50,
                    margin: EdgeInsets.symmetric(vertical: 16),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateStore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Updating Store...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, size: 24),
                                SizedBox(width: 12),
                                Text('Update Store', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}