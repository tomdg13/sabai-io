import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/business/ProductAdd.dart';
import 'package:sabaicub/business/ProductEdit.dart';
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int companyId = 1;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();
  String selectedCategory = 'All';
  String selectedStatus = 'active';
  List<String> categories = ['All'];

  @override
  void initState() {
    super.initState();
    _loadLangCode();
    _loadCompanyId();
    _loadCurrentTheme();
    fetchProductsByCompany();
    _searchController.addListener(() {
      filterProducts(_searchController.text);
    });
  }

  void _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  void _loadCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      companyId = prefs.getInt('company_id') ?? 1;
    });
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void filterProducts(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredProducts = products.where((product) {
        // Apply status filter
        if (selectedStatus != 'all' && product.status != selectedStatus)
          return false;

        // Apply category filter
        if (selectedCategory != 'All' && product.category != selectedCategory)
          return false;

        // Apply search filter
        if (query.isNotEmpty) {
          final nameLower = product.productName.toLowerCase();
          final codeLower = product.productCode?.toLowerCase() ?? '';
          final skuLower = product.sku?.toLowerCase() ?? '';
          final brandLower = product.brand?.toLowerCase() ?? '';

          return nameLower.contains(lowerQuery) ||
              codeLower.contains(lowerQuery) ||
              skuLower.contains(lowerQuery) ||
              brandLower.contains(lowerQuery);
        }

        return true;
      }).toList();
    });
  }

  void _updateCategories() {
    final uniqueCategories = products
        .map((product) => product.category ?? 'Uncategorized')
        .toSet()
        .toList();

    setState(() {
      categories = ['All', ...uniqueCategories];
    });
  }

  Future<void> fetchProductsByCompany() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/ioproduct/productsByCompany');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final requestBody = {'company_id': companyId, 'status': 'active'};

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final List<dynamic> rawProducts = data['data'] ?? [];
          Product._parseCount = 0;
          products = rawProducts.map((e) => Product.fromJson(e)).toList();

          _updateCategories();
          filteredProducts = List.from(products);

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

  Future<void> fetchLowStockProducts() async {
    final url = AppConfig.api('/api/ioproduct/lowstock/$companyId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final List<dynamic> rawProducts = data['data'] ?? [];
          final lowStockProducts = rawProducts
              .map((e) => Product.fromJson(e))
              .toList();

          if (lowStockProducts.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${lowStockProducts.length} ${SimpleTranslations.get(langCode, 'products_low_stock')}',
                ),
                backgroundColor: ThemeConfig.getThemeColors(
                  currentTheme,
                )['warning'],
                action: SnackBarAction(
                  label: SimpleTranslations.get(langCode, 'view_details'),
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      products = lowStockProducts;
                      filteredProducts = List.from(products);
                    });
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  SimpleTranslations.get(langCode, 'adequate_stock_message'),
                ),
                backgroundColor: ThemeConfig.getThemeColors(
                  currentTheme,
                )['success'],
              ),
            );
          }
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  void _onAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductAddPage(companyId: companyId),
      ),
    );

    if (result == true) {
      fetchProductsByCompany();
    }
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Category Filter
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'category'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                    width: 2,
                  ),
                ),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value!;
                });
                filterProducts(_searchController.text);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Status Filter
          // Expanded(
          //   flex: 1,
          //   child: DropdownButtonFormField<String>(
          //     value: selectedStatus,
          //     decoration: InputDecoration(
          //       labelText: SimpleTranslations.get(langCode, 'status'),
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(8),
          //       ),
          //       contentPadding: const EdgeInsets.symmetric(
          //         horizontal: 12,
          //         vertical: 8,
          //       ),
          //       focusedBorder: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(8),
          //         borderSide: BorderSide(
          //           color: ThemeConfig.getPrimaryColor(currentTheme),
          //           width: 2,
          //         ),
          //       ),
          //     ),
          //     items: [
          //       DropdownMenuItem(
          //         value: 'all',
          //         child: Text(SimpleTranslations.get(langCode, 'all')),
          //       ),
          //       DropdownMenuItem(
          //         value: 'active',
          //         child: Text(SimpleTranslations.get(langCode, 'active')),
          //       ),
          //       DropdownMenuItem(
          //         value: 'inactive',
          //         child: Text(SimpleTranslations.get(langCode, 'inactive')),
          //       ),
          //       DropdownMenuItem(
          //         value: 'discontinued',
          //         child: Text(SimpleTranslations.get(langCode, 'discontinued')),
          //       ),
          //     ],
          //     onChanged: (value) {
          //       setState(() {
          //         selectedStatus = value!;
          //       });
          //       filterProducts(_searchController.text);
          //     },
          //   ),
          // ),
       
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              ThemeConfig.getPrimaryColor(currentTheme),
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: ThemeConfig.getThemeColors(currentTheme)['error'],
              ),
              const SizedBox(height: 16),
              Text(
                error!,
                style: TextStyle(
                  color: ThemeConfig.getThemeColors(currentTheme)['error'],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchProductsByCompany,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                  foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                ),
                child: Text(SimpleTranslations.get(langCode, 'retry')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${SimpleTranslations.get(langCode, 'products')} (${filteredProducts.length})',
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            onPressed: fetchLowStockProducts,
            icon: const Icon(Icons.warning),
            tooltip: SimpleTranslations.get(langCode, 'check_low_stock'),
          ),
          IconButton(
            onPressed: fetchProductsByCompany,
            icon: const Icon(Icons.refresh),
            tooltip: SimpleTranslations.get(langCode, 'refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'search'),
                hintText: SimpleTranslations.get(langCode, 'search_hint'),
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

          // Filter Row
          _buildFilterRow(),

          // Products List
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          SimpleTranslations.get(langCode, 'no_products_found'),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          SimpleTranslations.get(langCode, 'no_search_results'),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (ctx, i) {
                      final product = filteredProducts[i];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(product.status),
                            child: Icon(
                              _getProductIcon(product.category),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            product.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                                '${SimpleTranslations.get(langCode, 'Stock')}: ${product.stockQuantity}',
                              ),
                          // trailing: Row(
                          //   mainAxisSize: MainAxisSize.min,
                          //   children: [
                          //     Text(
                          //       '${SimpleTranslations.get(langCode, 'Amt:')}: ${product.stockQuantity}',
                          //     ),
                          //     const SizedBox(width: 16),
                          //   ],
                          // ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductEditPage(
                                  productData: {
                                    'product_code': product.productCode,
                                    'product_name': product.productName,
                                    'sku': product.sku,
                                    'description': product.description,
                                    'category': product.category,
                                    'brand': product.brand,
                                    'unit_price': product.unitPrice,
                                    'cost_price': product.costPrice,
                                    'stock_quantity': product.stockQuantity,
                                    'minimum_stock': product.minimumStock,
                                    'unit_of_measure': product.unitOfMeasure,
                                    'weight': product.weight,
                                    'dimensions': product.dimensions,
                                    'barcode': product.barcode,
                                    'supplier_id': product.supplierId,
                                    'status': product.status,
                                    'notes': product.notes,
                                  },
                                ),
                              ),
                            );

                            if (result == true || result == 'deleted') {
                              fetchProductsByCompany();

                              if (result == 'deleted') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      SimpleTranslations.get(
                                        langCode,
                                        'product_discontinued_successfully',
                                      ),
                                    ),
                                    backgroundColor: ThemeConfig.getThemeColors(
                                      currentTheme,
                                    )['success'],
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
        onPressed: _onAddProduct,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_product'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return ThemeConfig.getThemeColors(currentTheme)['success'] ??
            Colors.green;
      case 'inactive':
        return ThemeConfig.getThemeColors(currentTheme)['warning'] ??
            Colors.orange;
      case 'discontinued':
        return ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return SimpleTranslations.get(langCode, 'active');
      case 'inactive':
        return SimpleTranslations.get(langCode, 'inactive');
      case 'discontinued':
        return SimpleTranslations.get(langCode, 'discontinued');
      default:
        return status;
    }
  }

  IconData _getProductIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'electronics':
        return Icons.devices;
      case 'computers':
        return Icons.computer;
      case 'software':
        return Icons.code;
      case 'food & beverage':
        return Icons.restaurant;
      case 'books':
        return Icons.book;
      case 'clothing':
        return Icons.checkroom;
      default:
        return Icons.inventory_2;
    }
  }

}

