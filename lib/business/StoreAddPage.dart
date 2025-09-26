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
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

// Import the postal code data
import 'postal_code_data.dart';

// Existing Models
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

class _StoreAddPageState extends State<StoreAddPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  
  // All Controllers - optimized with less frequent rebuilds
  late final TextEditingController _storeNameController;
  late final TextEditingController _storeManagerController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _storeTypeController;
  late final TextEditingController _notesController;
  late final TextEditingController _upiPercentageController;
  late final TextEditingController _visaPercentageController;
  late final TextEditingController _masterPercentageController;
  late final TextEditingController _accountController;
  late final TextEditingController _account2Controller;
  late final TextEditingController _store_modeController;
  late final TextEditingController _webController;
  late final TextEditingController _email1Controller;
  late final TextEditingController _email2Controller;
  late final TextEditingController _email3Controller;
  late final TextEditingController _email4Controller;
  late final TextEditingController _email5Controller;

  // State Variables
  String? _storeMode;
  PostalCode? _selectedPostalCode;
  String? _base64Image;
  File? _imageFile;
  Uint8List? _webImageBytes;
  String? _webImageName;
  bool _isLoading = false;
  bool _isLoadingGroups = false;
  bool _isLoadingMerchants = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Cached postal codes for better performance
  late final List<PostalCode> _cachedPostalCodes;

  // Dropdown Data
  List<Group> _groups = [];
  Group? _selectedGroup;
  List<Merchant> _merchants = [];
  Merchant? _selectedMerchant;

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeCachedData();
    _loadCurrentTheme();
    _setupAnimations();
    _loadUserPhone();
    _loadGroups();
  }

  void _initializeControllers() {
    _storeNameController = TextEditingController();
    _storeManagerController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _countryController = TextEditingController();
    _postalCodeController = TextEditingController();
    _storeTypeController = TextEditingController();
    _notesController = TextEditingController();
    _upiPercentageController = TextEditingController();
    _visaPercentageController = TextEditingController();
    _masterPercentageController = TextEditingController();
    _accountController = TextEditingController();
    _account2Controller = TextEditingController();
    _store_modeController = TextEditingController();
    _webController = TextEditingController();
    _email1Controller = TextEditingController();
    _email2Controller = TextEditingController();
    _email3Controller = TextEditingController();
    _email4Controller = TextEditingController();
    _email5Controller = TextEditingController();
  }

  void _initializeCachedData() {
    // Cache postal codes to avoid repeated calls
    _cachedPostalCodes = PostalCodeData.getAllPostalCodes();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced animation time
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

  void _loadUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user');
    if (userPhone != null && userPhone.isNotEmpty && mounted) {
      _phoneController.text = userPhone;
    }
  }

  // Optimized API Methods
  Future<void> _loadGroups() async {
    if (_isLoadingGroups) return;
    
    if (mounted) setState(() => _isLoadingGroups = true);
    
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
          if (mounted) {
            setState(() {
              _groups = groupsJson.map((json) => Group.fromJson(json)).toList();
            });
          }
        }
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
    
    if (mounted) {
      setState(() {
        _isLoadingMerchants = true;
        _merchants.clear();
        _selectedMerchant = null;
      });
    }
    
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
          if (mounted) {
            setState(() {
              _merchants = merchantsJson.map((json) => Merchant.fromJson(json)).toList();
            });
          }
        }
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
    _notesController.dispose();
    _upiPercentageController.dispose();
    _visaPercentageController.dispose();
    _masterPercentageController.dispose();
    _accountController.dispose();
    _account2Controller.dispose();
    _store_modeController.dispose();
    _webController.dispose();
    _email1Controller.dispose();
    _email2Controller.dispose();
    _email3Controller.dispose();
    _email4Controller.dispose();
    _email5Controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Optimized Image Handling
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
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files!.isEmpty) return;

      final file = files[0];
      if (file.size > 5 * 1024 * 1024) { // 5MB limit
        _showSnackBar(message: 'Image size must be less than 5MB', isError: true);
        return;
      }

      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) async {
        if (mounted) {
          final Uint8List bytes = reader.result as Uint8List;
          final String base64String = base64Encode(bytes);
          
          setState(() {
            _webImageBytes = bytes;
            _webImageName = file.name;
            _base64Image = 'data:${file.type};base64,$base64String';
          });

          _showSnackBar(message: 'Image selected successfully', isError: false);
        }
      });

      reader.readAsArrayBuffer(file);
    });
  }

  Future<void> _pickImageMobile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
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

  Widget _buildImageDisplay() {
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          _webImageBytes!, 
          fit: BoxFit.cover, 
          width: double.infinity, 
          height: double.infinity,
          cacheWidth: 400, // Cache optimization
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
          cacheWidth: 400, // Cache optimization
        ),
      );
    } else {
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
  }

  // Update your _createStore() method with these console logs:

