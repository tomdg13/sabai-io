import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'ProductAddPage.dart';
import 'ProductEditPage.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

class ProductPage extends StatefulWidget {
  const ProductPage({Key? key}) : super(key: key);

  @override
  State<ProductPage> createState() => _ProductPageState();
}

String langCode = 'en';

class _ProductPageState extends State<ProductPage> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🚀 DEBUG: ProductPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchProducts();
    
    _searchController.addListener(() {
      print('🔍 DEBUG: Search query: ${_searchController.text}');
      filterProducts(_searchController.text);
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
    print('🗑️ DEBUG: ProductPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterProducts(String query) {
    print('🔍 DEBUG: Filtering products with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredProducts = products.where((product) {
        // Filter out deleted products, then apply search filter
        if (product.status == 'deleted') return false;
        
        final nameLower = product.productName.toLowerCase();
        final categoryLower = (product.category ?? '').toLowerCase();
        final brandLower = (product.brand ?? '').toLowerCase();
        final codeLower = (product.productCode ?? '').toLowerCase();
        
        bool matches = nameLower.contains(lowerQuery) ||
            categoryLower.contains(lowerQuery) ||
            brandLower.contains(lowerQuery) ||
            codeLower.contains(lowerQuery);
            
        return matches;
      }).toList();
      print('🔍 DEBUG: Filtered products count: ${filteredProducts.length}');
    });
  }

  List<Product> _getActiveProducts(List<Product> allProducts) {
    final activeProducts = allProducts.where((product) => product.status != 'deleted').toList();
    print('✅ DEBUG: Active products (excluding deleted): ${activeProducts.length} out of ${allProducts.length}');
    return activeProducts;
  }

  Future<void> fetchProducts() async {
    print('🔍 DEBUG: Starting fetchProducts()');
    
    if (!mounted) {
      print('⚠️ DEBUG: Widget not mounted, aborting fetchProducts()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    // Correct API endpoint for your NestJS IoProduct API
    final url = AppConfig.api('/api/ioproduct');
    print('🌐 DEBUG: API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = prefs.getInt('company_id') ?? 1;
      
      print('🔑 DEBUG: Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('🏢 DEBUG: Company ID: $companyId');
      
      // Build query parameters
      final queryParams = {
        'status': 'active', // or 'admin' to see all products
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
            final List<dynamic> rawProducts = data['data'] ?? [];
            print('📦 DEBUG: Raw products count: ${rawProducts.length}');
            
            // Print first product for debugging
            if (rawProducts.isNotEmpty) {
              print('🔍 DEBUG: First product data: ${rawProducts[0]}');
            }
            
            products = rawProducts.map((e) {
              try {
                return Product.fromJson(e);
              } catch (parseError) {
                print('❌ DEBUG: Error parsing product: $parseError');
                print('📝 DEBUG: Problem product data: $e');
                rethrow;
              }
            }).toList();
            
            filteredProducts = _getActiveProducts(products);
            
            print('✅ DEBUG: Total products loaded: ${products.length}');
            print('✅ DEBUG: Active products: ${filteredProducts.length}');
            
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

  void _onAddProduct() async {
    print('➕ DEBUG: Add product button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductAddPage()),
    );

    print('📝 DEBUG: Add product result: $result');
    if (result == true) {
      print('🔄 DEBUG: Refreshing products after add');
      fetchProducts();
    }
  }

  // ✅ FIXED: Better image widget with proper error handling
  Widget _buildProductImage(Product product) {
    print('🖼️ DEBUG: Building image for product: ${product.productName}');
    print('🖼️ DEBUG: Image URL: ${product.imageUrl}');
    
    // Check if we have a valid image URL
    if (product.imageUrl == null || product.imageUrl!.isEmpty) {
      print('🖼️ DEBUG: No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.inventory_2,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = product.imageUrl!;
    
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
              print('🖼️ DEBUG: Image loaded successfully for ${product.productName}');
              return child;
            }
            print('🖼️ DEBUG: Loading image for ${product.productName}...');
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
            print('❌ DEBUG: Error loading image for ${product.productName}: $error');
            print('📝 DEBUG: Failed URL: $imageUrl');
            return Icon(
              Icons.inventory_2,
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
    print('🎨 DEBUG: Building ProductPage widget');
    print('📊 DEBUG: Current state - loading: $loading, error: $error, products: ${products.length}');
    
    if (loading) {
      print('⏳ DEBUG: Showing loading indicator');
      return Scaffold(
        appBar: AppBar(
          title: Text('Products'),
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
              Text('Loading products...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('❌ DEBUG: Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Products'),
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
                  'Error Loading Products',
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
                    fetchProducts();
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

    if (products.isEmpty) {
      print('📭 DEBUG: Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Products (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('🔄 DEBUG: Refresh button pressed from empty state');
                fetchProducts();
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
              Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No products found',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _onAddProduct,
                icon: Icon(Icons.add),
                label: Text('Add First Product'),
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

    print('📱 DEBUG: Rendering main product list with ${filteredProducts.length} products');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'products') ?? 'Products'} (${filteredProducts.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            onPressed: () {
              print('🔄 DEBUG: Refresh button pressed from app bar');
              fetchProducts();
            },
            icon: const Icon(Icons.refresh),
            tooltip: SimpleTranslations.get(langCode, 'refresh') ?? 'Refresh',
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
                labelText: SimpleTranslations.get(langCode, 'search') ?? 'Search products...',
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
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No products match your search'
                              : 'No products found',
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
                    onRefresh: fetchProducts,
                    child: ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (ctx, i) {
                        final product = filteredProducts[i];
                        print('🏗️ DEBUG: Building list item for product: ${product.productName}');

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundImage: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                  ? NetworkImage(product.imageUrl!) // Try original URL first
                                  : const AssetImage('assets/images/default_product.png') as ImageProvider,
                              onBackgroundImageError: (exception, stackTrace) {
                                print('🖼️ DEBUG: Error loading image for ${product.productName}');
                                print('🖼️ DEBUG: Original URL failed: ${product.imageUrl}');
                                print('🖼️ DEBUG: Error: $exception');
                                print('🖼️ DEBUG: Testing alternative URLs...');
                                
                                // Print alternative URLs to test
                                if (product.imageUrl!.contains('/public/')) {
                                  print('🖼️ DEBUG: Try without /public/: ${product.imageUrl!.replaceAll('/public/', '/')}');
                                  print('🖼️ DEBUG: Try with /uploads/: ${product.imageUrl!.replaceAll('/public/images/', '/uploads/')}');
                                  print('🖼️ DEBUG: Try with /static/: ${product.imageUrl!.replaceAll('/public/images/', '/static/')}');
                                }
                              },
                            ),
                            title: Text(
                              product.productName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.category != null && product.category!.isNotEmpty)
                                  Text(
                                    'Category: ${product.category}',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                if (product.brand != null && product.brand!.isNotEmpty)
                                  Text(
                                    'Brand: ${product.brand}',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                if (product.productCode != null && product.productCode!.isNotEmpty)
                                  Text(
                                    'Code: ${product.productCode}',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(product.status),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        product.status.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (product.unit != null) ...[
                                      SizedBox(width: 8),
                                      Text(
                                        'Unit: ${product.unit}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.edit,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                            onTap: () async {
                              print('👆 DEBUG: Product tapped: ${product.productName}');
                              
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductEditPage(
                                    productData: product.toJson(),
                                  ),
                                ),
                              );

                              print('📝 DEBUG: Edit product result: $result');
                              if (result == true || result == 'deleted') {
                                print('🔄 DEBUG: Product operation completed, refreshing list...');
                                fetchProducts();
                                
                                if (result == 'deleted') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Product removed from list'),
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
        onPressed: _onAddProduct,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_product') ?? 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  // ✅ Helper method to find correct image URL path
  String _getCorrectImageUrl(String imageUrl) {
    print('🖼️ DEBUG: Original image URL: $imageUrl');
    
    // Try different URL patterns to find the working one
    List<String> urlsToTry = [];
    
    // Pattern 1: Keep original URL with /public/
    urlsToTry.add(imageUrl);
    
    // Pattern 2: Remove /public/ from URL
    if (imageUrl.contains('/public/')) {
      urlsToTry.add(imageUrl.replaceAll('/public/', '/'));
    }
    
    // Pattern 3: Use direct file path (common for static files)
    if (imageUrl.contains('/public/images/')) {
      urlsToTry.add(imageUrl.replaceAll('/public/images/', '/uploads/'));
      urlsToTry.add(imageUrl.replaceAll('/public/images/', '/static/'));
      urlsToTry.add(imageUrl.replaceAll('/public/images/', '/files/'));
    }
    
    // For now, return the original URL and log all possibilities
    print('🖼️ DEBUG: URLs to try: $urlsToTry');
    
    // Let's first try the original URL
    return imageUrl;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'deleted':
        return Colors.red;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

// Updated Product model to match your IoProduct API structure
class Product {
  final int productId;
  final int companyId;
  final String productName;
  final String? productCode;
  final String? description;
  final String? category;
  final String? brand;
  final String? barcode;
  final int? supplierId;
  final DateTime createdDate;
  final DateTime updatedDate;
  final String? notes;
  final int? unit;
  final String? imageUrl;
  final String status;
  
  Product({
    required this.productId,
    required this.companyId,
    required this.productName,
    this.productCode,
    this.description,
    this.category,
    this.brand,
    this.barcode,
    this.supplierId,
    required this.createdDate,
    required this.updatedDate,
    this.notes,
    this.unit,
    this.imageUrl,
    required this.status,
  });
  
  factory Product.fromJson(Map<String, dynamic> json) {
    print('🔄 DEBUG: Converting JSON to Product');
    print('📝 DEBUG: JSON keys: ${json.keys.toList()}');
    print('📝 DEBUG: JSON data: $json');
    
    try {
      // Handle different date formats
      DateTime parseDate(dynamic dateValue) {
        if (dateValue == null) return DateTime.now();
        if (dateValue is String) {
          try {
            return DateTime.parse(dateValue);
          } catch (e) {
            print('⚠️ DEBUG: Error parsing date string "$dateValue": $e');
            return DateTime.now();
          }
        }
        return DateTime.now();
      }

      final product = Product(
        productId: json['product_id'] ?? 0,
        companyId: json['company_id'] ?? 0,
        productName: json['product_name'] ?? '',
        productCode: json['product_code'],
        description: json['description'],
        category: json['category'],
        brand: json['brand'],
        barcode: json['barcode'],
        supplierId: json['supplier_id'],
        createdDate: parseDate(json['created_date']),
        updatedDate: parseDate(json['updated_date']),
        notes: json['notes'],
        unit: json['unit'],
        imageUrl: json['image_url'],
        status: json['status'] ?? 'active',
      );
      
      print('✅ DEBUG: Successfully created product: ${product.productName}');
      return product;
    } catch (e, stackTrace) {
      print('❌ DEBUG: Error parsing product JSON: $e');
      print('📚 DEBUG: Stack trace: $stackTrace');
      print('📝 DEBUG: Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'company_id': companyId,
      'product_name': productName,
      'product_code': productCode,
      'description': description,
      'category': category,
      'brand': brand,
      'barcode': barcode,
      'supplier_id': supplierId,
      'created_date': createdDate.toIso8601String(),
      'updated_date': updatedDate.toIso8601String(),
      'notes': notes,
      'unit': unit,
      'image_url': imageUrl,
      'status': status,
    };
  }
}