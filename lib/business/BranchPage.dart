import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/business/BranchAddPage.dart';
import 'package:inventory/business/BranchEditPage.dart';
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class branchPage extends StatefulWidget {
  const branchPage({Key? key}) : super(key: key);

  @override
  State<branchPage> createState() => _branchPageState();
}

String langCode = 'en';

class _branchPageState extends State<branchPage> {
  List<Iobranch> branchs = [];
  List<Iobranch> filteredbranchs = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🚀 DEBUG: branchPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchbranchs();
    
    _searchController.addListener(() {
      print('🔍 DEBUG: Search query: ${_searchController.text}');
      filterbranchs(_searchController.text);
    });
  }

  void _loadLangCode() async {
    print('📱 DEBUG: Loading language code...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
      print('🌐 DEBUG: Language code loaded: $langCode');
    });
  }

  void _loadCurrentTheme() async {
    print('🎨 DEBUG: Loading current theme...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      print('🎨 DEBUG: Theme loaded: $currentTheme');
    });
  }

  @override
  void dispose() {
    print('🗑️ DEBUG: branchPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterbranchs(String query) {
    print('🔍 DEBUG: Filtering branchs with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredbranchs = branchs.where((branch) {
        final nameLower = branch.branchName.toLowerCase();
        final codeLower = branch.branchCode.toLowerCase();
        final provinceLower = (branch.provinceName ?? '').toLowerCase();
        
        bool matches = nameLower.contains(lowerQuery) || 
                      codeLower.contains(lowerQuery) ||
                      provinceLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('🔍 DEBUG: Filtered branchs count: ${filteredbranchs.length}');
    });
  }

  Future<void> fetchbranchs() async {
    print('🔍 DEBUG: Starting fetchbranchs()');
    
    if (!mounted) {
      print('⚠️ DEBUG: Widget not mounted, aborting fetchbranchs()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    // Correct API endpoint for your NestJS Iobranch API
    final url = AppConfig.api('/api/iobranch');
    print('🌐 DEBUG: API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('🔑 DEBUG: Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('🏢 DEBUG: Company ID: $companyId');
      
      // Build query parameters
      final queryParams = {
        'status': 'admin', // Use admin to see all branchs
        'company_id': companyId.toString(),
      };
      
      final uri = Uri.parse(url.toString()).replace(queryParameters: queryParams);
      print('🔗 DEBUG: Full URI: $uri');
      
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      print('📋 DEBUG: Request headers: $headers');
      
      final response = await http.get(uri, headers: headers);

      print('📡 DEBUG: Response Status Code: ${response.statusCode}');
      print('📄 DEBUG: Response Headers: ${response.headers}');
      print('📝 DEBUG: Response Body: ${response.body}');

      if (!mounted) {
        print('⚠️ DEBUG: Widget not mounted after API call, aborting');
        return;
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('✅ DEBUG: Parsed JSON successfully');
          print('📊 DEBUG: API Response structure: ${data.keys.toList()}');
          
          if (data['status'] == 'success') {
            final List<dynamic> rawbranchs = data['data'] ?? [];
            print('📦 DEBUG: Raw branchs count: ${rawbranchs.length}');
            
            // Print first branch for debugging
            if (rawbranchs.isNotEmpty) {
              print('🔍 DEBUG: First branch data: ${rawbranchs[0]}');
            }
            
            branchs = rawbranchs.map((e) {
              try {
                return Iobranch.fromJson(e);
              } catch (parseError) {
                print('❌ DEBUG: Error parsing branch: $parseError');
                print('📝 DEBUG: Problem branch data: $e');
                rethrow;
              }
            }).toList();
            
            filteredbranchs = List.from(branchs);
            
            print('✅ DEBUG: Total branchs loaded: ${branchs.length}');
            print('✅ DEBUG: Filtered branchs: ${filteredbranchs.length}');
            
            setState(() => loading = false);
          } else {
            print('❌ DEBUG: API returned error status: ${data['status']}');
            print('❌ DEBUG: API error message: ${data['message']}');
            setState(() {
              loading = false;
              error = data['message'] ?? 'Unknown error from API';
            });
          }
        } catch (jsonError) {
          print('❌ DEBUG: JSON parsing error: $jsonError');
          print('📝 DEBUG: Raw response that failed to parse: ${response.body}');
          setState(() {
            loading = false;
            error = 'Failed to parse server response: $jsonError';
          });
        }
      } else {
        print('❌ DEBUG: HTTP Error ${response.statusCode}');
        print('❌ DEBUG: Error response body: ${response.body}');
        setState(() {
          loading = false;
          error = 'Server error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e, stackTrace) {
      print('💥 DEBUG: Exception caught: $e');
      print('📚 DEBUG: Stack trace: $stackTrace');
      setState(() {
        loading = false;
        error = 'Failed to load data: $e';
      });
    }
  }

  void _onAddbranch() async {
    print('➕ DEBUG: Add branch button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => branchAddPage()),
    );

    print('📝 DEBUG: Add branch result: $result');
    if (result == true) {
      print('🔄 DEBUG: Refreshing branchs after add');
      fetchbranchs();
    }
  }

  Widget _buildbranchImage(Iobranch branch) {
    print('🖼️ DEBUG: Building image for branch: ${branch.branchName}');
    print('🖼️ DEBUG: Image URL: ${branch.imageUrl}');
    
    // Check if we have a valid image URL
    if (branch.imageUrl == null || branch.imageUrl!.isEmpty) {
      print('🖼️ DEBUG: No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.business,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = branch.imageUrl!;
    
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
    
    print('🖼️ DEBUG: Final image URL: $imageUrl');

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
              print('🖼️ DEBUG: Image loaded successfully for ${branch.branchName}');
              return child;
            }
            print('🖼️ DEBUG: Loading image for ${branch.branchName}...');
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
            print('❌ DEBUG: Error loading image for ${branch.branchName}: $error');
            print('📝 DEBUG: Failed URL: $imageUrl');
            return Icon(
              Icons.business,
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
    print('🎨 DEBUG: Building branchPage widget');
    print('📊 DEBUG: Current state - loading: $loading, error: $error, branchs: ${branchs.length}');
    
    if (loading) {
      print('⏳ DEBUG: Showing loading indicator');
      return Scaffold(
        appBar: AppBar(
          title: Text('Branches'),
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
              Text('Loading branches...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('❌ DEBUG: Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Branches'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error Loading Branches',
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
                    print('🔄 DEBUG: Retry button pressed');
                    fetchbranchs();
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
      );
    }

    if (branchs.isEmpty) {
      print('📭 DEBUG: Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Branches (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('🔄 DEBUG: Refresh button pressed from empty state');
                fetchbranchs();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No branches found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _onAddbranch,
                icon: Icon(Icons.add),
                label: Text('Add First Branch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                  foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                ),
              ),
            ],
          ),
        ),
      );
    }

    print('📱 DEBUG: Rendering main branch list with ${filteredbranchs.length} branches');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'branches')} (${filteredbranchs.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            onPressed: () {
              print('🔄 DEBUG: Refresh button pressed from app bar');
              fetchbranchs();
            },
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
                hintText: 'Search by name, code, or province...',
                prefixIcon: Icon(
                  Icons.search,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          print('🧹 DEBUG: Clear search button pressed');
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
            child: filteredbranchs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No branches match your search'
                              : 'No branches found',
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
                    onRefresh: fetchbranchs,
                    child: ListView.builder(
                      itemCount: filteredbranchs.length,
                      itemBuilder: (ctx, i) {
                        final branch = filteredbranchs[i];
                        print('🏗️ DEBUG: Building list item for branch: ${branch.branchName}');

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: _buildbranchImage(branch),
                            title: Text(
                              branch.branchName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code: ${branch.branchCode}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                if (branch.provinceName != null && branch.provinceName!.isNotEmpty)
                                  Text(
                                    'Province: ${branch.provinceName}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                if (branch.managerName != null && branch.managerName!.isNotEmpty)
                                  Text(
                                    'Manager: ${branch.managerName}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.edit,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                            isThreeLine: true,
                            onTap: () async {
                              print('👆 DEBUG: branch tapped: ${branch.branchName}');
                              
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => branchEditPage(
                                    branchData: branch.toJson(),
                                  ),
                                ),
                              );

                              print('📝 DEBUG: Edit branch result: $result');
                              if (result == true || result == 'deleted') {
                                print('🔄 DEBUG: branch operation completed, refreshing list...');
                                fetchbranchs();
                                
                                if (result == 'deleted') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Branch removed from list'),
                                      backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
                                      duration: Duration(seconds: 2),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddbranch,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_branch'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Updated Iobranch model to match your io_branch table structure
class Iobranch {
  final int branchId;
  final int companyId;
  final String branchName;
  final String branchCode;
  final String? provinceName;
  final String? address;
  final String? phone;
  final String? email;
  final String? managerName;
  final String? branchImage;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  Iobranch({
    required this.branchId,
    required this.companyId,
    required this.branchName,
    required this.branchCode,
    this.provinceName,
    this.address,
    this.phone,
    this.email,
    this.managerName,
    this.branchImage,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });
  
  factory Iobranch.fromJson(Map<String, dynamic> json) {
    print('🔄 DEBUG: Converting JSON to Iobranch');
    print('📝 DEBUG: JSON keys: ${json.keys.toList()}');
    print('📝 DEBUG: JSON data: $json');
    
    try {
      final branch = Iobranch(
        branchId: json['branch_id'] ?? 0,
        companyId: CompanyConfig.getCompanyId(), // Use centralized config instead
        branchName: json['branch_name'] ?? '',
        branchCode: json['branch_code'] ?? '',
        provinceName: json['province_name'],
        address: json['address'],
        phone: json['phone'],
        email: json['email'],
        managerName: json['manager_name'],
        branchImage: json['branch_image'],
        imageUrl: json['image_url'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      );
      print('✅ DEBUG: Successfully created Iobranch: ${branch.branchName} (${branch.branchCode})');
      return branch;
    } catch (e, stackTrace) {
      print('❌ DEBUG: Error parsing Iobranch JSON: $e');
      print('📚 DEBUG: Stack trace: $stackTrace');
      print('📝 DEBUG: Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'company_id': companyId,
      'branch_name': branchName,
      'branch_code': branchCode,
      'province_name': provinceName,
      'address': address,
      'phone': phone,
      'email': email,
      'manager_name': managerName,
      'branch_image': branchImage,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}