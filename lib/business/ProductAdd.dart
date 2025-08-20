import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sabaicub/config/config.dart';
import 'package:sabaicub/config/theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  // Cache these values to avoid repeated calls
  late Color primaryColor;
  late Color backgroundColor;
  late Color textColor;
  late Color buttonTextColor;

  // Text Controllers
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _dimensionsController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _supplierIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedStatus = 'active';
  String _selectedCategory = '';

  // Predefined categories - made const for better performance
  static const List<String> _predefinedCategories = [
    'ເຄື່ອງໃຊ້ໄຟຟ້າ',
    'ຄອມພິວເຕີ',
    'ຊອບແວ',
    'ອາຫານ ແລະ ເຄື່ອງດື່ມ',
    'ປື້ມ',
    'ເຄື່ອງນຸ່ງຫົ່ມ',
    'ບ້ານ ແລະ ສວນ',
    'ກິລາ',
    'ຍານຍົນ',
    'ສຸຂະພາບ ແລະ ຄວາມງາມ',
    'ເຄື່ອງມື',
    'ອຸປະກອນສຳນັກງານ',
    'ອື່ນໆ',
  ];

  @override
  void initState() {
    super.initState();
    _initializeColors();
    _loadSettings();
  }

  // Cache colors to avoid repeated theme calls
  void _initializeColors() {
    primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    textColor = ThemeConfig.getTextColor(currentTheme);
    buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);
  }

  // Load settings asynchronously but don't block UI
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final newLangCode = prefs.getString('languageCode') ?? 'en';
    final newTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    
    if (mounted && (newLangCode != langCode || newTheme != currentTheme)) {
      setState(() {
        langCode = newLangCode;
        currentTheme = newTheme;
      });
      _initializeColors();
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productCodeController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _barcodeController.dispose();
    _supplierIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Optimized barcode scanning with better error handling
  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerPage(),
        ),
      );
      
      if (result != null && result.isNotEmpty && mounted) {
        setState(() {
          _barcodeController.text = result;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Barcode scanned: $result'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Scanning failed: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      // Prepare product data more efficiently
      final productData = <String, dynamic>{
        'company_id': widget.companyId,
        'product_name': _productNameController.text.trim(),
        'status': _selectedStatus,
      };

      // Only add non-empty fields
      void addIfNotEmpty(String key, String? value) {
        if (value != null && value.trim().isNotEmpty) {
          productData[key] = value.trim();
        }
      }

      addIfNotEmpty('product_code', _productCodeController.text);
      addIfNotEmpty('sku', _skuController.text);
      addIfNotEmpty('description', _descriptionController.text);
      addIfNotEmpty('brand', _brandController.text);
      addIfNotEmpty('dimensions', _dimensionsController.text);
      addIfNotEmpty('barcode', _barcodeController.text);
      addIfNotEmpty('notes', _notesController.text);

      // Handle category
      if (_selectedCategory.isNotEmpty) {
        productData['category'] = _selectedCategory;
      } else if (_categoryController.text.trim().isNotEmpty) {
        productData['category'] = _categoryController.text.trim();
      }

      // Handle numeric fields
      if (_weightController.text.trim().isNotEmpty) {
        try {
          productData['weight'] = double.parse(_weightController.text.trim());
        } catch (e) {
          throw Exception('Invalid weight format');
        }
      }

      if (_supplierIdController.text.trim().isNotEmpty) {
        try {
          productData['supplier_id'] = int.parse(_supplierIdController.text.trim());
        } catch (e) {
          throw Exception('Invalid supplier ID format');
        }
      }

      final url = AppConfig.api('/api/ioproduct/add');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(productData),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      responseData['message'] ?? 'Product added successfully',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          Navigator.pop(context, true);
        } else {
          throw Exception(responseData['message'] ?? 'Failed to add product');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error occurred');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
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

  // Create reusable input decoration to avoid repeated object creation
  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
      hintText: hintText,
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
      prefixIcon: Icon(prefixIcon, color: primaryColor),
      filled: true,
      fillColor: backgroundColor,
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Basic Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barcode with scan button - Fixed Row layout
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _barcodeController,
                    style: TextStyle(color: textColor),
                    decoration: _buildInputDecoration(
                      labelText: 'Barcode',
                      prefixIcon: Icons.qr_code_scanner,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Scan button
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _scanBarcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: buttonTextColor,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.qr_code_scanner, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Product Name (Required)
            TextFormField(
              controller: _productNameController,
              style: TextStyle(color: textColor),
              decoration: _buildInputDecoration(
                labelText: 'Product Name *',
                prefixIcon: Icons.inventory_2,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Product name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Product Code and SKU in a row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _productCodeController,
                    style: TextStyle(color: textColor),
                    decoration: _buildInputDecoration(
                      labelText: 'Product Code',
                      prefixIcon: Icons.qr_code,
                      hintText: 'e.g., PRD-001',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    style: TextStyle(color: textColor),
                    decoration: _buildInputDecoration(
                      labelText: 'SKU',
                      prefixIcon: Icons.tag,
                      hintText: 'Stock Keeping Unit',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Category and Brand in a row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2, // Give more space to category dropdown
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory.isEmpty ? null : _selectedCategory,
                    style: TextStyle(color: textColor, fontSize: 14), // Smaller font
                    dropdownColor: backgroundColor,
                    isExpanded: true, // Prevent overflow
                    decoration: _buildInputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icons.category,
                    ),
                    items: _predefinedCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 200), // Limit width
                          child: Text(
                            category, 
                            style: TextStyle(color: textColor, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
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
                const SizedBox(width: 12), // Reduced spacing
                Expanded(
                  flex: 1, // Less space for brand
                  child: TextFormField(
                    controller: _brandController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: _buildInputDecoration(
                      labelText: 'Brand',
                      prefixIcon: Icons.branding_watermark,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Additional Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: _buildInputDecoration(
                labelText: 'Description',
                prefixIcon: Icons.description,
                hintText: 'Product description...',
              ),
            ),
            const SizedBox(height: 16),
            
            // Weight, Dimensions, and Supplier ID in rows
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                    ],
                    style: TextStyle(color: textColor),
                    decoration: _buildInputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: Icons.scale,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _dimensionsController,
                    style: TextStyle(color: textColor),
                    decoration: _buildInputDecoration(
                      labelText: 'Dimensions',
                      prefixIcon: Icons.aspect_ratio,
                      hintText: 'L x W x H cm',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _supplierIdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: textColor),
                    decoration: _buildInputDecoration(
                      labelText: 'Supplier ID',
                      prefixIcon: Icons.business,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    style: TextStyle(color: textColor, fontSize: 14),
                    dropdownColor: backgroundColor,
                    isExpanded: true, // Prevent overflow
                    decoration: _buildInputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icons.toggle_on,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: _buildInputDecoration(
                labelText: 'Notes',
                prefixIcon: Icons.note,
                hintText: 'Additional notes about the product...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Add Product',
          style: TextStyle(color: buttonTextColor),
        ),
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        iconTheme: IconThemeData(color: buttonTextColor),
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _buildBasicInfoSection(),
                    _buildDetailsSection(),
                  ],
                ),
              ),
            ),
            
            // Submit Button - Fixed at bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: buttonTextColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
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
                    : const Text(
                        'Add Product',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Optimized Barcode Scanner Page
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late MobileScannerController cameraController;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning || !mounted) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() {
          _isScanning = false;
        });
        
        // Vibrate to indicate successful scan
        HapticFeedback.mediumImpact();
        
        // Return the scanned barcode
        Navigator.of(context).pop(barcode.rawValue);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: state == TorchState.on ? Colors.yellow : Colors.white,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          
          // Simple overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          // Instructions
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Position the barcode within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isScanning ? 'Scanning...' : 'Processing...',
                    style: TextStyle(
                      color: _isScanning ? Colors.green : Colors.orange,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Manual input button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}