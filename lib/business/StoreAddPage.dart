import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

// Import the postal code data
import 'postal_code_data.dart';

// Import MCC data
import 'mcc_data.dart';

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
  late final TextEditingController _mccCodeController;
  late final TextEditingController _account_nameController;
  late final TextEditingController _cifController;

  // State Variables
  String? _storeMode;
  PostalCode? _selectedPostalCode;
  MccCode? _selectedMccCode;
  String? _base64Image;
  File? _imageFile;
  Uint8List? _webImageBytes;
  String? _webImageName;
  bool _isLoading = false;
  bool _isLoadingGroups = false;
  bool _isLoadingMerchants = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Cached data for better performance
  late final List<PostalCode> _cachedPostalCodes;
  late final List<MccCode> _cachedMccCodes;

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
    _mccCodeController = TextEditingController();
    _account_nameController = TextEditingController();
    _cifController = TextEditingController();
  }

  void _initializeCachedData() {
    // Cache postal codes and MCC codes to avoid repeated calls
    _cachedPostalCodes = PostalCodeData.getAllPostalCodes();
    _cachedMccCodes = MccData.getAllMccCodes();
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
    _mccCodeController.dispose();
    _account_nameController.dispose();
    _cifController.dispose();
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
      if (file.size > 5 * 1024 * 1024) {
        _showSnackBar(message: 'Image size must be less than 5MB', isError: true);
        return;
      }

      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) async {
        if (mounted) {
          final Uint8List bytes = reader.result as Uint8List;
          
          // Compress the image for web
          final compressedBytes = await _compressImageWeb(bytes);
          final String base64String = base64Encode(compressedBytes);
          
          setState(() {
            _webImageBytes = compressedBytes;
            _webImageName = file.name;
            _base64Image = 'data:image/jpeg;base64,$base64String';
          });

          _showSnackBar(message: 'Image selected and compressed successfully', isError: false);
        }
      });

      reader.readAsArrayBuffer(file);
    });
  }

  // Add image compression method for web (simplified approach)
  Future<Uint8List> _compressImageWeb(Uint8List imageBytes) async {
    try {
      // Create a canvas element for image processing
      final canvas = html.CanvasElement();
      final ctx = canvas.context2D;
      
      // Create an image element
      final img = html.ImageElement();
      final completer = Completer<Uint8List>();
      
      img.onLoad.listen((_) {
        // Calculate new dimensions (max 400x400)
        double width = img.width!.toDouble();
        double height = img.height!.toDouble();
        
        if (width > 400 || height > 400) {
          if (width > height) {
            height = height * (400 / width);
            width = 400;
          } else {
            width = width * (400 / height);
            height = 400;
          }
        }
        
        // Set canvas size
        canvas.width = width.round();
        canvas.height = height.round();
        
        // Draw the image
        ctx.drawImageScaled(img, 0, 0, width, height);
        
        // Get the compressed image data
        try {
          final dataUrl = canvas.toDataUrl('image/jpeg', 0.6);
          final base64Data = dataUrl.split(',')[1];
          completer.complete(base64Decode(base64Data));
        } catch (e) {
          print('Canvas compression failed: $e');
          completer.complete(imageBytes);
        }
      });
      
      img.onError.listen((_) {
        print('Image loading failed');
        completer.complete(imageBytes);
      });
      
      // Convert bytes to blob URL
      final blob = html.Blob([imageBytes]);
      img.src = html.Url.createObjectUrlFromBlob(blob);
      
      return await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Image compression timed out');
          return imageBytes;
        },
      );
    } catch (e) {
      print('Image compression failed: $e');
      return imageBytes; // Return original if compression fails
    }
  }

  Future<void> _pickImageMobile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,  // Reduced from 800
      maxHeight: 400, // Reduced from 800
      imageQuality: 60, // Reduced from 85
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
        borderRadius: BorderRadius.circular(16),
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
          Icon(Icons.add_a_photo, size: 48, color: ThemeConfig.getPrimaryColor(currentTheme)),
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
            'Recommended: 400x400px',
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
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(message: 'Please fill in all required fields', isError: true);
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
      final companyId = CompanyConfig.getCompanyId();

      final url = AppConfig.api('/api/iostore');
      
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
        'mcc': _selectedMccCode?.code, // Backend expects 'mcc' not 'mcc_code'
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
        'account_name': _getTextOrNull(_account_nameController),
        'cif': _getTextOrNull(_cifController),
      };

      if (_base64Image != null) {
        storeData['image'] = _base64Image!;
        print('📷 Image included in request (base64 length: ${_base64Image!.length})');
      }

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
        duration: Duration(seconds: 2),
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
    print('MCC Code: ${_selectedMccCode?.code} - ${_selectedMccCode?.nameEnglish}');
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
        menuMaxHeight: 200,
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
            return _cachedPostalCodes.take(10);
          }
          final String query = textEditingValue.text.toLowerCase();
          return _cachedPostalCodes.where((PostalCode option) {
            return option.code.toLowerCase().contains(query) ||
                   option.district.toLowerCase().contains(query) ||
                   option.province.toLowerCase().contains(query);
          }).take(20);
        },
        onSelected: (PostalCode selection) {
          _selectedPostalCode = selection;
          _postalCodeController.text = selection.code;
          setState(() {});
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
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

  Widget _buildMccCodeDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Autocomplete<MccCode>(
        displayStringForOption: (MccCode option) => 
            '${option.code} - ${option.nameEnglish} (${option.nameLao})',
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == '') {
            return _cachedMccCodes.take(10);
          }
          final String query = textEditingValue.text.toLowerCase();
          return _cachedMccCodes.where((MccCode option) {
            return option.code.toLowerCase().contains(query) ||
                   option.nameEnglish.toLowerCase().contains(query) ||
                   option.nameLao.toLowerCase().contains(query) ||
                   option.category.toLowerCase().contains(query);
          }).take(20);
        },
        onSelected: (MccCode selection) {
          _selectedMccCode = selection;
          _mccCodeController.text = selection.code;
          setState(() {});
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          if (_selectedMccCode != null && controller.text.isEmpty) {
            controller.text = '${_selectedMccCode!.code} - ${_selectedMccCode!.nameEnglish}';
          }
          
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            onEditingComplete: onEditingComplete,
            decoration: InputDecoration(
              labelText: 'MCC Code (Optional)',
              hintText: 'Type to search MCC codes...',
              prefixIcon: Icon(
                Icons.category,
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
                constraints: BoxConstraints(maxHeight: 200, maxWidth: 500),
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
                    final MccCode option = options.elementAt(index);
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
                                    option.nameEnglish,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    option.nameLao,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Category: ${option.category}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Add New Store',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (kDebugMode)
            IconButton(
              onPressed: _logFormData,
              icon: Icon(Icons.bug_report),
              tooltip: 'Log Form Data',
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Store Image Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            'Store Image (Optional)',
                            style: TextStyle(
                              fontSize: 20,
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
                            width: 200,
                            height: 200,
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
                ),

                SizedBox(height: 20),

                // Basic Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Group Dropdown
                      _buildDropdown<Group>(
                        label: 'Select Group',
                        icon: Icons.group,
                        value: _selectedGroup,
                        items: _groups,
                        getDisplayText: (group) => group.groupName,
                        onChanged: (Group? group) {
                          setState(() {
                            _selectedGroup = group;
                            _selectedMerchant = null;
                          });
                          if (group != null) {
                            _loadMerchants();
                          }
                        },
                        isLoading: _isLoadingGroups,
                        hint: 'Choose a group...',
                      ),

                      // Merchant Dropdown
                      _buildDropdown<Merchant>(
                        label: 'Select Merchant',
                        icon: Icons.business,
                        value: _selectedMerchant,
                        items: _merchants,
                        getDisplayText: (merchant) => merchant.merchantName,
                        onChanged: (Merchant? merchant) {
                          setState(() {
                            _selectedMerchant = merchant;
                          });
                        },
                        isLoading: _isLoadingMerchants,
                        hint: _selectedGroup == null ? 'Select a group first' : 'Choose a merchant...',
                      ),

                      // Store Name
                      _buildTextField(
                        controller: _storeNameController,
                        label: 'Store Name *',
                        icon: Icons.store,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Store name is required';
                          }
                          return null;
                        },
                        hint: 'Enter store name',
                      ),

                      // Store Manager
                      _buildTextField(
                        controller: _storeManagerController,
                        label: 'Store Manager',
                        icon: Icons.person,
                        hint: 'Enter manager name',
                      ),

                      // Store Mode
                      Text(
                        'Store Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildStoreModeRadio(),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Contact Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

                      _buildTextField(
                        controller: _emailController,
                        label: 'Main Email',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        hint: 'Enter main email address',
                      ),

                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        hint: 'Enter phone number',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Address Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Address Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on,
                        maxLines: 2,
                        hint: 'Enter full address',
                      ),

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
                        hint: 'Enter state or province',
                      ),

                      _buildTextField(
                        controller: _countryController,
                        label: 'Country',
                        icon: Icons.flag,
                        hint: 'Enter country',
                      ),

                      _buildPostalCodeDropdown(),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Business Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

                      _buildTextField(
                        controller: _storeTypeController,
                        label: 'Store Type',
                        icon: Icons.category,
                        hint: 'e.g., Retail, Restaurant, Service',
                      ),

                      _buildMccCodeDropdown(),

                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        icon: Icons.note,
                        maxLines: 3,
                        hint: 'Any additional notes about the store',
                      ),
                    ],
                  ),
                ),

                // Online Store Information (Conditional)
                if (_storeMode == 'online' || _storeMode == 'hybrid') ...[
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Online Store Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.getPrimaryColor(currentTheme),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        _buildTextField(
                          controller: _webController,
                          label: 'Website URL *',
                          icon: Icons.web,
                          keyboardType: TextInputType.url,
                          hint: 'https://example.com',
                          validator: (_storeMode == 'online' || _storeMode == 'hybrid') 
                              ? (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Website is required for online stores';
                                  }
                                  return null;
                                }
                              : null,
                        ),

                        Text(
                          'Additional Email Addresses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),

                        _buildTextField(
                          controller: _email1Controller,
                          label: 'Email 1',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),

                        _buildTextField(
                          controller: _email2Controller,
                          label: 'Email 2',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),

                        _buildTextField(
                          controller: _email3Controller,
                          label: 'Email 3',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),

                        _buildTextField(
                          controller: _email4Controller,
                          label: 'Email 4',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),

                        _buildTextField(
                          controller: _email5Controller,
                          label: 'Email 5',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 20),

                // Payment Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _upiPercentageController,
                              label: 'UPI %',
                              icon: Icons.payment,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              hint: '0.00',
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _visaPercentageController,
                              label: 'Visa %',
                              icon: Icons.credit_card,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              hint: '0.00',
                            ),
                          ),
                        ],
                      ),

                      _buildTextField(
                        controller: _masterPercentageController,
                        label: 'Mastercard %',
                        icon: Icons.credit_card,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        hint: '0.00',
                      ),

                      _buildTextField(
                        controller: _cifController,
                        label: 'CIF',
                        icon: Icons.account_balance,
                        hint: 'Enter CIF number',
                      ),

                      _buildTextField(
                        controller: _account_nameController,
                        label: 'Account Name',
                        icon: Icons.account_balance_wallet,
                        hint: 'Enter account holder name',
                      ),

                      _buildTextField(
                        controller: _accountController,
                        label: 'Primary Account',
                        icon: Icons.account_balance,
                        hint: 'Primary account number',
                      ),

                      _buildTextField(
                        controller: _account2Controller,
                        label: 'Secondary Account',
                        icon: Icons.account_balance,
                        hint: 'Secondary account number',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                // Submit Button
                Container(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Creating Store...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Create Store',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
    );
  }
}