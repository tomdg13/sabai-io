import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/business/UserAdd.dart';
import 'package:inventory/business/UserEdit.dart';
import 'package:inventory/config/config.dart';
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

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('Language code: $langCode');

    _loadLangCode();
    fetchUsersByRole('Admin');
    _searchController.addListener(() {
      filterUsers(_searchController.text);
    });
  }

  void _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('langCode') ?? 'en';
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
        final nameLower = user.name.toLowerCase();
        final phoneLower = user.phone.toLowerCase();
        return nameLower.contains(lowerQuery) ||
            phoneLower.contains(lowerQuery);
      }).toList();
    });
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
          filteredUsers = users;
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

  Widget _buildUserCard(User user) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserEditPage(
                userData: {
                  'username': user.username,
                  'phone': user.phone,
                  'email': user.email,
                  'name': user.name,
                  'photo': user.photo,
                  'photo_id': user.photo_id,
                  'document_id': user.documentId ?? '',
                  'bank_name': user.bankName ?? '',
                  'province_name': user.provinceName ?? '',
                  'district_name': user.districtName ?? '',
                  'village_name': user.villageName ?? '',
                  'account_no': user.accountNo ?? '',
                  'account_name': user.accountName ?? '',
                },
              ),
            ),
          );

          if (result == true) {
            fetchUsersByRole('Admin');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: user.photo.isNotEmpty
                      ? NetworkImage(user.photo)
                      : const AssetImage('assets/images/default_user.png') as ImageProvider,
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: user.photo.isEmpty
                      ? Icon(Icons.person, color: Colors.blue, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          user.phone,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (user.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.email, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Edit Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddUserCard() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _onAddUser,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  SimpleTranslations.get(langCode, 'add_user'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.green,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(SimpleTranslations.get(langCode, 'users')),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(SimpleTranslations.get(langCode, 'users')),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => fetchUsersByRole('Admin'),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'users')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'search'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          // Users List
          Expanded(
            child: filteredUsers.isEmpty && users.isNotEmpty
                ? Center(
                    child: Text(
                      SimpleTranslations.get(langCode, 'no_users_found'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredUsers.length + 1, // +1 for add user card
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // First item is always the "Add User" card
                        return _buildAddUserCard();
                      } else {
                        // Other items are user cards
                        final userIndex = index - 1;
                        if (userIndex < filteredUsers.length) {
                          return _buildUserCard(filteredUsers[userIndex]);
                        }
                        return Container(); // Fallback
                      }
                    },
                  ),
          ),
        ],
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
    );
  }
}