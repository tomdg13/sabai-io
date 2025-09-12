import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:inventory/business/UserAdd.dart';
import 'package:inventory/business/UserEdit.dart';
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPage extends StatefulWidget {
  const UserPage({Key? key}) : super(key: key);

  @override
  State<UserPage> createState() => _UserPageState();
}

String langCode = 'en';

class _UserPageState extends State<UserPage> {
  List<User> users = [];
  List<User> filteredUsers = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('UserPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchUsers();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterUsers(_searchController.text);
    });
  }

  void _loadLangCode() async {
    print('Loading language code...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
      print('Language code loaded: $langCode');
    });
  }

  void _loadCurrentTheme() async {
    print('Loading current theme...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      print('Theme loaded: $currentTheme');
    });
  }

  @override
  void dispose() {
    print('UserPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterUsers(String query) {
    print('Filtering users with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredUsers = users.where((user) {
        if (user.status == 'delete') return false;
        
        final nameLower = user.name.toLowerCase();
        final phoneLower = user.phone.toLowerCase();
        final usernameLower = user.username.toLowerCase();
        bool matches = nameLower.contains(lowerQuery) || 
                      phoneLower.contains(lowerQuery) ||
                      usernameLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('Filtered users count: ${filteredUsers.length}');
    });
  }

  Future<void> fetchUsers() async {
    print('Starting fetchUsers()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchUsers()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iouser/iouserRole');
    print('API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('Company ID: $companyId');
      
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      print('Request headers: $headers');
      
      final body = jsonEncode({'role': 'Admin', 'company_id': companyId});
      print('Request body: $body');
      
      final response = await http.post(url, headers: headers, body: body);

      print('Response Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');

      if (!mounted) {
        print('Widget not mounted after API call, aborting');
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          print('Parsed JSON successfully');
          print('API Response structure: ${data.keys.toList()}');
          
          if (data['status'] == 'success') {
            final List<dynamic> rawUsers = data['data'] ?? [];
            print('Raw users count: ${rawUsers.length}');
            
            // Print first user for debugging
            if (rawUsers.isNotEmpty) {
              print('First user data: ${rawUsers[0]}');
            }
            
            users = rawUsers.map((e) {
              try {
                return User.fromJson(e);
              } catch (parseError) {
                print('Error parsing user: $parseError');
                print('Problem user data: $e');
                rethrow;
              }
            }).toList();
            
            // Filter out deleted users immediately
            filteredUsers = users.where((user) => user.status != 'delete').toList();
            
            print('Total users loaded: ${users.length}');
            print('Active users (excluding deleted): ${filteredUsers.length}');
            
            setState(() => loading = false);
          } else {
            print('API returned error status: ${data['status']}');
            print('API error message: ${data['message']}');
            setState(() {
              loading = false;
              error = data['message'] ?? 'Unknown error from API';
            });
          }
        } catch (jsonError) {
          print('JSON parsing error: $jsonError');
          print('Raw response that failed to parse: ${response.body}');
          setState(() {
            loading = false;
            error = 'Failed to parse server response: $jsonError';
          });
        }
      } else {
        print('HTTP Error ${response.statusCode}');
        print('Error response body: ${response.body}');
        setState(() {
          loading = false;
          error = 'Server error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e, stackTrace) {
      print('Exception caught: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        loading = false;
        error = 'Failed to load data: $e';
      });
    }
  }

  void _onAddUser() async {
    print('Add User button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserAddPage()),
    );

    print('Add User result: $result');
    if (result == true) {
      print('Refreshing users after add');
      fetchUsers();
    }
  }

  Widget _buildUserImage(User user) {
    print('Building image for user: ${user.name}');
    print('Image URL: ${user.photo}');
    
    // Check if we have a valid image URL
    if (user.photo.isEmpty) {
      print('No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.person,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = user.photo;
    
    // If it's a relative URL, make it absolute
    if (!imageUrl.startsWith('http')) {
      // Get base URL from your config
      final baseUrl = AppConfig.api('').toString().replaceAll('/api', '');
      
      // Handle different path formats
      if (imageUrl.startsWith('/')) {
        imageUrl = '$baseUrl$imageUrl';
      } else {
        imageUrl = '$baseUrl/$imageUrl';
      }
    }
    
    print('Final image URL: $imageUrl');

    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('Image loaded successfully for ${user.name}');
              return child;
            }
            print('Loading image for ${user.name}...');
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image for ${user.name}: $error');
            print('Failed URL: $imageUrl');
            return Icon(
              Icons.person,
              color: Colors.grey[600],
              size: 30,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building UserPage widget');
    print('Current state - loading: $loading, error: $error, users: ${users.length}');
    
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;
    final cardMargin = isWideScreen ? 
        EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8) :
        EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    if (loading) {
      print('Showing loading indicator');
      return Scaffold(
        appBar: AppBar(
          title: Text('Users'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              SizedBox(height: 16),
              Text('Loading Users...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Users'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isWideScreen ? 600 : double.infinity),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error Loading Users',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      print('Retry button pressed');
                      fetchUsers();
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                      foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (filteredUsers.isEmpty && users.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Users (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchUsers();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isWideScreen ? 600 : double.infinity),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Users found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddUser,
                  icon: Icon(Icons.add),
                  label: Text('Add First User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                    foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: isWideScreen ? null : FloatingActionButton(
          onPressed: _onAddUser,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_user'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main user list with ${filteredUsers.length} users');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'users')} (${filteredUsers.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddUser,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_user'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchUsers();
            },
            icon: const Icon(Icons.refresh),
            tooltip: SimpleTranslations.get(langCode, 'refresh'),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isWideScreen ? 1200 : double.infinity),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: SimpleTranslations.get(langCode, 'search'),
                    hintText: 'Search by name, phone, or username...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              print('Clear search button pressed');
                              _searchController.clear();
                            },
                            icon: Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Users match your search'
                                  : 'No Users found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            if (_searchController.text.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchUsers,
                        child: isWideScreen
                            ? _buildGridView(cardMargin)
                            : _buildListView(cardMargin),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isWideScreen ? null : FloatingActionButton(
        onPressed: _onAddUser,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_user'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (ctx, i) {
        final user = filteredUsers[i];
        print('Building list item for user: ${user.name}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildUserImage(user),
            title: Text(
              user.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildUserSubtitle(user),
            trailing: Icon(
              Icons.edit,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            onTap: () => _navigateToEdit(user),
          ),
        );
      },
    );
  }

  Widget _buildGridView(EdgeInsets cardMargin) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: cardMargin.horizontal / 2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredUsers.length,
      itemBuilder: (ctx, i) {
        final user = filteredUsers[i];
        print('Building grid item for user: ${user.name}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(user),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildUserImage(user),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildUserSubtitle(user, compact: true),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserSubtitle(User user, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.phone.isNotEmpty)
          Text(
            'Phone: ${user.phone}',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact && user.role != null && user.role!.isNotEmpty)
          Text(
            'Role: ${user.role}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact && user.username.isNotEmpty)
          Text(
            'Username: ${user.username}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  void _navigateToEdit(User user) async {
    print('User tapped: ${user.name}');
    print('=== PASSING USER DATA TO EDIT ===');
    print('User branch_id: ${user.branchId}');
    print('User role: ${user.role}');
    print('User status: ${user.status}');
    print('=================================');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserEditPage(
          userData: {
            'user_id': user.userId,
            'username': user.username,
            'phone': user.phone,
            'email': user.email,
            'name': user.name,
            'photo': user.photo,
            'photo_id': user.photo_id,
            'document_id': user.documentId ?? '',
            'account_no': user.accountNo ?? '',
            'account_name': user.accountName ?? '',
            'status': user.status ?? 'active',
            'role': user.role ?? 'user',
            'branch_id': user.branchId,
            'company_id': user.companyId,
            'bio': user.bio ?? '',
            'language': user.language ?? 'en',
            'village_id': user.villageId,
            'district_id': user.districtId,
            'province_id': user.provinceId,
            'account_bank_id': user.accountBankId,
          },
        ),
      ),
    );

    print('Edit User result: $result');
    if (result == true || result == 'deleted') {
      print('User operation completed, refreshing list...');
      fetchUsers();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// User class remains the same
class User {
  final int? userId;
  final String username;
  final String name;
  final String email;
  final String phone;
  final String photo;
  final String photo_id;
  final String? documentId;
  final String? accountNo;
  final String? accountName;
  final String? status;
  final String? role;
  final int? branchId;
  final int? companyId;
  final String? bio;
  final String? language;
  final int? villageId;
  final int? districtId;
  final int? provinceId;
  final int? accountBankId;
  
  User({
    this.userId,
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
    required this.photo,
    required this.photo_id,
    this.documentId,
    this.accountNo,
    this.accountName,
    this.status,
    this.role,
    this.branchId,
    this.companyId,
    this.bio,
    this.language,
    this.villageId,
    this.districtId,
    this.provinceId,
    this.accountBankId,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to User');
    print('JSON keys: ${json.keys.toList()}');
    print('JSON data: $json');
    
    try {
      final user = User(
        userId: json['user_id'],
        username: json['username'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        photo: json['photo'] ?? '',
        photo_id: json['photo_id'] ?? '',
        documentId: json['document_id'],
        accountNo: json['account_no'],
        accountName: json['account_name'],
        status: json['status'],
        role: json['role'],
        branchId: json['branch_id'],
        companyId: json['company_id'],
        bio: json['bio'],
        language: json['language'],
        villageId: json['village_id'],
        districtId: json['district_id'],
        provinceId: json['province_id'],
        accountBankId: json['account_bank_id'],
      );
      print('Successfully created User: ${user.name}');
      return user;
    } catch (e, stackTrace) {
      print('Error parsing User JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'name': name,
      'email': email,
      'phone': phone,
      'photo': photo,
      'photo_id': photo_id,
      'document_id': documentId,
      'account_no': accountNo,
      'account_name': accountName,
      'status': status,
      'role': role,
      'branch_id': branchId,
      'company_id': companyId,
      'bio': bio,
      'language': language,
      'village_id': villageId,
      'district_id': districtId,
      'province_id': provinceId,
      'account_bank_id': accountBankId,
    };
  }
}