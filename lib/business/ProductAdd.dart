import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductAddPage extends StatefulWidget {
  final int companyId;
  
  const ProductAddPage({Key? key, required this.companyId}) : super(key: key);

  @override
  State<ProductAddPage> createState() => _ProductAddPageState();
}

class _ProductAddPageState extends State<ProductAddPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme;

  // Text Controllers
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _stockQuantityController = TextEditingController();
  final TextEditingController _minimumStockController = TextEditingController();
  final TextEditingController _unitOfMeasureController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _dimensionsController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _supplierIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedStatus = 'active';
  String _selectedCategory = '';

  // Predefined categories
  final List<String> _predefinedCategories = [
    'Electronics',
    'Computers',
    'Software',
    'Food & Beverage',
    'Books',
    'Clothing',
    'Home & Garden',
    'Sports',
    'Automotive',
    'Health & Beauty',
    'Tools',
    'Office Supplies',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadLangCode();
    _loadCurrentTheme();
    _unitOfMeasureController.text = 'piece'; // Default unit
    _stockQuantityController.text = '0'; // Default stock
    _minimumStockController.text = '0'; // Default minimum stock
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
    _productNameController.dispose();
    _productCodeController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _unitPriceController.dispose();
    _costPriceController.dispose();
    _stockQuantityController.dispose();
    _minimumStockController.dispose();
    _unitOfMeasureController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _barcodeController.dispose();
    _supplierIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      // Prepare product data
      final productData = {
        'company_id': widget.companyId,
        'product_name': _productNameController.text.trim(),
        'product_code': _productCodeController.text.trim().isNotEmpty 
            ? _productCodeController.text.trim() 
            : null,
        'sku': _skuController.text.trim().isNotEmpty 
            ? _skuController.text.trim() 
            : null,
        'description': _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        'category': _selectedCategory.isNotEmpty 
            ? _selectedCategory 
            : (_categoryController.text.trim().isNotEmpty 
                ? _categoryController.text.trim() 
                : null),
        'brand': _brandController.text.trim().isNotEmpty 
            ? _brandController.text.trim() 
            : null,
        'unit_price': _unitPriceController.text.trim().isNotEmpty 
            ? double.parse(_unitPriceController.text.trim()) 
            : null,
        'cost_price': _costPriceController.text.trim().isNotEmpty 
            ? double.parse(_costPriceController.text.trim()) 
            : null,
        'stock_quantity': int.parse(_stockQuantityController.text.trim()),
        'minimum_stock': int.parse(_minimumStockController.text.trim()),
        'unit_of_measure': _unitOfMeasureController.text.trim(),
        'weight': _weightController.text.trim().isNotEmpty 
            ? double.parse(_weightController.text.trim()) 
            : null,
        'dimensions': _dimensionsController.text.trim().isNotEmpty 
            ? _dimensionsController.text.trim() 
            : null,
        'barcode': _barcodeController.text.trim().isNotEmpty 
            ? _barcodeController.text.trim() 
            : null,
        'supplier_id': _supplierIdController.text.trim().isNotEmpty 
            ? int.parse(_supplierIdController.text.trim()) 
            : null,
        'status': _selectedStatus,
        'notes': _notesController.text.trim().isNotEmpty 
            ? _notesController.text.trim() 
            : null,
      };

      print('=== PRODUCT CREATION REQUEST ===');
      print('Request data: ${jsonEncode(productData)}');

      final url = AppConfig.api('/api/ioproduct/add');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(productData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  responseData['message'] ?? SimpleTranslations.get(langCode, 'product_added_successfully')
                ),
                backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
              ),
            );
            Navigator.pop(context, true); // Return true to indicate success
          }
        } else {
          throw Exception(responseData['message'] ?? SimpleTranslations.get(langCode, 'failed_to_add_product'));
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? SimpleTranslations.get(langCode, 'failed_to_add_product'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${SimpleTranslations.get(langCode, 'error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildBasicInfoSection() {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SimpleTranslations.get(langCode, 'basic_information'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Product Name (Required)
            TextFormField(
              controller: _productNameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: '${SimpleTranslations.get(langCode, 'product_name')} *',
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.inventory_2, color: primaryColor),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return SimpleTranslations.get(langCode, 'product_name_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Product Code
            TextFormField(
              controller: _productCodeController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'product_code'),
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.qr_code, color: primaryColor),
                hintText: 'e.g., PRD-001',
                hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 16),
            
            // SKU
            TextFormField(
              controller: _skuController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'sku'),
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.tag, color: primaryColor),
                hintText: 'Stock Keeping Unit',
                hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 16),
            
            // Category - Fixed layout to prevent overflow
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Predefined Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory.isEmpty ? null : _selectedCategory,
                  style: TextStyle(color: textColor),
                  dropdownColor: backgroundColor,
                  decoration: InputDecoration(
                    labelText: SimpleTranslations.get(langCode, 'category'),
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    prefixIcon: Icon(Icons.category, color: primaryColor),
                  ),
                  items: _predefinedCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category, 
                        style: TextStyle(color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? '';
                      if (value != null) {
                        _categoryController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // OR Divider
                Center(
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: textColor.withOpacity(0.6), 
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Custom Category Input
                TextFormField(
                  controller: _categoryController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: SimpleTranslations.get(langCode, 'custom_category'),
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    prefixIcon: Icon(Icons.edit, color: primaryColor),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _selectedCategory = '';
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Brand
            TextFormField(
              controller: _brandController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'brand'),
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.branding_watermark, color: primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SimpleTranslations.get(langCode, 'pricing_inventory'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                // Unit Price
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: SimpleTranslations.get(langCode, 'unit_price'),
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.attach_money, color: primaryColor),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return SimpleTranslations.get(langCode, 'invalid_price');
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Cost Price
                Expanded(
                  child: TextFormField(
                    controller: _costPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: SimpleTranslations.get(langCode, 'cost_price'),
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.money_off, color: primaryColor),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return SimpleTranslations.get(langCode, 'invalid_cost');
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                // Stock Quantity
                Expanded(
                  child: TextFormField(
                    controller: _stockQuantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: '${SimpleTranslations.get(langCode, 'stock_quantity')} *',
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.inventory, color: primaryColor),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return SimpleTranslations.get(langCode, 'stock_quantity_required');
                      }
                      final stock = int.tryParse(value);
                      if (stock == null || stock < 0) {
                        return SimpleTranslations.get(langCode, 'invalid_stock_quantity');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Minimum Stock
                Expanded(
                  child: TextFormField(
                    controller: _minimumStockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: '${SimpleTranslations.get(langCode, 'minimum_stock')} *',
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.warning, color: primaryColor),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return SimpleTranslations.get(langCode, 'minimum_stock_required');
                      }
                      final stock = int.tryParse(value);
                      if (stock == null || stock < 0) {
                        return SimpleTranslations.get(langCode, 'invalid_minimum_stock');
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Unit of Measure
            TextFormField(
              controller: _unitOfMeasureController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'unit_of_measure'),
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.straighten, color: primaryColor),
                hintText: 'piece, kg, liter, etc.',
                hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SimpleTranslations.get(langCode, 'additional_details'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'description'),
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.description, color: primaryColor),
                hintText: 'Product description...',
                hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                // Weight
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                    ],
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: SimpleTranslations.get(langCode, 'weight'),
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.scale, color: primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Dimensions
                Expanded(
                  child: TextFormField(
                    controller: _dimensionsController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: SimpleTranslations.get(langCode, 'dimensions'),
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.aspect_ratio, color: primaryColor),
                      hintText: 'L x W x H cm',
                      hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                // Barcode
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: SimpleTranslations.get(langCode, 'barcode'),
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.qr_code_scanner, color: primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Supplier ID
                Expanded(
                  child: TextFormField(
                    controller: _supplierIdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: SimpleTranslations.get(langCode, 'supplier_id'),
                      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.business, color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Status
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              style: TextStyle(color: textColor),
              dropdownColor: backgroundColor,
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'status'),
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.toggle_on, color: primaryColor),
              ),
              items: [
                DropdownMenuItem(
                  value: 'active',
                  child: Text(SimpleTranslations.get(langCode, 'active'), style: TextStyle(color: textColor)),
                ),
                DropdownMenuItem(
                  value: 'inactive',
                  child: Text(SimpleTranslations.get(langCode, 'inactive'), style: TextStyle(color: textColor)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'notes'),
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.note, color: primaryColor),
                hintText: 'Additional notes about the product...',
                hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCode, 'add_product'),
          style: TextStyle(color: buttonTextColor),
        ),
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        iconTheme: IconThemeData(color: buttonTextColor),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildBasicInfoSection(),
              _buildPricingSection(),
              _buildDetailsSection(),
              
              // Submit Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: buttonTextColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(buttonTextColor),
                          ),
                        )
                      : Text(
                          SimpleTranslations.get(langCode, 'add_product'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}