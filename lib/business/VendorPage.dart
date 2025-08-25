import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/business/vendorAddPage.dart';
import 'package:inventory/business/vendorEditPage.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class vendorPage extends StatefulWidget {
  const vendorPage({Key? key}) : super(key: key);

  @override
  State<vendorPage> createState() => _vendorPageState();
}

String langCode = 'en';

class _vendorPageState extends State<vendorPage> {
  List<Iovendor> vendors = [];
  List<Iovendor> filteredvendors = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🚀 DEBUG: vendorPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchvendors();
    
    _searchController.addListener(() {
      print('🔍 DEBUG: Search query: ${_searchController.text}');
      filtervendors(_searchController.text);
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
    print('🗑️ DEBUG: vendorPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filtervendors(String query) {
    print('🔍 DEBUG: Filtering vendors with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredvendors = vendors.where((vendor) {
        final nameLower = vendor.vendorName.toLowerCase();
        final codeLower = vendor.vendorCode.toLowerCase();
        final provinceLower = (vendor.provinceName ?? '').toLowerCase();
        
        bool matches = nameLower.contains(lowerQuery) || 
                      codeLower.contains(lowerQuery) ||
                      provinceLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('🔍 DEBUG: Filtered vendors count: ${filteredvendors.length}');
    });
  }

  Future<void> fetchvendors() async {
    print('🔍 DEBUG: Starting fetchvendors()');
    
    if (!mounted) {
      print('⚠️ DEBUG: Widget not mounted, aborting fetchvendors()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    // Correct API endpoint for your NestJS Iovendor API
    final url = AppConfig.api('/api/iovendor');
    print('🌐 DEBUG: API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = prefs.getInt('company_id') ?? 1;
      
      print('🔑 DEBUG: Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('🏢 DEBUG: Company ID: $companyId');
      
      // Build query parameters
      final queryParams = {
        'status': 'admin', // Use admin to see all vendors
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
            final List<dynamic> rawvendors = data['data'] ?? [];
            print('📦 DEBUG: Raw vendors count: ${rawvendors.length}');
            
            // Print first vendor for debugging
            if (rawvendors.isNotEmpty) {
              print('🔍 DEBUG: First vendor data: ${rawvendors[0]}');
            }
            
            vendors = rawvendors.map((e) {
              try {
                return Iovendor.fromJson(e);
              } catch (parseError) {
                print('❌ DEBUG: Error parsing vendor: $parseError');
                print('📝 DEBUG: Problem vendor data: $e');
                rethrow;
              }
            }).toList();
            
            filteredvendors = List.from(vendors);
            
            print('✅ DEBUG: Total vendors loaded: ${vendors.length}');
            print('✅ DEBUG: Filtered vendors: ${filteredvendors.length}');
            
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

  void _onAddvendor() async {
    print('➕ DEBUG: Add vendor button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => vendorAddPage()),
    );

    print('📝 DEBUG: Add vendor result: $result');
    if (result == true) {
      print('🔄 DEBUG: Refreshing vendors after add');
      fetchvendors();
    }
  }

  Widget _buildvendorImage(Iovendor vendor) {
    print('🖼️ DEBUG: Building image for vendor: ${vendor.vendorName}');
    print('🖼️ DEBUG: Image URL: ${vendor.imageUrl}');
    
    // Check if we have a valid image URL
    if (vendor.imageUrl == null || vendor.imageUrl!.isEmpty) {
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
    String imageUrl = vendor.imageUrl!;
    
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
              print('🖼️ DEBUG: Image loaded successfully for ${vendor.vendorName}');
              return child;
            }
            print('🖼️ DEBUG: Loading image for ${vendor.vendorName}...');
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
            print('❌ DEBUG: Error loading image for ${vendor.vendorName}: $error');
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
    print('🎨 DEBUG: Building vendorPage widget');
    print('📊 DEBUG: Current state - loading: $loading, error: $error, vendors: ${vendors.length}');
    
    if (loading) {
      print('⏳ DEBUG: Showing loading indicator');
      return Scaffold(
        appBar: AppBar(
          title: Text('vendores'),
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
              Text('Loading vendores...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('❌ DEBUG: Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('vendores'),
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
                  'Error Loading vendores',
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
                    fetchvendors();
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

    if (vendors.isEmpty) {
      print('📭 DEBUG: Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('vendores (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('🔄 DEBUG: Refresh button pressed from empty state');
                fetchvendors();
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
                'No vendores found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _onAddvendor,
                icon: Icon(Icons.add),
                label: Text('Add First vendor'),
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

    print('📱 DEBUG: Rendering main vendor list with ${filteredvendors.length} vendores');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'vendores')} (${filteredvendors.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            onPressed: () {
              print('🔄 DEBUG: Refresh button pressed from app bar');
              fetchvendors();
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
            child: filteredvendors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No vendores match your search'
                              : 'No vendores found',
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
                    onRefresh: fetchvendors,
                    child: ListView.builder(
                      itemCount: filteredvendors.length,
                      itemBuilder: (ctx, i) {
                        final vendor = filteredvendors[i];
                        print('🏗️ DEBUG: Building list item for vendor: ${vendor.vendorName}');

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: _buildvendorImage(vendor),
                            title: Text(
                              vendor.vendorName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code: ${vendor.vendorCode}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                if (vendor.provinceName != null && vendor.provinceName!.isNotEmpty)
                                  Text(
                                    'Province: ${vendor.provinceName}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                if (vendor.managerName != null && vendor.managerName!.isNotEmpty)
                                  Text(
                                    'Manager: ${vendor.managerName}',
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
                              print('👆 DEBUG: vendor tapped: ${vendor.vendorName}');
                              
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => vendorEditPage(
                                    vendorData: vendor.toJson(),
                                  ),
                                ),
                              );

                              print('📝 DEBUG: Edit vendor result: $result');
                              if (result == true || result == 'deleted') {
                                print('🔄 DEBUG: vendor operation completed, refreshing list...');
                                fetchvendors();
                                
                                if (result == 'deleted') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('vendor removed from list'),
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
        onPressed: _onAddvendor,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_vendor'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Updated Iovendor model to match your io_vendor table structure
class Iovendor {
  final int vendorId;
  final int companyId;
  final String vendorName;
  final String vendorCode;
  final String? provinceName;
  final String? address;
  final String? phone;
  final String? email;
  final String? managerName;
  final String? vendorImage;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  Iovendor({
    required this.vendorId,
    required this.companyId,
    required this.vendorName,
    required this.vendorCode,
    this.provinceName,
    this.address,
    this.phone,
    this.email,
    this.managerName,
    this.vendorImage,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });
  
  factory Iovendor.fromJson(Map<String, dynamic> json) {
    print('🔄 DEBUG: Converting JSON to Iovendor');
    print('📝 DEBUG: JSON keys: ${json.keys.toList()}');
    print('📝 DEBUG: JSON data: $json');
    
    try {
      final vendor = Iovendor(
        vendorId: json['vendor_id'] ?? 0,
        companyId: json['company_id'] ?? 0,
        vendorName: json['vendor_name'] ?? '',
        vendorCode: json['vendor_code'] ?? '',
        provinceName: json['province_name'],
        address: json['address'],
        phone: json['phone'],
        email: json['email'],
        managerName: json['manager_name'],
        vendorImage: json['vendor_image'],
        imageUrl: json['image_url'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      );
      print('✅ DEBUG: Successfully created Iovendor: ${vendor.vendorName} (${vendor.vendorCode})');
      return vendor;
    } catch (e, stackTrace) {
      print('❌ DEBUG: Error parsing Iovendor JSON: $e');
      print('📚 DEBUG: Stack trace: $stackTrace');
      print('📝 DEBUG: Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'vendor_id': vendorId,
      'company_id': companyId,
      'vendor_name': vendorName,
      'vendor_code': vendorCode,
      'province_name': provinceName,
      'address': address,
      'phone': phone,
      'email': email,
      'manager_name': managerName,
      'vendor_image': vendorImage,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}