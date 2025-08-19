import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/config/theme.dart';
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
  String currentTheme = 'green';

  // Controllers for form fields
  late TextEditingController _productNameController;
  late TextEditingController _skuController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _brandController;
  late TextEditingController _unitPriceController;
  late TextEditingController _costPriceController;
  late TextEditingController _stockQuantityController;
  late TextEditingController _minimumStockController;
  late TextEditingController _unitOfMeasureController;
  late TextEditingController _weightController;
  late TextEditingController _dimensionsController;
  late TextEditingController _barcodeController;
  late TextEditingController _supplierIdController;
  late TextEditingController _notesController;

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
    _loadTheme();
    _initializeControllers();
  }

  void _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? 'green';
    });
  }

  void _initializeControllers() {
    _productNameController = TextEditingController(text: widget.productData['product_name'] ?? '');
    _skuController = TextEditingController(text: widget.productData['sku'] ?? '');
    _descriptionController = TextEditingController(text: widget.productData['description'] ?? '');
    _categoryController = TextEditingController(text: widget.productData['category'] ?? '');
    _brandController = TextEditingController(text: widget.productData['brand'] ?? '');
    _unitPriceController = TextEditingController(
        text: widget.productData['unit_price']?.toString() ?? '');
    _costPriceController = TextEditingController(
        text: widget.productData['cost_price']?.toString() ?? '');
    _stockQuantityController = TextEditingController(
        text: widget.productData['stock_quantity']?.toString() ?? '0');
    _minimumStockController = TextEditingController(
        text: widget.productData['minimum_stock']?.toString() ?? '0');
    _unitOfMeasureController = TextEditingController(
        text: widget.productData['unit_of_measure'] ?? 'piece');
    _weightController = TextEditingController(
        text: widget.productData['weight']?.toString() ?? '');
    _dimensionsController = TextEditingController(text: widget.productData['dimensions'] ?? '');
    _barcodeController = TextEditingController(text: widget.productData['barcode'] ?? '');
    _supplierIdController = TextEditingController(
        text: widget.productData['supplier_id']?.toString() ?? '');
    _notesController = TextEditingController(text: widget.productData['notes'] ?? '');

    // Set initial status and category
    _selectedStatus = widget.productData['status'] ?? 'active';
    final currentCategory = widget.productData['category'] ?? '';
    if (_predefinedCategories.contains(currentCategory)) {
      _selectedCategory = currentCategory;
    } else {
      _selectedCategory = '';
      _categoryController.text = currentCategory;
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
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

  Future<void> _deleteProduct() async {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    
    // Show confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: ThemeConfig.getBackgroundColor(currentTheme),
          title: Text(
            SimpleTranslations.get(langCode, 'confirm_delete'),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
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
      
      final productCode = widget.productData['product_code']; // Use product_code for API endpoint
      final url = AppConfig.api('/api/ioproduct/delete/$productCode');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Log response details
      print('=== DELETE API RESPONSE DEBUG ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('=================================');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(SimpleTranslations.get(langCode, 'product_discontinued_successfully')),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, 'deleted'); // Return 'deleted' to indicate product was discontinued
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Delete failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('=== DELETE ERROR DEBUG ===');
      print('Error: $e');
      print('==========================');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final productCode = widget.productData['product_code']; // Use product_code for API endpoint
      final url = AppConfig.api('/api/ioproduct/update/$productCode');

      final updateData = <String, dynamic>{};

      // Only include fields that have values (not null or empty)
      if (_productNameController.text.trim().isNotEmpty) {
        updateData['product_name'] = _productNameController.text.trim();
      }
      
      if (_skuController.text.trim().isNotEmpty) {
        updateData['sku'] = _skuController.text.trim();
      }
      
      if (_descriptionController.text.trim().isNotEmpty) {
        updateData['description'] = _descriptionController.text.trim();
      }
      
      // Category: use dropdown selection or custom text
      final categoryValue = _selectedCategory.isNotEmpty 
          ? _selectedCategory 
          : _categoryController.text.trim();
      if (categoryValue.isNotEmpty) {
        updateData['category'] = categoryValue;
      }
      
      if (_brandController.text.trim().isNotEmpty) {
        updateData['brand'] = _brandController.text.trim();
      }
      
      if (_unitPriceController.text.trim().isNotEmpty) {
        updateData['unit_price'] = double.parse(_unitPriceController.text.trim());
      }
      
      if (_costPriceController.text.trim().isNotEmpty) {
        updateData['cost_price'] = double.parse(_costPriceController.text.trim());
      }
      
      if (_stockQuantityController.text.trim().isNotEmpty) {
        updateData['stock_quantity'] = int.parse(_stockQuantityController.text.trim());
      }
      
      if (_minimumStockController.text.trim().isNotEmpty) {
        updateData['minimum_stock'] = int.parse(_minimumStockController.text.trim());
      }
      
      if (_unitOfMeasureController.text.trim().isNotEmpty) {
        updateData['unit_of_measure'] = _unitOfMeasureController.text.trim();
      }
      
      if (_weightController.text.trim().isNotEmpty) {
        updateData['weight'] = double.parse(_weightController.text.trim());
      }
      
      if (_dimensionsController.text.trim().isNotEmpty) {
        updateData['dimensions'] = _dimensionsController.text.trim();
      }
      
      if (_barcodeController.text.trim().isNotEmpty) {
        updateData['barcode'] = _barcodeController.text.trim();
      }
      
      if (_supplierIdController.text.trim().isNotEmpty) {
        updateData['supplier_id'] = int.parse(_supplierIdController.text.trim());
      }
      
      updateData['status'] = _selectedStatus;
      
      if (_notesController.text.trim().isNotEmpty) {
        updateData['notes'] = _notesController.text.trim();
      }

      // Console logging for debugging
      print('=== API REQUEST DEBUG ===');
      print('URL: $url');
      print('Request Body: ${jsonEncode(updateData)}');
      print('Token: Bearer $token');
      print('========================');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      // Log response details
      print('=== API RESPONSE DEBUG ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('==========================');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(SimpleTranslations.get(langCode, 'product_updated_successfully')),
              backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Update failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('=== ERROR DEBUG ===');
      print('Error: $e');
      print('==================');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelKey,
    TextInputType? keyboardType,
    bool required = false,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
    String? hintText,
  }) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: SimpleTranslations.get(langCode, labelKey),
          hintText: hintText,
          labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
          hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return SimpleTranslations.get(langCode, 'field_required');
                }
                return null;
              }
            : null,
      ),
    );
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
              'Basic Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Product Code (Read-only)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                initialValue: widget.productData['product_code'] ?? '',
                enabled: false,
                style: TextStyle(color: textColor.withOpacity(0.6)),
                decoration: InputDecoration(
                  labelText: '${SimpleTranslations.get(langCode, 'product_code')} (Read-only)',
                  labelStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  fillColor: Colors.grey[100],
                  filled: true,
                ),
              ),
            ),
            
            _buildTextField(
              controller: _productNameController,
              labelKey: 'product_name',
              required: true,
            ),
            
            _buildTextField(
              controller: _skuController,
              labelKey: 'sku',
            ),
            
            // Category
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory.isEmpty ? null : _selectedCategory,
                      style: TextStyle(color: textColor),
                      dropdownColor: backgroundColor,
                      decoration: InputDecoration(
                        labelText: SimpleTranslations.get(langCode, 'category'),
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      items: _predefinedCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            style: TextStyle(color: textColor),
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
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'OR',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _categoryController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Custom Category',
                        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _selectedCategory = '';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            _buildTextField(
              controller: _brandController,
              labelKey: 'brand',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing & Inventory',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _unitPriceController,
                    labelKey: 'unit_price',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    hintText: '\$0.00',
                  ),
                ),
                Expanded(
                  child: _buildTextField(
                    controller: _costPriceController,
                    labelKey: 'cost_price',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    hintText: '\$0.00',
                  ),
                ),
              ],
            ),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _stockQuantityController,
                    labelKey: 'stock_quantity',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    required: true,
                  ),
                ),
                Expanded(
                  child: _buildTextField(
                    controller: _minimumStockController,
                    labelKey: 'minimum_stock',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    required: true,
                  ),
                ),
              ],
            ),
            
            _buildTextField(
              controller: _unitOfMeasureController,
              labelKey: 'unit_of_measure',
              hintText: 'piece, kg, liter, etc.',
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
              'Additional Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _descriptionController,
              labelKey: 'description',
              maxLines: 3,
              hintText: 'Product description...',
            ),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _weightController,
                    labelKey: 'weight',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                    ],
                    hintText: 'kg',
                  ),
                ),
                Expanded(
                  child: _buildTextField(
                    controller: _dimensionsController,
                    labelKey: 'dimensions',
                    hintText: 'L x W x H cm',
                  ),
                ),
              ],
            ),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _barcodeController,
                    labelKey: 'barcode',
                  ),
                ),
                Expanded(
                  child: _buildTextField(
                    controller: _supplierIdController,
                    labelKey: 'supplier_id',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            
            // Status
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                style: TextStyle(color: textColor),
                dropdownColor: backgroundColor,
                decoration: InputDecoration(
                  labelText: SimpleTranslations.get(langCode, 'status'),
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('Active', style: TextStyle(color: textColor)),
                  ),
                  DropdownMenuItem(
                    value: 'inactive',
                    child: Text('Inactive', style: TextStyle(color: textColor)),
                  ),
                  DropdownMenuItem(
                    value: 'discontinued',
                    child: Text('Discontinued', style: TextStyle(color: textColor)),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                },
              ),
            ),
            
            _buildTextField(
              controller: _notesController,
              labelKey: 'notes',
              maxLines: 3,
              hintText: 'Additional notes...',
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
        title: Text(
          SimpleTranslations.get(langCode, 'edit_product'),
          style: TextStyle(color: buttonTextColor),
        ),
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        iconTheme: IconThemeData(color: buttonTextColor),
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildBasicInfoSection(),
              _buildPricingSection(),
              _buildDetailsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateProduct,
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        tooltip: SimpleTranslations.get(langCode, 'update_product'),
        child: Icon(Icons.save, color: buttonTextColor),
      ),
    );
  }
}