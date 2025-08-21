import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:Inventory/config/config.dart';
import 'package:Inventory/config/theme.dart';
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

  // Pre-calculate colors once
  late final Color primaryColor;
  late final Color backgroundColor;
  late final Color textColor;
  late final Color buttonTextColor;

  // Text Controllers - Only essential fields
  final _productNameController = TextEditingController();
  final _productCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _supplierIdController = TextEditingController();
  final _unitController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = '';

  // Optimized categories list
  static const _categories = [
    'Electronics',
    'Education',
    'Food & Beverage',
    'Clothing',
    'Tools',
    'Office Supplies',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeTheme();
  }

  // Initialize theme colors once
  void _initializeTheme() {
    primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    textColor = ThemeConfig.getTextColor(currentTheme);
    buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);
  }

  @override
  void dispose() {
    // Dispose all controllers
    _productNameController.dispose();
    _productCodeController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _supplierIdController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Fast barcode scanning
  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
      );
      
      if (result?.isNotEmpty == true && mounted) {
        _barcodeController.text = result!;
        _showMessage('Barcode scanned: $result', isError: false);
      }
    } catch (e) {
      if (mounted) _showMessage('Scanning failed', isError: true);
    }
  }

  // Optimized product creation
  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token?.isEmpty != false) {
        throw Exception('Please login again');
      }

      // Build minimal request data
      final data = <String, dynamic>{
        'company_id': widget.companyId,
        'product_name': _productNameController.text.trim(),
      };

      // Add optional fields if not empty
      _addIfNotEmpty(data, 'product_code', _productCodeController.text);
      _addIfNotEmpty(data, 'description', _descriptionController.text);
      _addIfNotEmpty(data, 'brand', _brandController.text);
      _addIfNotEmpty(data, 'barcode', _barcodeController.text);
      _addIfNotEmpty(data, 'notes', _notesController.text);
      _addIfNotEmpty(data, 'category', _selectedCategory);

      // Parse numeric fields
      final unit = _unitController.text.trim();
      if (unit.isNotEmpty) {
        data['unit'] = int.tryParse(unit) ?? 0;
      }

      final supplierId = _supplierIdController.text.trim();
      if (supplierId.isNotEmpty) {
        data['supplier_id'] = int.tryParse(supplierId);
      }

      // Make API call
      final response = await http.post(
        AppConfig.api('/api/ioproducts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (!mounted) return;

      final result = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (result['status'] == 'success') {
          _showMessage('Product added successfully!', isError: false);
          Navigator.pop(context, true);
          return;
        }
      }
      
      throw Exception(result['message'] ?? 'Failed to add product');

    } catch (e) {
      if (mounted) {
        _showMessage('Error: ${e.toString()}', isError: true);
      }
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
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  // Optimized input decoration
  InputDecoration _inputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: backgroundColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Add Product'),
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader('Basic Information', Icons.inventory_2),
                    const SizedBox(height: 16),

                    // Barcode with scan button
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration: _inputDecoration('Barcode', Icons.qr_code_scanner),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton.filled(
                            onPressed: _isLoading ? null : _scanBarcode,
                            icon: const Icon(Icons.qr_code_scanner, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: buttonTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Product Name (Required)
                    TextFormField(
                      controller: _productNameController,
                      decoration: _inputDecoration('Product Name *', Icons.inventory_2),
                      validator: (value) {
                        if (value?.trim().isEmpty == true) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Product Code
                    TextFormField(
                      controller: _productCodeController,
                      decoration: _inputDecoration('Product Code', Icons.qr_code, hint: 'e.g., PRD-001'),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory.isEmpty ? null : _selectedCategory,
                      decoration: _inputDecoration('Category', Icons.category),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value ?? '');
                      },
                    ),
                    const SizedBox(height: 16),

                    // Brand
                    TextFormField(
                      controller: _brandController,
                      decoration: _inputDecoration('Brand', Icons.branding_watermark),
                    ),
                    const SizedBox(height: 16),

                    // Unit Quantity
                    TextFormField(
                      controller: _unitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration('Unit Quantity', Icons.confirmation_number, hint: 'e.g., 12'),
                    ),
                    const SizedBox(height: 24),

                    // Additional Details Section
                    _buildSectionHeader('Additional Details', Icons.description),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: _inputDecoration('Description', Icons.description, hint: 'Product description...'),
                    ),
                    const SizedBox(height: 16),

                    // Supplier ID
                    TextFormField(
                      controller: _supplierIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration('Supplier ID', Icons.business),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: _inputDecoration('Notes', Icons.note, hint: 'Additional notes...'),
                    ),
                    const SizedBox(height: 80), // Space for button
                  ],
                ),
              ),
            ),

            // Submit Button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: buttonTextColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
      ],
    );
  }
}

// Optimized Barcode Scanner
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late final MobileScannerController _controller;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning || !mounted) return;
    
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode?.isNotEmpty == true) {
      setState(() => _isScanning = false);
      HapticFeedback.mediumImpact();
      Navigator.pop(context, barcode);
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
              valueListenable: _controller.torchState,
              builder: (_, state, __) => Icon(
                state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                color: state == TorchState.on ? Colors.yellow : Colors.white,
              ),
            ),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          
          // Scan area
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
            bottom: 80,
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
                  const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Position barcode within frame',
                    style: TextStyle(color: Colors.white, fontSize: 16),
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
        ],
      ),
    );
  }
}