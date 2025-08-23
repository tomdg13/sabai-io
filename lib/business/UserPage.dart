import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/business/UserAdd.dart';
import 'package:inventory/business/UserEdit.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart'; // Add this import
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
  String currentTheme = ThemeConfig.defaultTheme; // Add theme variable

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme(); // Add theme loading
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

  // Add theme loading method
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
        // First filter out deleted users, then apply search filter
        if (user.status == 'delete') return false;
        
        final nameLower = user.name.toLowerCase();
        final phoneLower = user.phone.toLowerCase();
        return nameLower.contains(lowerQuery) ||
            phoneLower.contains(lowerQuery);
      }).toList();
    });
  }

  // Helper method to filter out deleted users
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
            ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
          ),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: TextStyle(
            color: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red, // Use theme color
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
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme), // Use theme color
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
                  color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
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
                           
                            ],
                          ),
                          trailing: Icon(
                            Icons.edit,
                            color: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserEditPage(
                                  userData: {
                                    'username': u.username,
                                    'phone': u.phone,
                                    'email': u.email,
                                    'name': u.name,
                                    'photo': u.photo,
                                    'photo_id': u.photo_id,
                                    'document_id': u.documentId ?? '',
                                    'bank_name': u.bankName ?? '',
                                    'province_name': u.provinceName ?? '',
                                    'district_name': u.districtName ?? '',
                                    'village_name': u.villageName ?? '',
                                    'account_no': u.accountNo ?? '',
                                    'account_name': u.accountName ?? '',
                                    'status': u.status ?? '',
                                  },
                                ),
                              ),
                            );

                            // Handle both update and delete results
                            if (result == true || result == 'deleted') {
                              print('User operation completed, refreshing list...');
                              fetchUsersByRole('Admin');
                              
                              if (result == 'deleted') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('User removed from list'),
                                    backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green, // Use theme color
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
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme), // Use theme color
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme), // Use theme color
        tooltip: SimpleTranslations.get(langCode, 'add_user'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class User {
  final String username;
  final String name;
  final String email;
  final String phone;
  final String photo;
  final String photo_id;
  final String? documentId;
  final String? bankName;
  final String? provinceName;
  final String? districtName;
  final String? villageName;
  final String? accountNo;
  final String? accountName;
  final String? status; // Added status field
  
  User({
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
    required this.photo,
    required this.photo_id,
    this.documentId,
    this.bankName,
    this.provinceName,
    this.districtName,
    this.villageName,
    this.accountNo,
    this.accountName,
    this.status, // Added status parameter
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      photo: json['photo'] ?? '',
      photo_id: json['photo_id'] ?? '',
      documentId: json['document_id'],
      bankName: json['bank_name'],
      provinceName: json['province_name'],
      districtName: json['district_name'],
      villageName: json['village_name'],
      accountNo: json['account_no'],
      accountName: json['account_name'],
      status: json['status'], // Added status parsing
    );
  }
}