class Product {
  final String productName;
  final String? productCode;
  final String? sku;
  final String? description;
  final String? category;
  final String? brand;
  final double? unitPrice;
  final double? costPrice;
  final int stockQuantity;
  final int? minimumStock;
  final String? unitOfMeasure;
  final double? weight;
  final String? dimensions;
  final String? barcode;
  final int? supplierId;
  final String status;
  final String? notes;
  final DateTime? createdDate;
  final DateTime? updatedDate;

  static int _parseCount = 0;

  Product({
    required this.productName,
    this.productCode,
    this.sku,
    this.description,
    this.category,
    this.brand,
    this.unitPrice,
    this.costPrice,
    required this.stockQuantity,
    this.minimumStock,
    this.unitOfMeasure,
    this.weight,
    this.dimensions,
    this.barcode,
    this.supplierId,
    required this.status,
    this.notes,
    this.createdDate,
    this.updatedDate,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse string/number to double
    double? parseToDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // Helper function to safely parse string/number to int
    int? parseToInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    _parseCount++;

    return Product(
      productName: json['product_name'] ?? '',
      productCode: json['product_code'],
      sku: json['sku'],
      description: json['description'],
      category: json['category'],
      brand: json['brand'],
      unitPrice: parseToDouble(json['unit_price']),
      costPrice: parseToDouble(json['cost_price']),
      stockQuantity: parseToInt(json['stock_quantity']) ?? 0,
      minimumStock: parseToInt(json['minimum_stock']),
      unitOfMeasure: json['unit_of_measure'],
      weight: parseToDouble(json['weight']),
      dimensions: json['dimensions'],
      barcode: json['barcode'],
      supplierId: parseToInt(json['supplier_id']),
      status: json['status'] ?? 'active',
      notes: json['notes'],
      createdDate: json['created_date'] != null
          ? DateTime.tryParse(json['created_date'])
          : null,
      updatedDate: json['updated_date'] != null
          ? DateTime.tryParse(json['updated_date'])
          : null,
    );
  }
}
