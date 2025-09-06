import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/business/StoreAddPage.dart';
import 'package:inventory/business/StoreEditPage.dart';
import 'package:inventory/config/company_config.dart';

import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class storePage extends StatefulWidget {
  const storePage({Key? key}) : super(key: key);

  @override
  State<storePage> createState() => _storePageState();
}

String langCode = 'en';

class _storePageState extends State<storePage> {
  List<Iostore> stores = [];
  List<Iostore> filteredstores = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🚀 DEBUG: storePage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchstores();
    
    _searchController.addListener(() {
      print('🔍 DEBUG: Search query: ${_searchController.text}');
      filterstores(_searchController.text);
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
    print('🗑️ DEBUG: storePage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterstores(String query) {
    print('🔍 DEBUG: Filtering stores with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredstores = stores.where((store) {
        final nameLower = store.storeName.toLowerCase();
        bool matches = nameLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('🔍 DEBUG: Filtered stores count: ${filteredstores.length}');
    });
  }

  Future<void> fetchstores() async {
    print('🔍 DEBUG: Starting fetchstores()');
    
    if (!mounted) {
      print('⚠️ DEBUG: Widget not mounted, aborting fetchstores()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    // Correct API endpoint for your NestJS Iostore API
    final url = AppConfig.api('/api/iostore');
    print('🌐 DEBUG: API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('🔑 DEBUG: Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('🏢 DEBUG: Company ID: $companyId');
      
      // Build query parameters
      final queryParams = {
        'status': 'admin', // Use admin to see all stores
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
            final List<dynamic> rawstores = data['data'] ?? [];
            print('📦 DEBUG: Raw stores count: ${rawstores.length}');
            
            // Print first store for debugging
            if (rawstores.isNotEmpty) {
              print('🔍 DEBUG: First store data: ${rawstores[0]}');
            }
            
            stores = rawstores.map((e) {
              try {
                return Iostore.fromJson(e);
              } catch (parseError) {
                print('❌ DEBUG: Error parsing store: $parseError');
                print('📝 DEBUG: Problem store data: $e');
                rethrow;
              }
            }).toList();
            
            filteredstores = List.from(stores);
            
            print('✅ DEBUG: Total stores loaded: ${stores.length}');
            print('✅ DEBUG: Filtered stores: ${filteredstores.length}');
            
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

  void _onAddstore() async {
    print('➕ DEBUG: Add store button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StoreAddPage()),
    );

    print('📝 DEBUG: Add store result: $result');
    if (result == true) {
      print('🔄 DEBUG: Refreshing stores after add');
      fetchstores();
    }
  }

  Widget _buildstoreImage(Iostore store) {
    print('🖼️ DEBUG: Building image for store: ${store.storeName}');
    print('🖼️ DEBUG: Image URL: ${store.imageUrl}');
    
    // Check if we have a valid image URL
    if (store.imageUrl == null || store.imageUrl!.isEmpty) {
      print('🖼️ DEBUG: No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.store,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = store.imageUrl!;
    
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
              print('🖼️ DEBUG: Image loaded successfully for ${store.storeName}');
              return child;
            }
            print('🖼️ DEBUG: Loading image for ${store.storeName}...');
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
            print('❌ DEBUG: Error loading image for ${store.storeName}: $error');
            print('📝 DEBUG: Failed URL: $imageUrl');
            return Icon(
              Icons.store,
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
    print('🎨 DEBUG: Building storePage widget');
    print('📊 DEBUG: Current state - loading: $loading, error: $error, stores: ${stores.length}');
    
    if (loading) {
      print('⏳ DEBUG: Showing loading indicator');
      return Scaffold(
        appBar: AppBar(
          title: Text('stores'),
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
              Text('Loading stores...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('❌ DEBUG: Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('stores'),
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
                  'Error Loading stores',
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
                    fetchstores();
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

    if (stores.isEmpty) {
      print('📭 DEBUG: Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('stores (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('🔄 DEBUG: Refresh button pressed from empty state');
                fetchstores();
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
              Icon(Icons.store, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No stores found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _onAddstore,
                icon: Icon(Icons.add),
                label: Text('Add First store'),
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

    print('📱 DEBUG: Rendering main store list with ${filteredstores.length} stores');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'stores')} (${filteredstores.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            onPressed: () {
              print('🔄 DEBUG: Refresh button pressed from app bar');
              fetchstores();
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
            child: filteredstores.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No stores match your search'
                              : 'No stores found',
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
                    onRefresh: fetchstores,
                    child: ListView.builder(
                      itemCount: filteredstores.length,
                      itemBuilder: (ctx, i) {
                        final store = filteredstores[i];
                        print('🏗️ DEBUG: Building list item for store: ${store.storeName}');

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: _buildstoreImage(store),
                            title: Text(
                              store.storeName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              'Company ID: ${store.companyId}',
                              style: TextStyle(fontSize: 13),
                            ),
                            trailing: Icon(
                              Icons.edit,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                            onTap: () async {
                              print('👆 DEBUG: store tapped: ${store.storeName}');
                              
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => storeEditPage(
                                    storeData: store.toJson(),
                                  ),
                                ),
                              );

                              print('📝 DEBUG: Edit store result: $result');
                              if (result == true || result == 'deleted') {
                                print('🔄 DEBUG: store operation completed, refreshing list...');
                                fetchstores();
                                
                                if (result == 'deleted') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('store removed from list'),
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
        onPressed: _onAddstore,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_store'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Updated Iostore model to match your io_store table structure
class Iostore {
  final int storeId;
  final int companyId;
  final String storeName;
  final String? imageUrl;
  
  Iostore({
    required this.storeId,
    required this.companyId,
    required this.storeName,
    this.imageUrl,
  });
  
  factory Iostore.fromJson(Map<String, dynamic> json) {
    print('🔄 DEBUG: Converting JSON to Iostore');
    print('📝 DEBUG: JSON keys: ${json.keys.toList()}');
    print('📝 DEBUG: JSON data: $json');
    
    try {
      final store = Iostore(
        storeId: json['store_id'] ?? 0,
        companyId: CompanyConfig.getCompanyId(), // Use centralized config instead
        storeName: json['store_name'] ?? '',
        imageUrl: json['image_url'],
      );
      print('✅ DEBUG: Successfully created Iostore: ${store.storeName}');
      return store;
    } catch (e, stackTrace) {
      print('❌ DEBUG: Error parsing Iostore JSON: $e');
      print('📚 DEBUG: Stack trace: $stackTrace');
      print('📝 DEBUG: Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'company_id': companyId,
      'store': storeName,
      'image_url': imageUrl,
    };
  }
}