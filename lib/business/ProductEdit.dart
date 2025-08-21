import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:Inventory/config/config.dart';
import 'package:Inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductEditPage extends StatefulWidget {
  final Map<String, dynamic> productData;
  
  const ProductEditPage({Key? key, required this.productData}) : super(key: key);

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme;

  // Pre-calculate colors for performance - Initialize with defaults
  Color primaryColor = const Color(0xFF4CAF50);
  Color backgroundColor = const Color(0xFFF1F8E9);
  Color textColor = const Color(0xFF1B5E20);
  Color buttonTextColor = const Color(0xFFFFFFFF);

  // Controllers for form fields - Only schema fields
  late final TextEditingController _productNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _supplierIdController;
  late final TextEditingController _unitController; // New field
  late final TextEditingController _notesController;

  String _selectedCategory = '';

  // Simplified categories
  static const _categories = [
    'Electronics',
    'Education',
    'Food & Beverage',
    'Clothing',
    'Tools',
    'Office Supplies',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadLangCode();
    _loadCurrentTheme();
    _initializeControllers();
  }

  void _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        langCode = prefs.getString('languageCode') ?? 'en';
      });
    }
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      });
      _initializeTheme();
    }
  }

  void _initializeTheme() {
    if (mounted) {
      setState(() {
        // Initialize theme colors
        primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
        backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
        textColor = ThemeConfig.getTextColor(currentTheme);
        buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);
      });
    }
  }

  void _initializeControllers() {
    _productNameController = TextEditingController(text: widget.productData['product_name'] ?? '');
    _descriptionController = TextEditingController(text: widget.productData['description'] ?? '');
    _categoryController = TextEditingController(text: widget.productData['category'] ?? '');
    _brandController = TextEditingController(text: widget.productData['brand'] ?? '');
    _barcodeController = TextEditingController(text: widget.productData['barcode'] ?? '');
    _supplierIdController = TextEditingController(text: widget.productData['supplier_id']?.toString() ?? '');
    _unitController = TextEditingController(text: widget.productData['unit']?.toString() ?? '');
    _notesController = TextEditingController(text: widget.productData['notes'] ?? '');

    // Set initial category
    final currentCategory = widget.productData['category'] ?? '';
    if (_categories.contains(currentCategory)) {
      _selectedCategory = currentCategory;
    } else {
      _selectedCategory = '';
      _categoryController.text = currentCategory;
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _supplierIdController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _deleteProduct() async {
    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            SimpleTranslations.get(langCode, 'confirm_delete'),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            SimpleTranslations.get(langCode, 'delete_product_confirmation'),
            style: TextStyle(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                SimpleTranslations.get(langCode, 'cancel'),
                style: TextStyle(color: textColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(SimpleTranslations.get(langCode, 'delete')),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final productCode = widget.productData['product_code'];
      final url = AppConfig.api('/api/ioproducts/$productCode');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showMessage(SimpleTranslations.get(langCode, 'product_deleted_successfully'), isError: false);
          Navigator.pop(context, 'deleted');
        } else {
          _showMessage(data['message'] ?? 'Delete failed', isError: true);
        }
      } else {
        _showMessage('Server error: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('Failed to delete product: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final productCode = widget.productData['product_code'];
      final url = AppConfig.api('/api/ioproducts/$productCode');

      final updateData = <String, dynamic>{};

      // Only include non-empty fields
      _addIfNotEmpty(updateData, 'product_name', _productNameController.text);
      _addIfNotEmpty(updateData, 'description', _descriptionController.text);
      _addIfNotEmpty(updateData, 'brand', _brandController.text);
      _addIfNotEmpty(updateData, 'barcode', _barcodeController.text);
      _addIfNotEmpty(updateData, 'notes', _notesController.text);

      // Category: use dropdown selection or custom text
      final categoryValue = _selectedCategory.isNotEmpty 
          ? _selectedCategory 
          : _categoryController.text.trim();
      if (categoryValue.isNotEmpty) {
        updateData['category'] = categoryValue;
      }

      // Parse numeric fields
      final unit = _unitController.text.trim();
      if (unit.isNotEmpty) {
        updateData['unit'] = int.tryParse(unit);
      }

      final supplierId = _supplierIdController.text.trim();
      if (supplierId.isNotEmpty) {
        updateData['supplier_id'] = int.tryParse(supplierId);
      }

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showMessage(SimpleTranslations.get(langCode, 'product_updated_successfully'), isError: false);
          Navigator.pop(context, true);
        } else {
          _showMessage(data['message'] ?? 'Update failed', isError: true);
        }
      } else {
        _showMessage('Server error: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showMessage('Failed to update product: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper methods
  void _addIfNotEmpty(Map<String, dynamic> data, String key, String value) {
    if (value.trim().isNotEmpty) {
      data[key] = value.trim();
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
      hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: backgroundColor,
    );
  }

  Widget _buildSectionHeader(String titleKey) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        SimpleTranslations.get(langCode, titleKey),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(SimpleTranslations.get(langCode, 'edit_product')),
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        actions: [
          IconButton(
            onPressed: _deleteProduct,
            icon: const Icon(Icons.delete),
            tooltip: SimpleTranslations.get(langCode, 'delete_product'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    _buildSectionHeader('basic_information'),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Product Code (Read-only)
                          TextFormField(
                            initialValue: widget.productData['product_code'] ?? '',
                            enabled: false,
                            decoration: _inputDecoration(
                              SimpleTranslations.get(langCode, 'product_code_readonly')
                            ),
                            style: TextStyle(color: textColor.withOpacity(0.6)),
                          ),
                          const SizedBox(height: 16),

                          // Product Name (Required)
                          TextFormField(
                            controller: _productNameController,
                            decoration: _inputDecoration(
                              '${SimpleTranslations.get(langCode, 'product_name')} *'
                            ),
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return SimpleTranslations.get(langCode, 'field_required');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Category Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCategory.isEmpty ? null : _selectedCategory,
                            decoration: _inputDecoration(
                              SimpleTranslations.get(langCode, 'category')
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
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
                          const SizedBox(height: 16),

                          // Brand
                          TextFormField(
                            controller: _brandController,
                            decoration: _inputDecoration(
                              SimpleTranslations.get(langCode, 'brand')
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Unit Quantity
                          TextFormField(
                            controller: _unitController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _inputDecoration(
                              SimpleTranslations.get(langCode, 'unit_quantity'),
                              hint: SimpleTranslations.get(langCode, 'unit_hint')
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Additional Details
                    _buildSectionHeader('additional_details'),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: _inputDecoration(
                              SimpleTranslations.get(langCode, 'description'),
                              hint: SimpleTranslations.get(langCode, 'description_hint')
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Barcode
                          TextFormField(
                            controller: _barcodeController,
                            decoration: _inputDecoration(
                              SimpleTranslations.get(langCode, 'barcode')
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Supplier ID
                          TextFormField(
                            controller: _supplierIdController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _inputDecoration(
                              SimpleTranslations.get(langCode, 'supplier_id')
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Notes
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: _inputDecoration(
                              SimpleTranslations.get(langCode, 'notes'),
                              hint: SimpleTranslations.get(langCode, 'notes_hint')
                            ),
                          ),
                          const SizedBox(height: 80), // Space for FAB
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _updateProduct,
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        icon: const Icon(Icons.save),
        label: Text(SimpleTranslations.get(langCode, 'update')),
      ),
    );
  }
}