import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import '../utils/simple_translations.dart';
import 'dart:convert';

class AddStockPage extends StatefulWidget {
  final String? currentTheme;
  
  const AddStockPage({Key? key, this.currentTheme}) : super(key: key);

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  String? accessToken;
  String langCode = 'en';
  int? companyId;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _productIdController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockQuantityController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _reservedQuantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _supplierIdController = TextEditingController();
  final _blockLocationController = TextEditingController();
  final _reasonController = TextEditingController();
  
  // State management
  bool isLoading = false;
  bool isSubmitting = false;
  bool isCreateMode = true;
  bool isScanning = false;
  bool isLoadingLocations = false;
  List<Map<String, dynamic>> existingInventory = [];
  List<Map<String, dynamic>> locations = [];
  Map<String, dynamic>? selectedInventoryItem;
  Map<String, dynamic>? scannedProduct;
  Map<String, dynamic>? selectedLocation;
  
  // Dropdown values
  String selectedCurrency = 'LAK';
  String selectedStatus = 'ACTIVE';
  DateTime? selectedExpireDate;
  
  // Cache primary color for performance
  late Color primaryColor;

  @override
  void initState() {
    super.initState();
    primaryColor = ThemeConfig.getPrimaryColor(widget.currentTheme ?? 'default');
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    langCode = prefs.getString('languageCode') ?? 'en';
    companyId = prefs.getInt('company_id') ?? 1;
    
    if (accessToken != null) {
      await _loadLocations();
      await _loadExistingInventory();
    } else {
      _showErrorSnackBar(SimpleTranslations.get(langCode, 'auth_token_not_found'));
    }
  }

  Future<void> _loadLocations() async {
    if (accessToken == null || companyId == null) return;
    
    setState(() => isLoadingLocations = true);

    try {
      final response = await http.get(
        AppConfig.api('/api/iolocation?status=admin&company_id=$companyId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('📍 DEBUG: Locations API Response: ${response.statusCode}');
      print('📍 DEBUG: Locations API Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            locations = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
          print('📍 DEBUG: Loaded ${locations.length} locations');
        } else {
          _showErrorSnackBar('Failed to load locations: ${data['message']}');
        }
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        _showErrorSnackBar('Failed to load locations: Server error ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error loading locations: $e');
      _showErrorSnackBar('Error loading locations: $e');
    } finally {
      setState(() => isLoadingLocations = false);
    }
  }

  Future<void> _scanBarcode() async {
    // Navigate to barcode scanner
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerPage(
          langCode: langCode,
          primaryColor: primaryColor,
        ),
      ),
    );

    if (result != null && result is String) {
      await _lookupProductByBarcode(result);
    }
  }

