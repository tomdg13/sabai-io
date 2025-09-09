import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../config/config.dart';
import '../config/theme.dart';
import '../utils/simple_translations.dart';

class UserAddPage extends StatefulWidget {
  const UserAddPage({super.key});

  @override
  State<UserAddPage> createState() => _UserAddPageState();
}

class _UserAddPageState extends State<UserAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = _Controllers();
  
  String _selectedRole = 'office';
  File? _selectedImage;
  String _base64Image = '';
  bool _isLoading = false;
  String _langCode = 'en';
  String _currentTheme = ThemeConfig.defaultTheme;

  _CompanyData? _companyData;
  _BranchData _branchData = _BranchData();

  final List<String> _roles = ['office', 'admin', 'user'];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPreferences();
    await _loadCompanyData();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _langCode = prefs.getString('languageCode') ?? 'en';
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _loadCompanyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = CompanyConfig.getCompanyId();
      final companyName = prefs.getString('company_name') ?? 'Unknown Company';

      setState(() {
        _companyData = _CompanyData(id: companyId, name: companyName);
      });

      await _loadBranches();
        } catch (e) {
      setState(() {
        _companyData = _CompanyData(id: null, name: '');
      });
      _showErrorSnackBar(_translate('error_loading_company_info'));
    }
  }

  Future<void> _loadBranches() async {
    if (!mounted) return;
    
    setState(() {
      _branchData = _branchData.copyWith(isLoading: true);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = _companyData?.id;
      
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['data'] != null) {
          final branches = (data['data'] as List)
              .map((branch) => _Branch.fromJson(branch))
              .toList();
          
          setState(() {
            _branchData = _branchData.copyWith(
              branches: branches,
              isLoading: false,
            );
          });
        } else {
          setState(() {
            _branchData = _branchData.copyWith(isLoading: false);
          });
          _showErrorSnackBar(_translate('no_branches_found'));
        }
      } else {
        setState(() {
          _branchData = _branchData.copyWith(isLoading: false);
        });
        _showErrorSnackBar('Failed to load branches: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _branchData = _branchData.copyWith(isLoading: false);
      });
      _showErrorSnackBar('Error loading branches: $e');
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      await _pickImageFromSource(ImageSource.gallery);
    } else {
      _showImageSourceBottomSheet();
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            _buildImageSourceTile(Icons.photo_library, _translate('gallery'), ImageSource.gallery),
            _buildImageSourceTile(Icons.camera_alt, _translate('camera'), ImageSource.camera),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceTile(IconData icon, String title, ImageSource source) {
    return ListTile(
      leading: Icon(icon, color: ThemeConfig.getPrimaryColor(_currentTheme)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        _pickImageFromSource(source);
      },
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
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
        _selectedImage = kIsWeb ? null : File(image.path);
        _base64Image = dataUrl;
      });

      _showSuccessSnackBar(_translate('image_selected_successfully'));
    } catch (e) {
      _showErrorSnackBar(_translate('error_selecting_image'));
    }
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate() || _branchData.selectedBranch == null) {
      if (_branchData.selectedBranch == null) {
        _showErrorSnackBar('Please select a branch');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final url = AppConfig.api('/api/iouser/add');

      final requestBody = _buildRequestBody();

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      _handleAddUserResponse(response);
    } catch (e) {
      _showErrorSnackBar(_translate('network_error_occurred'));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildRequestBody() {
    return {
      'phone': _controllers.phone.text.trim(),
      'name': _controllers.name.text.trim(),
      'email': _controllers.email.text.trim(),
      'role': _selectedRole,
      'company_id': _companyData?.id,
      'branch_id': _branchData.selectedBranch!.id,
      'photo': _base64Image,
      'status': 'resetpassword',
      'document_id': _controllers.documentId.text.trim().nullIfEmpty,
      'username': _controllers.phone.text.trim(),
      'account_no': _controllers.accountNo.text.trim().nullIfEmpty,
      'account_name': _controllers.accountName.text.trim().nullIfEmpty,
      'language': _langCode,
    };
  }

  void _handleAddUserResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showSuccessSnackBar('${_translate('user_added_successfully')} ${_companyData?.name}!');
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar(data['message'] ?? _translate('unknown_error_occurred'));
      }
    } else {
      _handleErrorResponse(response);
    }
  }

  void _handleErrorResponse(http.Response response) {
    try {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['message'] ?? 
          errorData['error'] ?? 
          _translate('unknown_server_error');
      _showErrorSnackBar('${_translate('server_error')} (${response.statusCode}): $errorMessage');
    } catch (e) {
      _showErrorSnackBar('${_translate('error')} ${response.statusCode}: ${response.body}');
    }
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
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
              child: _buildImageContent(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _translate('tap_to_select_profile_image'),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    if (_selectedImage != null || _base64Image.isNotEmpty) {
      return ClipOval(
        child: kIsWeb && _base64Image.isNotEmpty
            ? Image.memory(
                base64Decode(_base64Image.split(',')[1]),
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              )
            : _selectedImage != null
                ? Image.file(
                    _selectedImage!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                : const SizedBox(),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo,
          size: 40,
          color: ThemeConfig.getPrimaryColor(_currentTheme),
        ),
        const SizedBox(height: 4),
        Text(
          _translate('add_photo'),
          style: TextStyle(
            fontSize: 10,
            color: ThemeConfig.getPrimaryColor(_currentTheme),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            borderRadius: BorderRadius.circular(4),
          ),
          child: _branchData.isLoading
              ? _buildLoadingIndicator()
              : _buildBranchDropdownButton(),
        ),
        if (_branchData.selectedBranch == null)
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

  Widget _buildLoadingIndicator() {
    return Container(
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
    );
  }

  Widget _buildBranchDropdownButton() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<_Branch>(
        value: _branchData.selectedBranch,
        hint: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Select branch'),
        ),
        isExpanded: true,
        items: _branchData.branches.map(_buildBranchMenuItem).toList(),
        onChanged: (branch) => setState(() {
          _branchData = _branchData.copyWith(selectedBranch: branch);
        }),
      ),
    );
  }

  DropdownMenuItem<_Branch> _buildBranchMenuItem(_Branch branch) {
    return DropdownMenuItem<_Branch>(
      value: branch,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _buildBranchImage(branch),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                branch.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchImage(_Branch branch) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: branch.imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(
                branch.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultBranchIcon(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildLoadingBranchIcon();
                },
              ),
            )
          : _buildDefaultBranchIcon(),
    );
  }

  Widget _buildDefaultBranchIcon() {
    return Container(
      color: Colors.grey[100],
      child: Icon(
        Icons.location_on,
        color: Colors.grey[400],
        size: 16,
      ),
    );
  }

  Widget _buildLoadingBranchIcon() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileImageSection(),
        const SizedBox(height: 32),
        if (_isWebWideScreen) ..._buildWebLayout() else ..._buildMobileLayout(),
        const SizedBox(height: 16),
        _buildBranchDropdown(),
        const SizedBox(height: 32),
        _buildActionButtons(),
      ],
    );
  }

  bool get _isWebWideScreen => kIsWeb && MediaQuery.of(context).size.width > 600;

  List<Widget> _buildWebLayout() {
    return [
      Row(
        children: [
          Expanded(child: _buildPhoneField()),
          const SizedBox(width: 16),
          Expanded(child: _buildNameField()),
          
          
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _buildDocumentIdField()),
          const SizedBox(width: 16),
          
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _buildEmailField()),
          const SizedBox(width: 16),
          Expanded(child: _buildRoleDropdown()),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _buildAccountNameField()),
          const SizedBox(width: 16),
          Expanded(child: _buildAccountNumberField()),
        ],
      ),
    ];
  }

  List<Widget> _buildMobileLayout() {
    return [
      _buildNameField(),
      const SizedBox(height: 16),
      _buildUsernameField(),
      const SizedBox(height: 16),
      _buildDocumentIdField(),
      const SizedBox(height: 16),
      _buildAccountNameField(),
      const SizedBox(height: 16),
      _buildAccountNumberField(),
      const SizedBox(height: 16),
      _buildPhoneField(),
      const SizedBox(height: 16),
      _buildEmailField(),
      const SizedBox(height: 16),
      _buildRoleDropdown(),
    ];
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _controllers.name,
      decoration: _buildInputDecoration(
        _translate('full_name_required'),
        _translate('enter_full_name'),
        Icons.person,
      ),
      validator: (value) => _validateName(value),
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _controllers.username,
      readOnly: true, // Make username read-only since it auto-fills from phone
      decoration: _buildInputDecoration(
        'Username (Auto-filled from phone)',
        'Username will be same as phone number',
        Icons.account_circle,
      ).copyWith(
        fillColor: Colors.grey[100], // Slightly different color to show it's read-only
      ),
    );
  }

  Widget _buildDocumentIdField() {
    return TextFormField(
      controller: _controllers.documentId,
      decoration: _buildInputDecoration('Document ID (Optional)', 'Enter document/ID number', Icons.badge),
    );
  }

  Widget _buildAccountNameField() {
    return TextFormField(
      controller: _controllers.accountName,
      decoration: _buildInputDecoration('Account Name (Optional)', 'Enter bank account name', Icons.account_balance),
    );
  }

  Widget _buildAccountNumberField() {
    return TextFormField(
      controller: _controllers.accountNo,
      decoration: _buildInputDecoration('Account Number (Optional)', 'Enter bank account number', Icons.credit_card),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _controllers.phone,
      keyboardType: TextInputType.phone,
      decoration: _buildInputDecoration(
        _translate('phone_number_required'),
        _translate('enter_phone_number'),
        Icons.phone,
      ),
      validator: (value) => _validatePhone(value),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _controllers.email,
      keyboardType: TextInputType.emailAddress,
      decoration: _buildInputDecoration(
        _translate('email_required'),
        _translate('enter_email_address'),
        Icons.email,
      ),
      validator: (value) => _validateEmail(value),
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: _buildInputDecoration(_translate('role_required'), '', Icons.work),
      items: _roles.map((role) => DropdownMenuItem(
        value: role,
        child: Text(role.toUpperCase()),
      )).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() => _selectedRole = newValue);
        }
      },
      validator: (value) => value?.isEmpty == true ? _translate('please_select_role') : null,
    );
  }

  Widget _buildActionButtons() {
    final isEnabled = !_isLoading && _companyData?.id != null && _branchData.selectedBranch != null;
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isEnabled ? _addUser : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled 
                  ? ThemeConfig.getPrimaryColor(_currentTheme) 
                  : Colors.grey,
              foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    isEnabled 
                        ? _translate('add_user').toUpperCase()
                        : 'SELECT COMPANY & BRANCH',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: Text(
            _translate('cancel').toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ThemeConfig.getPrimaryColor(_currentTheme),
          width: 2,
        ),
      ),
      prefixIcon: Icon(icon, color: ThemeConfig.getPrimaryColor(_currentTheme)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  String? _validateName(String? value) {
    if (value?.trim().isEmpty == true) {
      return _translate('please_enter_name');
    }
    if (value!.trim().length < 2) {
      return _translate('name_must_be_at_least_2_characters');
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value?.trim().isEmpty == true) {
      return _translate('please_enter_phone_number');
    }
    if (value!.trim().length < 8) {
      return _translate('phone_number_must_be_at_least_8_digits');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value?.trim().isEmpty == true) {
      return _translate('please_enter_email_address');
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!.trim())) {
      return _translate('please_enter_valid_email_address');
    }
    return null;
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
        title: Text(_translate('add_user')),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
        elevation: 0,
      ),
      body: _companyData == null
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getPrimaryColor(_currentTheme),
                ),
              ),
            )
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: kIsWeb && MediaQuery.of(context).size.width > 800 ? 800 : double.infinity,
                  ),
                  padding: EdgeInsets.all(kIsWeb ? 32 : 16),
                  child: Form(
                    key: _formKey,
                    child: _buildFormContent(),
                  ),
                ),
              ),
            ),
    );
  }
}

