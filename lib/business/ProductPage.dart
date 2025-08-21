import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Inventory/business/ProductAdd.dart';
import 'package:Inventory/business/ProductEdit.dart';
import 'package:Inventory/config/config.dart';
import 'package:Inventory/config/theme.dart';
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
        // Apply category filter
        if (selectedCategory != 'All' && product.category != selectedCategory)
          return false;

        // Apply search filter
        if (query.isNotEmpty) {
          final nameLower = product.productName.toLowerCase();
          final codeLower = product.productCode?.toLowerCase() ?? '';
          final brandLower = product.brand?.toLowerCase() ?? '';

          return nameLower.contains(lowerQuery) ||
              codeLower.contains(lowerQuery) ||
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

    // Add status filter to API call since status column was removed from database
    // This assumes your backend filters for active products by default
    final url = AppConfig.api('/api/ioproducts/company/$companyId?status=active');
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

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final List<dynamic> rawProducts = data['data'] ?? [];
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
    final url = AppConfig.api('/api/ioproducts/company/$companyId/low-stock');
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
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: ThemeConfig.getBackgroundColor(currentTheme),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category Filter
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.2)),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedCategory,
                style: TextStyle(color: textColor, fontSize: 14),
                dropdownColor: ThemeConfig.getBackgroundColor(currentTheme),
                decoration: InputDecoration(
                  labelText: SimpleTranslations.get(langCode, 'category'),
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  prefixIcon: Icon(Icons.category, color: primaryColor, size: 20),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category, 
                    child: Text(
                      category,
                      style: TextStyle(color: textColor),
                      overflow: TextOverflow.ellipsis,
                    )
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value!;
                  });
                  filterProducts(_searchController.text);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Quick actions
          Container(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  selectedCategory = 'All';
                });
                filterProducts('');
              },
              icon: Icon(Icons.clear_all, color: primaryColor),
              tooltip: SimpleTranslations.get(langCode, 'clear_filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.2)),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: SimpleTranslations.get(langCode, 'search'),
            labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
            hintText: SimpleTranslations.get(langCode, 'search_hint'),
            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
            prefixIcon: Icon(Icons.search, color: primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: textColor.withOpacity(0.7)),
                    onPressed: () {
                      _searchController.clear();
                      filterProducts('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductEditPage(
                  productData: {
                    'product_code': product.productCode,
                    'product_name': product.productName,
                    'description': product.description,
                    'category': product.category,
                    'brand': product.brand,
                    'barcode': product.barcode,
                    'supplier_id': product.supplierId,
                    'unit': product.unit,
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
                        'product_deleted_successfully',
                      ),
                    ),
                    backgroundColor: ThemeConfig.getThemeColors(
                      currentTheme,
                    )['success'],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    _getProductIcon(product.category),
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Product Details - Fixed overflow issue
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        product.productName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Product Code and Category
                      if (product.productCode != null || product.category != null)
                        Text(
                          [
                            if (product.productCode != null) product.productCode!,
                            if (product.category != null) product.category!,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      
                      // Stock and Unit Row - Fixed with Wrap to prevent overflow
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Stock Info
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStockColor(product.stockQuantity).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory,
                                  size: 12,
                                  color: _getStockColor(product.stockQuantity),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Stock: ${product.stockQuantity ?? 0}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: _getStockColor(product.stockQuantity),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Unit Badge
                          if (product.unit != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 12,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Unit: ${product.unit}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: textColor.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    
    final totalProducts = products.length;
    final lowStockProducts = products.where((p) => (p.stockQuantity ?? 0) <= 5).length;
    final totalUnits = products.fold<int>(0, (sum, p) => sum + (p.unit ?? 0));
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.1),
            primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.inventory_2,
              label: 'Total',
              value: '$totalProducts',
              color: primaryColor,
            ),
          ),
          Container(width: 1, height: 40, color: primaryColor.withOpacity(0.2)),
          Expanded(
            child: _buildStatItem(
              icon: Icons.confirmation_number,
              label: 'Units',
              value: '$totalUnits',
              color: Colors.blue,
            ),
          ),
          Container(width: 1, height: 40, color: primaryColor.withOpacity(0.2)),
          Expanded(
            child: _buildStatItem(
              icon: Icons.warning,
              label: 'Low Stock',
              value: '$lowStockProducts',
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final textColor = ThemeConfig.getTextColor(currentTheme);
    
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);
    
    if (loading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading products...',
                style: TextStyle(
                  color: ThemeConfig.getTextColor(currentTheme).withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getTextColor(currentTheme),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: fetchProductsByCompany,
                  icon: const Icon(Icons.refresh),
                  label: Text(SimpleTranslations.get(langCode, 'retry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: buttonTextColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          '${SimpleTranslations.get(langCode, 'products')} (${filteredProducts.length})',
          style: TextStyle(
            color: buttonTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: fetchLowStockProducts,
            icon: const Icon(Icons.warning_amber_rounded),
            tooltip: SimpleTranslations.get(langCode, 'check_low_stock'),
          ),
          IconButton(
            onPressed: fetchProductsByCompany,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: SimpleTranslations.get(langCode, 'refresh'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Row
          _buildStatsRow(),
          
          // Search Bar
          _buildSearchBar(),

          // Filter Row
          _buildFilterRow(),

          // Products List
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            SimpleTranslations.get(langCode, 'no_products_found'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ThemeConfig.getTextColor(currentTheme),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by adding your first product',
                            style: TextStyle(
                              fontSize: 14,
                              color: ThemeConfig.getTextColor(currentTheme).withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _onAddProduct,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: buttonTextColor,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : filteredProducts.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            SimpleTranslations.get(langCode, 'no_search_results'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filteredProducts.length,
                    itemBuilder: (ctx, i) {
                      final product = filteredProducts[i];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _onAddProduct,
          backgroundColor: primaryColor,
          foregroundColor: buttonTextColor,
          elevation: 0,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            SimpleTranslations.get(langCode, 'add_product'),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Color _getStockColor(int? stock) {
    final stockValue = stock ?? 0;
    if (stockValue <= 5) return Colors.red;
    if (stockValue <= 20) return Colors.orange;
    return Colors.green;
  }

  IconData _getProductIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'ເຄື່ອງໃຊ້ໄຟຟ້າ':
      case 'electronics':
        return Icons.devices;
      case 'ຄອມພິວເຕີ':
      case 'computers':
        return Icons.computer;
      case 'ຊອບແວ':
      case 'software':
        return Icons.code;
      case 'ອາຫານ ແລະ ເຄື່ອງດື່ມ':
      case 'food & beverage':
        return Icons.restaurant;
      case 'ປື້ມ':
      case 'books':
        return Icons.book;
      case 'education':
        return Icons.school;
      case 'ເຄື່ອງນຸ່ງຫົ່ມ':
      case 'clothing':
        return Icons.checkroom;
      case 'ບ້ານ ແລະ ສວນ':
      case 'home & garden':
        return Icons.home;
      case 'ກິລາ':
      case 'sports':
        return Icons.sports_soccer;
      case 'ຍານຍົນ':
      case 'automotive':
        return Icons.directions_car;
      case 'ສຸຂະພາບ ແລະ ຄວາມງາມ':
      case 'health & beauty':
        return Icons.favorite;
      case 'ເຄື່ອງມື':
      case 'tools':
        return Icons.build;
      case 'ອຸປະກອນສຳນັກງານ':
      case 'office supplies':
        return Icons.business_center;
      case 'ອື່ນໆ':
      case 'other':
        return Icons.category;
      default:
        return Icons.inventory_2;
    }
  }
}

class Product {
  final String productName;
  final String? productCode;
  final String? description;
  final String? category;
  final String? brand;
  final String? barcode;
  final int? supplierId;
  final int? unit;
  final String? notes;
  final int? stockQuantity;
  final String? status; // Added status field
  final DateTime? createdDate;
  final DateTime? updatedDate;

  Product({
    required this.productName,
    this.productCode,
    this.description,
    this.category,
    this.brand,
    this.barcode,
    this.supplierId,
    this.unit,
    this.notes,
    this.stockQuantity,
    this.status,
    this.createdDate,
    this.updatedDate,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse string/number to int
    int? parseToInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Product(
      productName: json['product_name'] ?? '',
      productCode: json['product_code'],
      description: json['description'],
      category: json['category'],
      brand: json['brand'],
      barcode: json['barcode'],
      supplierId: parseToInt(json['supplier_id']),
      unit: parseToInt(json['unit']),
      notes: json['notes'],
      stockQuantity: parseToInt(json['stock_quantity']),
      status: json['status'] ?? 'active', // Default to active if not provided
      createdDate: json['created_date'] != null
          ? DateTime.tryParse(json['created_date'])
          : null,
      updatedDate: json['updated_date'] != null
          ? DateTime.tryParse(json['updated_date'])
          : null,
    );
  }
}