  Future<void> _lookupProductByBarcode(String barcode) async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        AppConfig.api('/api/ioproduct/barcode/$barcode'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('🔍 DEBUG: Barcode API Response: ${response.statusCode}');
      print('🔍 DEBUG: Barcode API Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            scannedProduct = data['data'];
            _barcodeController.text = scannedProduct!['barcode'] ?? '';
            _productIdController.text = scannedProduct!['product_id'].toString();
          });
          print('✅ DEBUG: Product found: ${scannedProduct!['product_name']}');
          _showSuccessSnackBar(SimpleTranslations.get(langCode, 'product_found_success'));
        } else {
          _showErrorSnackBar('Product not found: ${data['message']}');
        }
      } else if (response.statusCode == 404) {
        _showErrorSnackBar(SimpleTranslations.get(langCode, 'product_not_found'));
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        _showErrorSnackBar(SimpleTranslations.get(langCode, 'failed_to_lookup_product'));
      }
    } catch (e) {
      print('❌ DEBUG: Error looking up product: $e');
      _showErrorSnackBar('${SimpleTranslations.get(langCode, 'error_looking_up_product')}: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadExistingInventory() async {
    if (accessToken == null) return;
    
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        AppConfig.api('/api/inventory'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          existingInventory = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else if (response.statusCode == 401) {
        _handleAuthError();
      }
    } catch (e) {
      _showErrorSnackBar('${SimpleTranslations.get(langCode, 'failed_to_load_inventory')}: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _createNewInventory() async {
    if (!_formKey.currentState!.validate() || accessToken == null) return;

    if (selectedLocation == null) {
      _showErrorSnackBar('Please select a location');
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final requestBody = {
        'barcode': _barcodeController.text.trim().isNotEmpty ? _barcodeController.text.trim() : null,
        'product_id': int.parse(_productIdController.text),
        'location_id': selectedLocation!['location_id'],
        'stock_quantity': int.parse(_stockQuantityController.text),
        'minimum_stock': int.parse(_minimumStockController.text),
        'reserved_quantity': int.parse(_reservedQuantityController.text.isEmpty ? '0' : _reservedQuantityController.text),
        'cost_price_lak': double.parse(_costPriceController.text),
        'unit_price_lak': double.parse(_unitPriceController.text),
        'currency_primary': selectedCurrency,
        'batch_number': _batchNumberController.text.isEmpty ? null : _batchNumberController.text,
        'supplier_id': _supplierIdController.text.isEmpty ? null : int.tryParse(_supplierIdController.text),
        'expire_date': selectedExpireDate?.toIso8601String().split('T')[0],
        'block_location': _blockLocationController.text.isEmpty ? null : _blockLocationController.text,
        'status': selectedStatus,
      };

      final response = await http.post(
        AppConfig.api('/api/inventory'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessSnackBar(SimpleTranslations.get(langCode, 'inventory_created_success'));
        _clearForm();
        Navigator.pop(context, true);
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        final errorData = json.decode(response.body);
        _showErrorSnackBar('${SimpleTranslations.get(langCode, 'failed_to_create_inventory')}: ${errorData['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('${SimpleTranslations.get(langCode, 'error_creating_inventory')}: $e');
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<void> _addStockToExisting() async {
    if (selectedInventoryItem == null || _stockQuantityController.text.isEmpty || _reasonController.text.isEmpty || accessToken == null) {
      _showErrorSnackBar(SimpleTranslations.get(langCode, 'fill_all_required_fields'));
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final requestBody = {
        'stock_in_quantity': int.parse(_stockQuantityController.text),
        'reason': _reasonController.text,
      };

      final response = await http.put(
        AppConfig.api('/api/inventory/${selectedInventoryItem!['inventory_id']}/stock-movement'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar(SimpleTranslations.get(langCode, 'stock_added_success'));
        _clearForm();
        Navigator.pop(context, true);
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        final errorData = json.decode(response.body);
        _showErrorSnackBar('${SimpleTranslations.get(langCode, 'failed_to_add_stock')}: ${errorData['message']}');
      }
    } catch (e) {
      _showErrorSnackBar('${SimpleTranslations.get(langCode, 'error_adding_stock')}: $e');
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _handleAuthError() {
    _showErrorSnackBar(SimpleTranslations.get(langCode, 'session_expired'));
  }

  void _clearForm() {
    _barcodeController.clear();
    _productIdController.clear();
    _stockQuantityController.clear();
    _minimumStockController.clear();
    _reservedQuantityController.clear();
    _costPriceController.clear();
    _unitPriceController.clear();
    _batchNumberController.clear();
    _supplierIdController.clear();
    _blockLocationController.clear();
    _reasonController.clear();
    setState(() {
      selectedExpireDate = null;
      selectedInventoryItem = null;
      selectedLocation = null;
      selectedCurrency = 'LAK';
      selectedStatus = 'ACTIVE';
      scannedProduct = null;
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _productIdController.dispose();
    _stockQuantityController.dispose();
    _minimumStockController.dispose();
    _reservedQuantityController.dispose();
    _costPriceController.dispose();
    _unitPriceController.dispose();
    _batchNumberController.dispose();
    _supplierIdController.dispose();
    _blockLocationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCode, 'add_stock'), 
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
            tooltip: SimpleTranslations.get(langCode, 'scan_barcode'),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Scanned Product Info
                if (scannedProduct != null) ...[
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        // Product Image
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: scannedProduct!['image_url'] != null && scannedProduct!['image_url'].toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.network(
                                    scannedProduct!['image_url'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.green[100],
                                        child: Icon(
                                          Icons.inventory,
                                          color: Colors.green[600],
                                          size: 24,
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.green[100],
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  color: Colors.green[100],
                                  child: Icon(
                                    Icons.inventory,
                                    color: Colors.green[600],
                                    size: 24,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    SimpleTranslations.get(langCode, 'scanned_product'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${SimpleTranslations.get(langCode, 'product_name')}: ${scannedProduct!['product_name'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${SimpleTranslations.get(langCode, 'product_id')}: ${scannedProduct!['product_id']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              if (scannedProduct!['barcode'] != null)
                                Text(
                                  'Barcode: ${scannedProduct!['barcode']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                          onPressed: () {
                            setState(() {
                              scannedProduct = null;
                              _productIdController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Mode Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _ModeButton(
                        isSelected: isCreateMode,
                        onTap: () => setState(() => isCreateMode = true),
                        icon: Icons.add_box,
                        text: SimpleTranslations.get(langCode, 'create_new'),
                        color: primaryColor,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _ModeButton(
                        isSelected: !isCreateMode,
                        onTap: () => setState(() => isCreateMode = false),
                        icon: Icons.add_circle,
                        text: SimpleTranslations.get(langCode, 'add_to_existing'),
                        color: primaryColor,
                      )),
                    ],
                  ),
                ),
                
                // Form Content
                Expanded(
                  child: isCreateMode ? _buildCreateForm() : _buildAddForm(),
                ),
              ],
            ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SimpleTranslations.get(langCode, 'create_new_inventory_item'), 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 20),
            
            // Barcode Scanner (Primary)
            Row(
              children: [
                Expanded(
                  child: _FastTextField(
                    controller: _barcodeController,
                    label: 'Barcode *',
                    keyboardType: TextInputType.text,
                    required: true,
                    langCode: langCode,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    onPressed: _scanBarcode,
                    tooltip: SimpleTranslations.get(langCode, 'scan_barcode'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Product ID (Auto-populated from barcode scan)
            _FastTextField(
              controller: _productIdController,
              label: SimpleTranslations.get(langCode, 'product_id'),
              keyboardType: TextInputType.number,
              required: true,
              langCode: langCode,
            ),
            const SizedBox(height: 16),
            
            // Location Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${SimpleTranslations.get(langCode, 'location')} *',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: isLoadingLocations
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text('Loading locations...'),
                            ],
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            value: selectedLocation,
                            hint: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('Select location'),
                            ),
                            isExpanded: true,
                            items: locations.map((location) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: location,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      // Location Image
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey[300]!),
                                        ),
                                        child: location['image_url'] != null && location['image_url'].toString().isNotEmpty
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(5),
                                                child: Image.network(
                                                  location['image_url'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[100],
                                                      child: Icon(
                                                        Icons.location_on,
                                                        color: Colors.grey[400],
                                                        size: 16,
                                                      ),
                                                    );
                                                  },
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Container(
                                                      color: Colors.grey[100],
                                                      child: Center(
                                                        child: SizedBox(
                                                          width: 12,
                                                          height: 12,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 1.5,
                                                            value: loadingProgress.expectedTotalBytes != null
                                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              )
                                            : Container(
                                                color: Colors.grey[100],
                                                child: Icon(
                                                  Icons.location_on,
                                                  color: Colors.grey[400],
                                                  size: 16,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Location Name and ID
                                      Expanded(
                                        child: Text(
                                          location['location'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => selectedLocation = value),
                          ),
                        ),
                ),
                if (selectedLocation == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: Text(
                      'Location is required',
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stock Quantities
            Row(
              children: [
                Expanded(child: _FastTextField(
                  controller: _stockQuantityController,
                  label: SimpleTranslations.get(langCode, 'stock_quantity'),
                  keyboardType: TextInputType.number,
                  required: true,
                  langCode: langCode,
                )),
                const SizedBox(width: 16),
                Expanded(child: _FastTextField(
                  controller: _minimumStockController,
                  label: SimpleTranslations.get(langCode, 'minimum_stock'),
                  keyboardType: TextInputType.number,
                  required: true,
                  langCode: langCode,
                )),
              ],
            ),
            const SizedBox(height: 16),
            
            // Prices
            Row(
              children: [
                Expanded(child: _FastTextField(
                  controller: _costPriceController,
                  label: SimpleTranslations.get(langCode, 'cost_price_lak'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  required: true,
                  langCode: langCode,
                )),
                const SizedBox(width: 16),
                Expanded(child: _FastTextField(
                  controller: _unitPriceController,
                  label: SimpleTranslations.get(langCode, 'unit_price_lak'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  required: true,
                  langCode: langCode,
                )),
              ],
            ),
            const SizedBox(height: 16),
            
            // Optional fields
            _FastTextField(
              controller: _reservedQuantityController,
              label: SimpleTranslations.get(langCode, 'reserved_quantity_optional'),
              keyboardType: TextInputType.number,
              langCode: langCode,
            ),
            const SizedBox(height: 16),
            
            _FastTextField(
              controller: _batchNumberController,
              label: SimpleTranslations.get(langCode, 'batch_number_optional'),
              langCode: langCode,
            ),
            const SizedBox(height: 16),
            
            // Dropdowns
            Row(
              children: [
                Expanded(child: _FastDropdown(
                  value: selectedCurrency,
                  label: SimpleTranslations.get(langCode, 'currency'),
                  items: const ['LAK', 'THB'],
                  onChanged: (value) => setState(() => selectedCurrency = value!),
                )),
                const SizedBox(width: 16),
                Expanded(child: _FastDropdown(
                  value: selectedStatus,
                  label: SimpleTranslations.get(langCode, 'status'),
                  items: const ['ACTIVE', 'INACTIVE', 'RESERVED'],
                  onChanged: (value) => setState(() => selectedStatus = value!),
                )),
              ],
            ),
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _createNewInventory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : Text(
                        SimpleTranslations.get(langCode, 'create_inventory_item'), 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SimpleTranslations.get(langCode, 'add_stock_to_existing_item'), 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),
          
          // Inventory Selector
          Text(
            SimpleTranslations.get(langCode, 'select_inventory_item'), 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
          ),
          const SizedBox(height: 8),
          
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: selectedInventoryItem,
                hint: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(SimpleTranslations.get(langCode, 'select_inventory_item_hint')),
                ),
                isExpanded: true,
                items: existingInventory.map((item) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: item,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('${SimpleTranslations.get(langCode, 'product')} ${item['product_id']} - ${SimpleTranslations.get(langCode, 'location')} ${item['location_id']} (${SimpleTranslations.get(langCode, 'stock')}: ${item['stock_quantity']})'),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedInventoryItem = value),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Selected Item Details
          if (selectedInventoryItem != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SimpleTranslations.get(langCode, 'selected_item_details'), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  const SizedBox(height: 8),
                  Text('${SimpleTranslations.get(langCode, 'product_id')}: ${selectedInventoryItem!['product_id']}'),
                  Text('${SimpleTranslations.get(langCode, 'location_id')}: ${selectedInventoryItem!['location_id']}'),
                  Text('${SimpleTranslations.get(langCode, 'current_stock')}: ${selectedInventoryItem!['stock_quantity']}'),
                  Text('${SimpleTranslations.get(langCode, 'available')}: ${selectedInventoryItem!['available_quantity']}'),
                  Text('${SimpleTranslations.get(langCode, 'status')}: ${selectedInventoryItem!['status']}'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Quantity and Reason
          _FastTextField(
            controller: _stockQuantityController,
            label: SimpleTranslations.get(langCode, 'quantity_to_add'),
            keyboardType: TextInputType.number,
            required: true,
            langCode: langCode,
          ),
          const SizedBox(height: 16),
          
          _FastTextField(
            controller: _reasonController,
            label: SimpleTranslations.get(langCode, 'reason_for_stock_addition'),
            maxLines: 3,
            required: true,
            langCode: langCode,
          ),
          const SizedBox(height: 32),
          
          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : _addStockToExisting,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : Text(
                      SimpleTranslations.get(langCode, 'add_stock'), 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Barcode Scanner Page
class BarcodeScannerPage extends StatefulWidget {
  final String langCode;
  final Color primaryColor;

  const BarcodeScannerPage({
    Key? key,
    required this.langCode,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> with WidgetsBindingObserver {
  late MobileScannerController cameraController;
  bool isScanned = false;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  void _initializeCamera() {
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    
    // Add a small delay to ensure camera is properly initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          isInitialized = true;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check if controller is available instead of using value.isInitialized
    if (!isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        cameraController.stop();
        break;
      case AppLifecycleState.resumed:
        cameraController.start();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!isScanned && mounted) {
      final List<Barcode> barcodes = capture.barcodes;
      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
        setState(() {
          isScanned = true;
        });
        
        // Add haptic feedback
        if (Platform.isAndroid || Platform.isIOS) {
          HapticFeedback.lightImpact();
        }
        
        // Small delay to show visual feedback before closing
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pop(context, barcodes.first.rawValue);
          }
        });
      }
    }
  }

  void _toggleFlash() async {
    try {
      await cameraController.toggleTorch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SimpleTranslations.get(widget.langCode, 'flash_error')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _switchCamera() async {
    try {
      await cameraController.switchCamera();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SimpleTranslations.get(widget.langCode, 'camera_switch_error')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(widget.langCode, 'scan_barcode'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isInitialized) ...[
            IconButton(
              icon: ValueListenableBuilder(
                valueListenable: cameraController.torchState,
                builder: (context, state, child) {
                  switch (state) {
                    case TorchState.off:
                      return const Icon(Icons.flash_off);
                    case TorchState.on:
                      return const Icon(Icons.flash_on, color: Colors.yellow);
                    // ignore: unreachable_switch_default
                    default:
                      return const Icon(Icons.flash_off, color: Colors.grey);
                  }
                },
              ),
              onPressed: _toggleFlash,
              tooltip: SimpleTranslations.get(widget.langCode, 'flash'),
            ),
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: _switchCamera,
              tooltip: SimpleTranslations.get(widget.langCode, 'switch_camera'),
            ),
          ],
        ],
      ),
      body: !isInitialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: widget.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    SimpleTranslations.get(widget.langCode, 'initializing_camera'),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Camera View
                MobileScanner(
                  controller: cameraController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              SimpleTranslations.get(widget.langCode, 'camera_error'),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(SimpleTranslations.get(widget.langCode, 'close')),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Scanner Overlay
                CustomPaint(
                  painter: ScannerOverlay(
                    scanAreaSize: 250,
                    borderColor: isScanned ? Colors.green : widget.primaryColor,
                    borderWidth: 3,
                  ),
                  child: const SizedBox.expand(),
                ),
                
                // Success Indicator
                if (isScanned)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            SimpleTranslations.get(widget.langCode, 'barcode_detected'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Bottom Instructions
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 48,
                          color: widget.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          SimpleTranslations.get(widget.langCode, 'scan_instruction'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              SimpleTranslations.get(widget.langCode, 'cancel'),
                              style: const TextStyle(fontSize: 16),
                            ),
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

// Custom Scanner Overlay Painter
class ScannerOverlay extends CustomPainter {
  final double scanAreaSize;
  final Color borderColor;
  final double borderWidth;

  ScannerOverlay({
    required this.scanAreaSize,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final scanAreaPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: scanAreaSize,
          height: scanAreaSize,
        ),
        const Radius.circular(12),
      ));

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanAreaPath,
    );

    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5);
    
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw corner brackets
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    const cornerLength = 20.0;
    
    // Top-left corner
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top + cornerLength),
      Offset(scanRect.left, scanRect.top),
      paint,
    );
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top),
      Offset(scanRect.left + cornerLength, scanRect.top),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanRect.right - cornerLength, scanRect.top),
      Offset(scanRect.right, scanRect.top),
      paint,
    );
    canvas.drawLine(
      Offset(scanRect.right, scanRect.top),
      Offset(scanRect.right, scanRect.top + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom - cornerLength),
      Offset(scanRect.left, scanRect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom),
      Offset(scanRect.left + cornerLength, scanRect.bottom),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanRect.right - cornerLength, scanRect.bottom),
      Offset(scanRect.right, scanRect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(scanRect.right, scanRect.bottom - cornerLength),
      Offset(scanRect.right, scanRect.bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Fast, optimized custom widgets
class _ModeButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String text;
  final Color color;

  const _ModeButton({
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[600], size: 20),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FastTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool required;
  final int maxLines;
  final String langCode;

  const _FastTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.required = false,
    this.maxLines = 1,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : keyboardType == const TextInputType.numberWithOptions(decimal: true)
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
              : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return SimpleTranslations.get(langCode, 'field_required');
              }
              if (keyboardType == TextInputType.number && int.tryParse(value) == null) {
                return SimpleTranslations.get(langCode, 'enter_valid_number');
              }
              if (keyboardType == const TextInputType.numberWithOptions(decimal: true) && double.tryParse(value) == null) {
                return SimpleTranslations.get(langCode, 'enter_valid_price');
              }
              return null;
            }
          : null,
    );
  }
}

class _FastDropdown extends StatelessWidget {
  final String value;
  final String label;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FastDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}