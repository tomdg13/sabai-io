import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/business/UserAdd.dart';
import 'package:inventory/business/UserEdit.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class userpage extends StatefulWidget {
  const userpage({Key? key}) : super(key: key);

  @override
  State<userpage> createState() => _userpageState();
}

String langCode = 'en';

class _userpageState extends State<userpage> {
  List<User> users = [];
  List<User> filteredUsers = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchUsersByRole('Admin');
    _searchController.addListener(() {
      filterUsers(_searchController.text);
    });
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void filterUsers(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredUsers = users.where((user) {
        if (user.status == 'delete') return false;
        
        final nameLower = user.name.toLowerCase();
        final phoneLower = user.phone.toLowerCase();
        return nameLower.contains(lowerQuery) ||
            phoneLower.contains(lowerQuery);
      }).toList();
    });
  }

  List<User> _getActiveUsers(List<User> allUsers) {
    return allUsers.where((user) => user.status != 'delete').toList();
  }

  Future<void> fetchUsersByRole(String role) async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iouser/iouserRole');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token}',
        },
        body: jsonEncode({'role': role}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> rawUsers = data['data'] ?? [];
          users = rawUsers.map((e) => User.fromJson(e)).toList();
          
          // Filter out deleted users immediately
          filteredUsers = _getActiveUsers(users);
          
          print('Total users loaded: ${users.length}');
          print('Active users (excluding deleted): ${filteredUsers.length}');
          
          setState(() => loading = false);
        } else {
          setState(() {
            loading = false;
            error = data['message'] ?? 'Unknown error';
          });
        }
      } else {
        setState(() {
          loading = false;
          error = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Failed to load data: $e';
      });
    }
  }

  void _onAddUser() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserAddPage()),
    );

    if (result == true) {
      fetchUsersByRole('Admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            ThemeConfig.getPrimaryColor(currentTheme),
          ),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: TextStyle(
            color: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
          ),
        ),
      );
    }

    if (users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'users')} (${filteredUsers.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            onPressed: () => fetchUsersByRole('Admin'),
            icon: const Icon(Icons.refresh),
            tooltip: SimpleTranslations.get(langCode, 'refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'search'),
                prefixIcon: Icon(
                  Icons.search,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
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
                        const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          SimpleTranslations.get(langCode, 'no_users_found'),
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (ctx, i) {
                      final u = filteredUsers[i];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: u.photo.isNotEmpty
                                ? NetworkImage(u.photo)
                                : const AssetImage(
                                        'assets/images/default_user.png',
                                      )
                                      as ImageProvider,
                          ),
                          title: Text(u.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.phone),
                              if (u.role != null) 
                                Text('Role: ${u.role}', 
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.edit,
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                          ),
                          onTap: () async {
                            print('=== PASSING USER DATA TO EDIT ===');
                            print('User branch_id: ${u.branchId}');
                            print('User role: ${u.role}');
                            print('User status: ${u.status}');
                            print('=================================');
                            
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserEditPage(
                                  userData: {
                                    'user_id': u.userId,
                                    'username': u.username,
                                    'phone': u.phone,
                                    'email': u.email,
                                    'name': u.name,
                                    'photo': u.photo,
                                    'photo_id': u.photo_id,
                                    'document_id': u.documentId ?? '',
                                    'account_no': u.accountNo ?? '',
                                    'account_name': u.accountName ?? '',
                                    'status': u.status ?? 'active',
                                    'role': u.role ?? 'user',
                                    'branch_id': u.branchId, // Now included!
                                    'company_id': u.companyId,
                                    'bio': u.bio ?? '',
                                    'language': u.language ?? 'en',
                                    // Geographic data
                                    'village_id': u.villageId,
                                    'district_id': u.districtId,
                                    'province_id': u.provinceId,
                                    'account_bank_id': u.accountBankId,
                                  },
                                ),
                              ),
                            );

                            if (result == true || result == 'deleted') {
                              print('User operation completed, refreshing list...');
                              fetchUsersByRole('Admin');
                              
                              if (result == 'deleted') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('User removed from list'),
                                    backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddUser,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_user'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

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
  final int? branchId; // Added branch_id
  final int? companyId; // Added company_id
  final String? bio;
  final String? language;
  // Geographic fields
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
    this.branchId, // Added branch_id parameter
    this.companyId, // Added company_id parameter
    this.bio,
    this.language,
    this.villageId,
    this.districtId,
    this.provinceId,
    this.accountBankId,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
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
      branchId: json['branch_id'], // Added branch_id parsing
      companyId: json['company_id'], // Added company_id parsing
      bio: json['bio'],
      language: json['language'],
      villageId: json['village_id'],
      districtId: json['district_id'],
      provinceId: json['province_id'],
      accountBankId: json['account_bank_id'],
    );
  }
}