// Data Classes
class _Controllers {
  final phone = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final documentId = TextEditingController();
  final accountNo = TextEditingController();
  final accountName = TextEditingController();
  final username = TextEditingController();

  void dispose() {
    phone.dispose();
    name.dispose();
    email.dispose();
    documentId.dispose();
    accountNo.dispose();
    accountName.dispose();
    username.dispose();
  }
}

class _CompanyData {
  final int? id;
  final String name;

  const _CompanyData({required this.id, required this.name});
}

class _Branch {
  final int id;
  final String name;
  final String code;
  final String address;
  final String imageUrl;

  const _Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.imageUrl,
  });

  factory _Branch.fromJson(Map<String, dynamic> json) {
    return _Branch(
      id: json['branch_id'] as int,
      name: json['branch_name'] ?? 'Unknown Branch',
      code: json['branch_code'] ?? '',
      address: json['address'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }
}

class _BranchData {
  final List<_Branch> branches;
  final _Branch? selectedBranch;
  final bool isLoading;

  const _BranchData({
    this.branches = const [],
    this.selectedBranch,
    this.isLoading = false,
  });

  _BranchData copyWith({
    List<_Branch>? branches,
    _Branch? selectedBranch,
    bool? isLoading,
  }) {
    return _BranchData(
      branches: branches ?? this.branches,
      selectedBranch: selectedBranch ?? this.selectedBranch,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Extensions
extension StringExtensions on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}