Future<void> _createStore() async {
  FocusScope.of(context).unfocus();
  
  if (!_formKey.currentState!.validate()) {
    _showSnackBar(message: 'Please fill in all required fields', isError: true);
    return;
  }

  // Validate online store requirements
  if (_storeMode == 'online' || _storeMode == 'online+offline') {
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
    final companyId = CompanyConfig.getCompanyId();

    final url = AppConfig.api('/api/iostore');
    
    // Console log: URL being called
    print('🌐 API URL: $url');
    print('🏢 Company ID: $companyId');
    print('🔑 Token exists: ${token != null}');

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
      'notes': _getTextOrNull(_notesController),
      'upi_percentage': _parseDoubleOrNull(_upiPercentageController),
      'visa_percentage': _parseDoubleOrNull(_visaPercentageController),
      'master_percentage': _parseDoubleOrNull(_masterPercentageController),
      'account': _getTextOrNull(_accountController),
      'account2': _getTextOrNull(_account2Controller),
      'store_mode': _getTextOrNull(_store_modeController),
      'web': _getTextOrNull(_webController),
      'email1': _getTextOrNull(_email1Controller),
      'email2': _getTextOrNull(_email2Controller),
      'email3': _getTextOrNull(_email3Controller),
      'email4': _getTextOrNull(_email4Controller),
      'email5': _getTextOrNull(_email5Controller),
    };

    if (_base64Image != null) {
      storeData['image'] = _base64Image!;
      print('📷 Image included in request (base64 length: ${_base64Image!.length})');
    }

    // Console log: Request body (without image data to keep it readable)
    final storeDataForLog = Map<String, dynamic>.from(storeData);
    if (storeDataForLog.containsKey('image')) {
      storeDataForLog['image'] = '[BASE64_IMAGE_DATA_${_base64Image!.length}_CHARS]';
    }
    
    print('📤 REQUEST BODY:');
    print('================');
    storeDataForLog.forEach((key, value) {
      print('$key: $value');
    });
    print('================');

    final response = await http.post(
      Uri.parse(url.toString()),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(storeData),
    );

    // Console log: Response details
    print('📥 RESPONSE:');
    print('================');
    print('Status Code: ${response.statusCode}');
    print('Headers: ${response.headers}');
    print('Body: ${response.body}');
    print('================');

    if (!mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      print('✅ SUCCESS: ${responseData['status']}');
      print('📋 Response Data: $responseData');
      
      if (responseData['status'] == 'success') {
        _showSuccessDialog();
      } else {
        print('❌ API returned success status but with error message');
        throw Exception(responseData['message'] ?? 'Unknown error');
      }
    } else {
      print('❌ HTTP ERROR: ${response.statusCode}');
      final errorData = jsonDecode(response.body);
      print('🚨 Error Data: $errorData');
      throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
    }
  } catch (e) {
    print('💥 EXCEPTION CAUGHT: $e');
    print('📍 Exception Type: ${e.runtimeType}');
    if (mounted) _showErrorDialog(e.toString());
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
  // Utility methods (unchanged)
  String? _getTextOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  double? _parseDoubleOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2), // Reduced duration
      ),
    );
  }

  void _logFormData() {
  print('📝 CURRENT FORM DATA:');
  print('===================');
  print('Store Name: ${_storeNameController.text}');
  print('Store Manager: ${_storeManagerController.text}');
  print('Email: ${_emailController.text}');
  print('Phone: ${_phoneController.text}');
  print('Address: ${_addressController.text}');
  print('City: ${_cityController.text}');
  print('State: ${_stateController.text}');
  print('Country: ${_countryController.text}');
  print('Postal Code: ${_postalCodeController.text}');
  print('Selected Group: ${_selectedGroup?.groupName}');
  print('Selected Merchant: ${_selectedMerchant?.merchantName}');
  print('Store Mode: $_storeMode');
  print('Website: ${_webController.text}');
  print('Email1: ${_email1Controller.text}');
  print('Email2: ${_email2Controller.text}');
  print('Email3: ${_email3Controller.text}');
  print('Email4: ${_email4Controller.text}');
  print('Email5: ${_email5Controller.text}');
  print('===================');
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
        content: Text('Store "${_storeNameController.text}" has been created successfully!'),
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
        content: Text('Failed to create store:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Try Again', style: TextStyle(color: ThemeConfig.getPrimaryColor(currentTheme))),
          ),
        ],
      ),
    );
  }

  // Optimized UI Building Methods
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

  Widget _buildDropdown<T>({
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
          filled: true,
          fillColor: Colors.white,
          suffixIcon: isLoading ? SizedBox(
            width: 20,
            height: 20,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ) : null,
        ),
        items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(getDisplayText(item)),
        )).toList(),
        onChanged: isLoading ? null : onChanged,
        menuMaxHeight: 200, // Reduced height for better performance
      ),
    );
  }

  Widget _buildPostalCodeDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Autocomplete<PostalCode>(
        displayStringForOption: (PostalCode option) => 
            '${option.code} - ${option.district}, ${option.province}',
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == '') {
            return _cachedPostalCodes.take(10); // Show first 10 when empty
          }
          final String query = textEditingValue.text.toLowerCase();
          return _cachedPostalCodes.where((PostalCode option) {
            return option.code.toLowerCase().contains(query) ||
                   option.district.toLowerCase().contains(query) ||
                   option.province.toLowerCase().contains(query);
          }).take(20); // Limit results for performance
        },
        onSelected: (PostalCode selection) {
          _selectedPostalCode = selection;
          _postalCodeController.text = selection.code;
          setState(() {});
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          // Set initial value if postal code is already selected
          if (_selectedPostalCode != null && controller.text.isEmpty) {
            controller.text = '${_selectedPostalCode!.code} - ${_selectedPostalCode!.district}, ${_selectedPostalCode!.province}';
          }
          
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            onEditingComplete: onEditingComplete,
            decoration: InputDecoration(
              labelText: 'Postal Code',
              hintText: 'Type to search postal codes...',
              prefixIcon: Icon(
                Icons.local_post_office,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              suffixIcon: Icon(
                Icons.search,
                color: Colors.grey[600],
              ),
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
              fillColor: Colors.white,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: BoxConstraints(maxHeight: 200, maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final PostalCode option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: index < options.length - 1
                              ? Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                option.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.getPrimaryColor(currentTheme),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.district,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    option.province,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
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
              _storeMode = value;
              _store_modeController.text = value ?? '';
              setState(() {});
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          Divider(height: 1),
          RadioListTile<String>(
            title: Text('Offline'),
            value: 'offline',
            groupValue: _storeMode,
            onChanged: (String? value) {
              _storeMode = value;
              _store_modeController.text = value ?? '';
              setState(() {});
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          Divider(height: 1),
          RadioListTile<String>(
            title: Text('Online + Offline'),
            value: 'hybrid',
            groupValue: _storeMode,
            onChanged: (String? value) {
              _storeMode = value;
              _store_modeController.text = value ?? '';
              setState(() {});
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final maxWidth = isWideScreen ? 800.0 : double.infinity;
    final imageSize = isWideScreen ? 160.0 : 140.0; // Smaller image for performance

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
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
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
                        _buildDropdown<Group>(
                          label: 'Group (Optional)',
                          icon: Icons.group,
                          value: _selectedGroup,
                          items: _groups,
                          getDisplayText: (group) => group.groupName,
                          isLoading: _isLoadingGroups,
                          hint: 'Select group',
                          onChanged: (group) {
                            _selectedGroup = group;
                            _selectedMerchant = null;
                            _merchants.clear();
                            setState(() {});
                            if (group != null) _loadMerchants();
                          },
                        ),
                        _buildDropdown<Merchant>(
                          label: 'Merchant (Optional)',
                          icon: Icons.business,
                          value: _selectedMerchant,
                          items: _merchants,
                          getDisplayText: (merchant) => merchant.merchantName,
                          isLoading: _isLoadingMerchants,
                          hint: 'Select merchant',
                          onChanged: _selectedGroup == null ? null : (merchant) {
                            _selectedMerchant = merchant;
                            setState(() {});
                          },
                        ),
                      ]),
                      _buildTextField(
                        controller: _storeManagerController,
                        label: 'Store Manager',
                        icon: Icons.person,
                        hint: 'Enter manager name',
                      ),
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
                        _buildPostalCodeDropdown(),
                      ]),
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


                  // Store Details
                  _buildSectionCard(
                    title: 'Store Details',
                    icon: Icons.business_center,
                    children: [
                      _buildStoreModeRadio(),
                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        icon: Icons.note,
                        hint: 'Additional notes',
                        maxLines: 3,
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

                  // Create Button
                  Container(
                    width: double.infinity,
                    height: 50,
                    margin: EdgeInsets.symmetric(vertical: 16),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createStore,
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
                                Text('Creating Store...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_business, size: 24),
                                SizedBox(width: 12),
                                Text('Create Store', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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