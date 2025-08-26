import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
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
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Image picker and photo handling
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  File? _selectedIdImage;
  String? _photoBase64;
  String? _photoIdBase64;

  // Controllers for all form fields
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _documentIdController;
  late TextEditingController _accountNoController;
  late TextEditingController _accountNameController;
  late TextEditingController _bioController;

  // Dropdown selections
  String _selectedRole = 'office';
  String _selectedStatus = 'active';

  // Branch data
  List<Map<String, dynamic>> _branches = [];
  Map<String, dynamic>? _selectedBranch;
  bool _isLoadingBranches = false;

  final List<String> _roles = ['office', 'admin', 'user'];
  final List<String> _statuses = ['active', 'inactive'];

  @override
  void initState() {
    super.initState();
    _loadLangCode();
    _loadCurrentTheme();
    _initializeControllers();
    _loadBranches();
  }

  void _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    print('=== USER DATA DEBUG ===');
    print('Full userData: ${widget.userData}');
    print('branch_id: ${widget.userData['branch_id']}');
    print('branch_id type: ${widget.userData['branch_id'].runtimeType}');
    print('=======================');
    
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _usernameController = TextEditingController(text: widget.userData['username'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _documentIdController = TextEditingController(text: widget.userData['document_id'] ?? '');
    _accountNoController = TextEditingController(text: widget.userData['account_no'] ?? '');
    _accountNameController = TextEditingController(text: widget.userData['account_name'] ?? '');
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    
    // Set initial dropdown values
    _selectedRole = widget.userData['role'] ?? 'office';
    _selectedStatus = widget.userData['status'] ?? 'active';
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final url = AppConfig.api('/api/iobranch');

      print('=== BRANCH LOADING DEBUG ===');
      print('User branch_id from userData: ${widget.userData['branch_id']}');
      print('Loading branches from: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['data'] != null) {
          final List<dynamic> branchList = data['data'];
          
          setState(() {
            _branches = branchList.map((branch) => {
              'id': branch['branch_id'],
              'branch_name': branch['branch_name'] ?? 'Unknown Branch',
              'branch_code': branch['branch_code'] ?? '',
              'address': branch['address'] ?? '',
              'image_url': branch['image_url'] ?? '',
            }).toList();
            
            print('Available branches: ${_branches.length}');
            _branches.forEach((branch) {
              print('Branch ID: ${branch['id']}, Name: ${branch['branch_name']}');
            });
            
            // Find and set the user's current branch
            final userBranchId = widget.userData['branch_id'];
            if (userBranchId != null) {
              _selectedBranch = _branches.firstWhere(
                (branch) => branch['id'].toString() == userBranchId.toString(),
                orElse: () {
                  print('WARNING: User branch_id $userBranchId not found in branch list');
                  return _branches.isNotEmpty ? _branches[0] : {};
                },
              );
              print('Selected branch: ${_selectedBranch?['branch_name']} (ID: ${_selectedBranch?['id']})');
            } else {
              print('WARNING: No branch_id found in user data');
              if (_branches.isNotEmpty) {
                _selectedBranch = _branches[0];
                print('Default selected to first branch: ${_selectedBranch?['branch_name']}');
              }
            }
            
            _isLoadingBranches = false;
          });
        } else {
          print('ERROR: Invalid branch API response: ${data['status']}');
          setState(() {
            _isLoadingBranches = false;
          });
        }
      } else {
        print('ERROR: Branch API request failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          _isLoadingBranches = false;
        });
      }
    } catch (e) {
      print('ERROR: Exception loading branches: $e');
      setState(() {
        _isLoadingBranches = false;
      });
    }
  }

  // Image picker methods
  Future<void> _pickImage({bool isIdImage = false}) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
                title: Text(SimpleTranslations.get(langCode, 'gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery, isIdImage: isIdImage);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
                title: Text(SimpleTranslations.get(langCode, 'camera')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera, isIdImage: isIdImage);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromSource(ImageSource source, {bool isIdImage = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final List<int> imageBytes = await imageFile.readAsBytes();

        if (imageBytes.length > 500000) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image too large. Please select a smaller image.'),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
            ),
          );
          return;
        }

        final String base64String = base64Encode(imageBytes);
        final String dataUrl = 'data:image/jpeg;base64,$base64String';

        setState(() {
          if (isIdImage) {
            _selectedIdImage = imageFile;
            _photoIdBase64 = dataUrl;
          } else {
            _selectedImage = imageFile;
            _photoBase64 = dataUrl;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image selected successfully'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
        ),
      );
    }
  }

  Widget _buildImagePicker({
    required String title,
    required String subtitle,
    required File? selectedImage,
    required String? existingImageUrl,
    required VoidCallback onTap,
    IconData icon = Icons.add_a_photo,
  }) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                width: 2,
              ),
            ),
            child: selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      selectedImage,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  )
                : (existingImageUrl != null && existingImageUrl.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          existingImageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  size: 30,
                                  color: ThemeConfig.getPrimaryColor(currentTheme),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ThemeConfig.getPrimaryColor(currentTheme),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 30,
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 10,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${SimpleTranslations.get(langCode, 'branch') ?? 'Branch'} *',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _isLoadingBranches
              ? Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeConfig.getPrimaryColor(currentTheme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Loading branches...'),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedBranch != null && _branches.contains(_selectedBranch) ? _selectedBranch : null,
                    hint: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Select branch'),
                    ),
                    isExpanded: true,
                    items: _branches.map((branch) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: branch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              // branch Image
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: branch['image_url'] != null &&
                                        branch['image_url']
                                            .toString()
                                            .isNotEmpty &&
                                        !branch['image_url'].toString().contains('undefined')
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.network(
                                          branch['image_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[100],
                                              child: Icon(
                                                Icons.location_on,
                                                color: Colors.grey[400],
                                                size: 16,
                                              ),
                                            );
                                          },
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              color: Colors.grey[100],
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 1.5,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[100],
                                        child: Icon(
                                          Icons.location_on,
                                          color: Colors.grey[400],
                                          size: 16,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              // branch Name
                              Expanded(
                                child: Text(
                                  branch['branch_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedBranch = value),
                  ),
                ),
        ),
        if (_selectedBranch == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              'Branch is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        // Show current selection for debugging
        if (_selectedBranch != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              'Selected: ${_selectedBranch!['branch_name']} (ID: ${_selectedBranch!['id']})',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _documentIdController.dispose();
    _accountNoController.dispose();
    _accountNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _deleteUser() async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(SimpleTranslations.get(langCode, 'confirm_delete')),
          content: Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(SimpleTranslations.get(langCode, 'cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
              ),
              child: Text('Delete'),
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
      
      final phone = widget.userData['phone'];
      final url = AppConfig.api('/api/iouser/update/$phone');

      final deleteData = {
        'status': 'delete',
      };

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(deleteData),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            ),
          );
          Navigator.pop(context, 'deleted');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Delete failed'),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: $e'),
          backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
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
      
      final phone = widget.userData['phone'];
      final url = AppConfig.api('/api/iouser/update/$phone');

      // Add detailed logging
      print('=== UPDATE USER DEBUG ===');
      print('Phone: $phone');
      print('URL: $url');
      print('Token: Bearer $token');

      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim().isEmpty ? null : _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'status': _selectedStatus,
        'branch_id': _selectedBranch?['id'],
        'document_id': _documentIdController.text.trim().isEmpty ? null : _documentIdController.text.trim(),
        'account_no': _accountNoController.text.trim().isEmpty ? null : _accountNoController.text.trim(),
        'account_name': _accountNameController.text.trim().isEmpty ? null : _accountNameController.text.trim(),
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        'language': langCode,
      };

      // Add photos only if new ones were selected
      if (_photoBase64 != null) {
        updateData['photo'] = _photoBase64;
      }
      if (_photoIdBase64 != null) {
        updateData['photo_id'] = _photoIdBase64;
      }

      print('Request Body: ${jsonEncode(updateData)}');
      print('========================');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      print('=== UPDATE RESPONSE DEBUG ===');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('==============================');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User updated successfully'),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Update failed'),
              backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
          ),
        );
      }
    } catch (e) {
      print('=== UPDATE ERROR DEBUG ===');
      print('Error: $e');
      print('Error Type: ${e.runtimeType}');
      print('==========================');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user: $e'),
          backgroundColor: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool required = false,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
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
          prefixIcon: icon != null ? Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ) : null,
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                if (label.toLowerCase().contains('email')) {
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                }
                return null;
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'edit_user')),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            onPressed: _deleteUser,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete User',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Selection Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildImagePicker(
                          title: 'Profile Photo',
                          subtitle: 'Tap to change profile image',
                          selectedImage: _selectedImage,
                          existingImageUrl: widget.userData['photo'],
                          onTap: () => _pickImage(isIdImage: false),
                          icon: Icons.person,
                        ),
                        _buildImagePicker(
                          title: 'ID Document',
                          subtitle: 'Tap to change ID photo',
                          selectedImage: _selectedIdImage,
                          existingImageUrl: widget.userData['photo_id'],
                          onTap: () => _pickImage(isIdImage: true),
                          icon: Icons.badge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Basic Information Section
                    const Text(
                      'Basic Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      required: true,
                      icon: Icons.person,
                    ),

                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.account_circle,
                    ),

                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      required: true,
                      icon: Icons.email,
                    ),

                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      required: true,
                      icon: Icons.phone,
                    ),

                    const SizedBox(height: 24),

                    // Organization Section
                    const Text(
                      'Organization Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Branch Dropdown
                    _buildBranchDropdown(),
                    const SizedBox(height: 16),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.work,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _roles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedRole = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.info,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _statuses.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedStatus = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Additional Information Section
                    const Text(
                      'Additional Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _documentIdController,
                      label: 'Document ID',
                      icon: Icons.badge,
                    ),

                    _buildTextField(
                      controller: _accountNameController,
                      label: 'Account Name',
                      icon: Icons.account_balance,
                    ),

                    _buildTextField(
                      controller: _accountNoController,
                      label: 'Account Number',
                      icon: Icons.credit_card,
                    ),

                    _buildTextField(
                      controller: _bioController,
                      label: 'Bio',
                      maxLines: 3,
                      icon: Icons.description,
                    ),

                    const SizedBox(height: 32),

                    // Update Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ThemeConfig.getButtonTextColor(currentTheme),
                                ),
                              ),
                            )
                          : Text(
                              'UPDATE USER',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Cancel Button
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pop(context, false);
                            },
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}