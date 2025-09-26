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
// For web file handling
import 'package:universal_html/html.dart' as html;

// Models
class Group {
  final int groupId;
  final String groupName;
  final String? imageUrl;

  const Group({
    required this.groupId,
    required this.groupName,
    this.imageUrl,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupId: json['group_id'] as int,
      groupName: json['group_name'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Group && other.groupId == groupId;
  }

  @override
  int get hashCode => groupId.hashCode;
}

class Merchant {
  final int merchantId;
  final String merchantName;
  final String? imageUrl;

  const Merchant({
    required this.merchantId,
    required this.merchantName,
    this.imageUrl,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      merchantId: json['merchant_id'] as int,
      merchantName: json['merchant_name'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Merchant && other.merchantId == merchantId;
  }

  @override
  int get hashCode => merchantId.hashCode;
}

class StoreAddPage extends StatefulWidget {
  const StoreAddPage({Key? key}) : super(key: key);

  @override
  State<StoreAddPage> createState() => _StoreAddPageState();
}

class _StoreAddPageState extends State<StoreAddPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _storeNameController = TextEditingController();
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
  final _upiPercentageController = TextEditingController();
  final _visaPercentageController = TextEditingController();
  final _masterPercentageController = TextEditingController();
  final _accountController = TextEditingController();
  final _account2Controller = TextEditingController();

  // State variables
  String? _base64Image;
  File? _imageFile; // For mobile
  Uint8List? _webImageBytes; // For web
  // ignore: unused_field
  String? _webImageName; // For web
  bool _isLoading = false;
  bool _isLoadingGroups = false;
  bool _isLoadingMerchants = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Dropdown data
  List<Group> _groups = [];
  Group? _selectedGroup;
  List<Merchant> _merchants = [];
  Merchant? _selectedMerchant;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Focus nodes for better keyboard navigation
  final _storeNameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
    _loadUserPhone();
    _loadGroups();
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

  void _loadUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user');
    if (userPhone != null && userPhone.isNotEmpty) {
      setState(() {
        _phoneController.text = userPhone;
      });
      print('Auto-populated phone field with: $userPhone');
    }
  }

  // API Methods
  Future<void> _loadGroups() async {
    if (_isLoadingGroups) return;
    
    setState(() => _isLoadingGroups = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      final url = AppConfig.api('/api/iogroup?company_id=$companyId');
      
      final response = await http.get(
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
          final List<dynamic> groupsJson = responseData['data'];
          setState(() {
            _groups = groupsJson.map((json) => Group.fromJson(json)).toList();
          });
        } else {
          _showSnackBar(message: 'Failed to load groups: ${responseData['message']}', isError: true);
        }
      } else {
        _showSnackBar(message: 'Failed to load groups: Server error ${response.statusCode}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading groups: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  Future<void> _loadMerchants() async {
    if (_selectedGroup == null || _isLoadingMerchants) return;
    
    setState(() {
      _isLoadingMerchants = true;
      _merchants.clear();
      _selectedMerchant = null;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      final url = AppConfig.api('/api/iomerchant/company/$companyId/group/${_selectedGroup!.groupId}');
      
      final response = await http.get(
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
          final List<dynamic> merchantsJson = responseData['data'];
          setState(() {
            _merchants = merchantsJson.map((json) => Merchant.fromJson(json)).toList();
          });
        } else {
          _showSnackBar(message: 'Failed to load merchants: ${responseData['message']}', isError: true);
        }
      } else {
        _showSnackBar(message: 'Failed to load merchants: Server error ${response.statusCode}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading merchants: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMerchants = false);
      }
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
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
    _storeNameFocus.dispose();
    _phoneFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // Web-specific image picking
        await _pickImageWeb();
      } else {
        // Mobile-specific image picking
        await _pickImageMobile();
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar(
        message: 'Error selecting image: $e',
        isError: true,
      );
    }
  }

  Future<void> _pickImageWeb() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files!.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();

      reader.onLoadEnd.listen((e) async {
        final Uint8List bytes = reader.result as Uint8List;
        final String base64String = base64Encode(bytes);
        
        setState(() {
          _webImageBytes = bytes;
          _webImageName = file.name;
          _base64Image = 'data:${file.type};base64,$base64String';
        });

        print('Web image selected and converted to base64');
        _showSnackBar(
          message: 'Image selected successfully',
          isError: false,
        );
      });

      reader.readAsArrayBuffer(file);
    });
  }

  Future<void> _pickImageMobile() async {
    // Show image source selection dialog for mobile
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

      print('Mobile image selected and converted to base64');
      _showSnackBar(
        message: 'Image selected successfully',
        isError: false,
      );
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
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

  Widget _buildImageDisplay() {
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
    } else {
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
          SizedBox(height: 4),
          Text(
            'Recommended: 800x800px',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          if (kIsWeb) ...[
            SizedBox(height: 8),
            Text(
              'Click to browse files',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }
  }

  Future<void> _createStore() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        message: 'Please fill in all required fields',
        isError: true,
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
      print('Creating Store at: $url');

      final storeData = {
        'company_id': companyId.toString(),
        'group_id': _selectedGroup?.groupId,
        'merchant_id': _selectedMerchant?.merchantId,
        'store_name': _storeNameController.text.trim(),
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
      };

      // Only add image if one was selected
      if (_base64Image != null) {
        storeData['image'] = _base64Image!;
      }

      print('Store data: ${storeData.toString()}');

      final response = await http.post(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
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
      print('Error creating Store: $e');
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _getTextOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  int? _parseIntOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  double? _parseDoubleOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Store "${_storeNameController.text}" has been created successfully!'),
            SizedBox(height: 8),
            if (_selectedGroup != null) ...[
              Text('Group: ${_selectedGroup!.groupName}'),
              SizedBox(height: 4),
            ],
            if (_selectedMerchant != null) ...[
              Text('Merchant: ${_selectedMerchant!.merchantName}'),
              SizedBox(height: 4),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to Store list
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
        content: Text('Failed to create Store:\n$error'),
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
    TextInputAction? textInputAction,
    VoidCallback? onFieldSubmitted,
    bool obscureText = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        textInputAction: textInputAction ?? TextInputAction.next,
        onFieldSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted() : null,
        obscureText: obscureText,
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

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) getDisplayText,
    required void Function(T?)? onChanged,
    bool isLoading = false,
    String? hint,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
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
          fillColor: Colors.grey[50],
          suffixIcon: isLoading
              ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.getPrimaryColor(currentTheme)),
                  ),
                )
              : null,
        ),
        items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(getDisplayText(item)),
        )).toList(),
        onChanged: isLoading ? null : onChanged,
      ),
    );
  }

  Widget _buildResponsiveRow(List<Widget> children) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    
    if (isWideScreen && children.length == 2) {
      return Row(
        children: [
          Expanded(child: children[0]),
          SizedBox(width: 16),
          Expanded(child: children[1]),
        ],
      );
    } else {
      return Column(children: children);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final imageSize = isWideScreen ? 200.0 : 180.0;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;

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
        child: Center(
          child: Container(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Store Image Section
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
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (kIsWeb ? _webImageBytes != null : _imageFile != null)
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
                            child: _buildImageDisplay(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),

                  // Basic Information
                  _buildSectionCard(
                    title: 'Store Information',
                    icon: Icons.store,
                    children: [
                      _buildEnhancedTextField(
                        controller: _storeNameController,
                        label: 'Store Name *',
                        icon: Icons.store,
                        focusNode: _storeNameFocus,
                        keyboardType: TextInputType.text,
                        hint: 'Enter store name',
                        textInputAction: TextInputAction.next,
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
                      _buildDropdownField<Group>(
                        label: 'Group (Optional)',
                        icon: Icons.group,
                        value: _selectedGroup,
                        items: _groups,
                        getDisplayText: (group) => group.groupName,
                        isLoading: _isLoadingGroups,
                        hint: _isLoadingGroups ? 'Loading groups...' : 'Select a group',
                        onChanged: (group) {
                          setState(() {
                            _selectedGroup = group;
                            _selectedMerchant = null;
                            _merchants.clear();
                          });
                          if (group != null) _loadMerchants();
                        },
                      ),
                      _buildDropdownField<Merchant>(
                        label: 'Merchant (Optional)',
                        icon: Icons.business,
                        value: _selectedMerchant,
                        items: _merchants,
                        getDisplayText: (merchant) => merchant.merchantName,
                        isLoading: _isLoadingMerchants,
                        hint: _selectedGroup == null
                            ? 'Select a group first'
                            : _isLoadingMerchants
                                ? 'Loading merchants...'
                                : 'Select a merchant',
                        onChanged: (_selectedGroup == null || _isLoadingMerchants) 
                            ? null 
                            : (merchant) => setState(() => _selectedMerchant = merchant),
                      ),
                      _buildEnhancedTextField(
                        controller: _storeManagerController,
                        label: 'Store Manager',
                        icon: Icons.person,
                        hint: 'Enter manager name',
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Contact Information
                  _buildSectionCard(
                    title: 'Contact Information',
                    icon: Icons.contact_phone,
                    children: [
                      _buildResponsiveRow([
                        _buildEnhancedTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Enter email address',
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'
            ).hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                            }
                            return null;
                          },
                        ),
                       
                      ]),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Address Information
                  _buildSectionCard(
                    title: 'Address Information',
                    icon: Icons.location_on,
                    children: [
                      _buildEnhancedTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.home,
                        hint: 'Enter full address',
                        maxLines: 2,
                      ),
                      _buildResponsiveRow([
                        _buildEnhancedTextField(
                          controller: _cityController,
                          label: 'City',
                          icon: Icons.location_city,
                          hint: 'Enter city',
                        ),
                        _buildEnhancedTextField(
                          controller: _stateController,
                          label: 'State',
                          icon: Icons.map,
                          hint: 'Enter state/province',
                        ),
                      ]),
                      _buildResponsiveRow([
                        _buildEnhancedTextField(
                          controller: _countryController,
                          label: 'Country',
                          icon: Icons.public,
                          hint: 'Enter country',
                        ),
                        _buildEnhancedTextField(
                          controller: _postalCodeController,
                          label: 'Postal Code',
                          icon: Icons.local_post_office,
                          hint: 'Enter ZIP/postal code',
                        ),
                      ]),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Store Details
                  _buildSectionCard(
                    title: 'Store Details',
                    icon: Icons.business,
                    children: [
                      _buildResponsiveRow([
                    _buildEnhancedTextField(
                        controller: _notesController,
                        label: 'Notes',
                        icon: Icons.note,
                        hint: 'Additional notes',
                        maxLines: 3,
                      ),
                    ],
                  ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Payment Information
                  _buildSectionCard(
                    title: 'Payment Information',
                    icon: Icons.payment,
                    children: [
                      _buildEnhancedTextField(
                          controller: _masterPercentageController,
                          label: 'MDR Master %',
                          icon: Icons.style,
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
                      _buildEnhancedTextField(
                        controller: _upiPercentageController,
                        label: 'MDR UPI %',
                        icon: Icons.style,
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
                        _buildEnhancedTextField(
                          controller: _visaPercentageController,
                          label: 'MDR Visa %',
                          icon: Icons.style,
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
                      _buildEnhancedTextField(
                          controller: _storeTypeController,
                          label: 'Account Name',
                          icon: Icons.auto_stories,
                          hint: 'e.g., Abc DEF...',
                        ),
                      _buildEnhancedTextField(
                        controller: _accountController,
                        label: 'Account LAK Number',
                        icon: Icons.account_balance,
                        hint: 'e.g., 03XXXXX41XXXXXXX',
                      ),
                      _buildEnhancedTextField(
                        controller: _account2Controller,
                        label: 'Account USD Number',
                        icon: Icons.account_balance,
                        hint: 'e.g., 03XXXXX41XXXXXXX',
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
                        onPressed: _isLoading ? null : _createStore,
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
        ),
      ),
    );
  }
}