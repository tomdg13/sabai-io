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

class _StoreAddPageState extends State<StoreAddPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, FocusNode> _focusNodes;

  // State variables
  String? _base64Image;
  File? _imageFile;
  bool _isLoading = false;
  bool _isLoadingGroups = false;
  bool _isLoadingMerchants = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Dropdown data
  List<Group> _groups = [];
  Group? _selectedGroup;
  List<Merchant> _merchants = [];
  Merchant? _selectedMerchant;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeFocusNodes();
    _loadCurrentTheme();
    _setupAnimations();
    _loadGroups();
  }

  void _initializeControllers() {
    _controllers = {
      'storeName': TextEditingController(),
      'storeManager': TextEditingController(),
      'email': TextEditingController(),
      'phone': TextEditingController(),
      'address': TextEditingController(),
      'city': TextEditingController(),
      'state': TextEditingController(),
      'country': TextEditingController(),
      'postalCode': TextEditingController(),
      'storeType': TextEditingController(),
      'status': TextEditingController(),
      'openingHours': TextEditingController(),
      'squareFootage': TextEditingController(),
      'notes': TextEditingController(),
      'upiPercentage': TextEditingController(),
      'visaPercentage': TextEditingController(),
      'masterPercentage': TextEditingController(),
      'account': TextEditingController(),
    };
  }

  void _initializeFocusNodes() {
    _focusNodes = {
      for (String key in _controllers.keys) key: FocusNode(),
    };
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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final List<dynamic> groupsJson = responseData['data'];
          setState(() {
            _groups = groupsJson.map((json) => Group.fromJson(json)).toList();
          });
        } else {
          _showErrorSnackBar('Failed to load groups: ${responseData['message']}');
        }
      } else {
        _showErrorSnackBar('Failed to load groups: Server error ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading groups: $e');
    } finally {
      setState(() => _isLoadingGroups = false);
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
      
      // Using the REST-style endpoint format
      final url = AppConfig.api('/api/iomerchant/company/$companyId/group/${_selectedGroup!.groupId}');
      
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final List<dynamic> merchantsJson = responseData['data'];
          setState(() {
            _merchants = merchantsJson.map((json) => Merchant.fromJson(json)).toList();
          });
        } else {
          _showErrorSnackBar('Failed to load merchants: ${responseData['message']}');
        }
      } else {
        _showErrorSnackBar('Failed to load merchants: Server error ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading merchants: $e');
    } finally {
      setState(() => _isLoadingMerchants = false);
    }
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    _focusNodes.values.forEach((focusNode) => focusNode.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  // Image Picker Methods
  Future<void> _pickImage() async {
    try {
      final ImageSource? source = await _showImageSourceDialog();
      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        await _processSelectedImage(image);
        _showSuccessSnackBar('Image selected successfully');
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting image: $e');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(),
            const SizedBox(height: 20),
            const Text(
              'Select Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
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
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 8),
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

  Future<void> _processSelectedImage(XFile image) async {
    final File imageFile = File(image.path);
    final Uint8List imageBytes = await imageFile.readAsBytes();
    final String base64String = base64Encode(imageBytes);

    setState(() {
      _imageFile = imageFile;
      _base64Image = 'data:image/jpeg;base64,$base64String';
    });
  }

  // Form Submission
  Future<void> _createStore() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill in all required fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _submitStoreData();
      await _handleApiResponse(response);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<http.Response> _submitStoreData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final companyId = CompanyConfig.getCompanyId();
    final url = AppConfig.api('/api/iostore');

    final storeData = _buildStoreDataMap(companyId);

    return await http.post(
      Uri.parse(url.toString()),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(storeData),
    );
  }

  Map<String, dynamic> _buildStoreDataMap(int? companyId) {
    return {
      'company_id': companyId?.toString(),
      'group_id': _selectedGroup?.groupId,
      'merchant_id': _selectedMerchant?.merchantId,
      'store_name': _controllers['storeName']!.text.trim(),
      'store_manager': _getTextOrNull('storeManager'),
      'email': _getTextOrNull('email'),
      'phone': _getTextOrNull('phone'),
      'address': _getTextOrNull('address'),
      'city': _getTextOrNull('city'),
      'state': _getTextOrNull('state'),
      'country': _getTextOrNull('country'),
      'postal_code': _getTextOrNull('postalCode'),
      'store_type': _getTextOrNull('storeType'),
      'status': _getTextOrNull('status'),
      'opening_hours': _getTextOrNull('openingHours'),
      'square_footage': _parseIntOrNull(_controllers['squareFootage']!.text),
      'notes': _getTextOrNull('notes'),
      'image': _base64Image,
      'upi_percentage': _parseDoubleOrNull(_controllers['upiPercentage']!.text),
      'visa_percentage': _parseDoubleOrNull(_controllers['visaPercentage']!.text),
      'master_percentage': _parseDoubleOrNull(_controllers['masterPercentage']!.text),
      'account': _getTextOrNull('account'),
    };
  }

  String? _getTextOrNull(String key) {
    final text = _controllers[key]!.text.trim();
    return text.isEmpty ? null : text;
  }

  int? _parseIntOrNull(String text) {
    return text.trim().isEmpty ? null : int.tryParse(text.trim());
  }

  double? _parseDoubleOrNull(String text) {
    return text.trim().isEmpty ? null : double.tryParse(text.trim());
  }

  Future<void> _handleApiResponse(http.Response response) async {
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
  }

  // Dropdown Builders - Fixed Layout for Images
Widget _buildGroupDropdown() {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    height: 60,
    child: DropdownButtonFormField<Group>(
      value: _selectedGroup,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Group',
        hintText: _isLoadingGroups ? 'Loading groups...' : 'Select a group (optional)',
        prefixIcon: Icon(Icons.group, color: ThemeConfig.getPrimaryColor(currentTheme)),
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
        suffixIcon: _isLoadingGroups
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
      items: _groups.map((Group group) {
        return DropdownMenuItem<Group>(
          value: group,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: group.imageUrl != null &&
                      group.imageUrl!.isNotEmpty &&
                      !group.imageUrl!.contains('undefined')
                  ? ClipOval(
                      child: Image.network(
                        group.imageUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.group, color: Colors.grey[600], size: 18);
                        },
                      ),
                    )
                  : Icon(Icons.group, color: Colors.grey[600], size: 18),
            ),
            title: Text(
              group.groupName,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );
      }).toList(),
      onChanged: _isLoadingGroups ? null : (Group? newGroup) {
        setState(() {
          _selectedGroup = newGroup;
          _selectedMerchant = null;
          _merchants.clear();
        });
        if (newGroup != null) {
          _loadMerchants();
        }
      },
    ),
  );
}


  Widget _buildMerchantDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<Merchant>(
        value: _selectedMerchant,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Merchant',
          hintText: _selectedGroup == null
              ? 'Select a group first'
              : _isLoadingMerchants
                  ? 'Loading merchants...'
                  : 'Select a merchant (optional)',
          prefixIcon: Icon(Icons.business, color: ThemeConfig.getPrimaryColor(currentTheme)),
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
          suffixIcon: _isLoadingMerchants
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
        items: _merchants.map((Merchant merchant) {
          return DropdownMenuItem<Merchant>(
            value: merchant,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: merchant.imageUrl != null && 
                       merchant.imageUrl!.isNotEmpty && 
                       !merchant.imageUrl!.contains('undefined')
                    ? ClipOval(
                        child: Image.network(
                          merchant.imageUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.business, color: Colors.grey[600], size: 18);
                          },
                        ),
                      )
                    : Icon(Icons.business, color: Colors.grey[600], size: 18),
              ),
              title: Text(
                merchant.merchantName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        }).toList(),
        onChanged: (_selectedGroup == null || _isLoadingMerchants) ? null : (Merchant? newMerchant) {
          setState(() {
            _selectedMerchant = newMerchant;
          });
        },
      ),
    );
  }

  // UI Helper Methods
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Text('Success!'),
          ],
        ),
        content: Text('Store "${_controllers['storeName']!.text}" has been created successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
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
            const Icon(Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Error'),
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Form Field Builders
  Widget _buildTextField({
    required String controllerKey,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _controllers[controllerKey],
        focusNode: _focusNodes[controllerKey],
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: ThemeConfig.getPrimaryColor(currentTheme)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: ThemeConfig.getPrimaryColor(currentTheme), size: 24),
                    const SizedBox(width: 12),
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
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  // Validation Methods
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        return 'Please enter a valid email address';
      }
    }
    return null;
  }

  String? _validatePositiveNumber(String? value, String fieldName) {
    if (value != null && value.trim().isNotEmpty) {
      final num = int.tryParse(value.trim());
      if (num == null || num <= 0) {
        return 'Please enter a valid $fieldName';
      }
    }
    return null;
  }

  String? _validatePercentage(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      final num = double.tryParse(value.trim());
      if (num == null || num < 0 || num > 100) {
        return 'Enter a valid percentage (0-100)';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageSection(),
              const SizedBox(height: 20),
              _buildStoreInformationSection(),
              const SizedBox(height: 20),
              _buildContactInformationSection(),
              const SizedBox(height: 20),
              _buildAddressInformationSection(),
              const SizedBox(height: 20),
              _buildPaymentInformationSection(),
              const SizedBox(height: 20),
              _buildStoreDetailsSection(),
              const SizedBox(height: 30),
              _buildCreateButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Add New Store'),
      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
      foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
      elevation: 0,
      actions: [
        if (_isLoading)
          Container(
            margin: const EdgeInsets.all(16),
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
    );
  }

  Widget _buildImageSection() {
    return _buildSectionCard(
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _imageFile != null ? _buildSelectedImage() : _buildImagePlaceholder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedImage() {
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
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
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
        const SizedBox(height: 12),
        Text(
          'Tap to add image',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Recommended: 800x800px',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStoreInformationSection() {
    return _buildSectionCard(
      title: 'Store Information',
      icon: Icons.store,
      children: [
        _buildTextField(
          controllerKey: 'storeName',
          label: 'Store Name *',
          icon: Icons.store,
          hint: 'Enter store name',
          validator: (value) => _validateRequired(value, 'Store name'),
        ),
        _buildGroupDropdown(),
        _buildMerchantDropdown(),
        _buildTextField(
          controllerKey: 'storeManager',
          label: 'Store Manager',
          icon: Icons.person,
          hint: 'Enter manager name (optional)',
        ),
      ],
    );
  }

  Widget _buildContactInformationSection() {
    return _buildSectionCard(
      title: 'Contact Information',
      icon: Icons.contact_phone,
      children: [
        _buildTextField(
          controllerKey: 'email',
          label: 'Email',
          icon: Icons.email,
          hint: 'Enter email address (optional)',
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ),
        _buildTextField(
          controllerKey: 'phone',
          label: 'Phone',
          icon: Icons.phone,
          hint: 'Enter phone number (optional)',
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildAddressInformationSection() {
    return _buildSectionCard(
      title: 'Address Information',
      icon: Icons.location_on,
      children: [
        _buildTextField(
          controllerKey: 'address',
          label: 'Address',
          icon: Icons.home,
          hint: 'Enter full address (optional)',
          maxLines: 2,
        ),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controllerKey: 'city',
                label: 'City',
                icon: Icons.location_city,
                hint: 'City',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controllerKey: 'state',
                label: 'State',
                icon: Icons.map,
                hint: 'State/Province',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controllerKey: 'country',
                label: 'Country',
                icon: Icons.public,
                hint: 'Country',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controllerKey: 'postalCode',
                label: 'Postal Code',
                icon: Icons.local_post_office,
                hint: 'ZIP/Postal',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentInformationSection() {
    return _buildSectionCard(
      title: 'Payment Information',
      icon: Icons.payment,
      children: [
        _buildTextField(
          controllerKey: 'upiPercentage',
          label: 'UPI Percentage',
          icon: Icons.percent,
          hint: 'e.g., 1.5',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _validatePercentage,
        ),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controllerKey: 'visaPercentage',
                label: 'Visa Percentage',
                icon: Icons.percent,
                hint: 'e.g., 2.0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePercentage,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controllerKey: 'masterPercentage',
                label: 'Master Percentage',
                icon: Icons.percent,
                hint: 'e.g., 1.8',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePercentage,
              ),
            ),
          ],
        ),
        _buildTextField(
          controllerKey: 'account',
          label: 'Account Number',
          icon: Icons.account_balance,
          hint: 'Enter account number',
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildStoreDetailsSection() {
    return _buildSectionCard(
      title: 'Store Details',
      icon: Icons.business,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controllerKey: 'storeType',
                label: 'Store Type',
                icon: Icons.category,
                hint: 'e.g., retail, warehouse',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controllerKey: 'status',
                label: 'Status',
                icon: Icons.info,
                hint: 'e.g., active, inactive',
              ),
            ),
          ],
        ),
        _buildTextField(
          controllerKey: 'openingHours',
          label: 'Opening Hours',
          icon: Icons.access_time,
          hint: 'e.g., Mon-Fri: 9AM-6PM (optional)',
        ),
        _buildTextField(
          controllerKey: 'squareFootage',
          label: 'Square Footage',
          icon: Icons.square_foot,
          hint: 'Store size in sq ft (optional)',
          keyboardType: TextInputType.number,
          validator: (value) => _validatePositiveNumber(value, 'square footage'),
        ),
        _buildTextField(
          controllerKey: 'notes',
          label: 'Notes',
          icon: Icons.note,
          hint: 'Additional notes (optional)',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _createStore,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
            foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            shadowColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
          ),
          child: _isLoading ? _buildLoadingButton() : _buildCreateButtonContent(),
        ),
      ),
    );
  }

  Widget _buildLoadingButton() {
    return Row(
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
        const SizedBox(width: 16),
        const Text(
          'Creating Store...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCreateButtonContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_circle, size: 24),
        const SizedBox(width: 12),
        const Text(
          'Create Store',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}