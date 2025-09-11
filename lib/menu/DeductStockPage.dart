import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:inventory/menu/menu_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../utils/simple_translations.dart';

class DeductStockPage extends StatefulWidget {
  final String? currentTheme;

  const DeductStockPage({super.key, this.currentTheme});

  @override
  State<DeductStockPage> createState() => _DeductStockPageState();
}

class _DeductStockPageState extends State<DeductStockPage> {
  // Core Authentication & Config
  String? _accessToken;
  String _langCode = 'en';
  late final int _companyId;
  String? _userId;
  String? _branchId;
  late Color _primaryColor;

  // Form State
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    'productId': TextEditingController(),
    'productName': TextEditingController(),
    'barcode': TextEditingController(),
    'amount': TextEditingController(text: '0'),
    'price': TextEditingController(text: '0'),
    'batchNumber': TextEditingController(),
    'supplierId': TextEditingController(),
  };

  // Data Collections
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _stores = [];

  // Selected Items
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedLocation;
  Map<String, dynamic>? _selectedStore;
  Map<String, dynamic>? _scannedProduct;
  DateTime? _selectedExpireDate;

  // Form Values
  String _selectedCurrency = 'LAK';
  String _selectedStatus = 'active';

  // Loading States
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingProducts = false;
  bool _isLoadingLocations = false;
  bool _isLoadingStores = false;

  @override
  void initState() {
    super.initState();
    _primaryColor = ThemeConfig.getPrimaryColor(widget.currentTheme ?? 'default');
    _initializeAuth();
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  // INITIALIZATION
  Future<void> _initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _langCode = prefs.getString('languageCode') ?? 'en';
      _companyId = CompanyConfig.getCompanyId();
      _userId = prefs.getString('user');
      _branchId = prefs.getString('branch_id');

      if (_accessToken != null) {
        await Future.wait([
          _loadLocations(),
          _loadStores(),
          if (kIsWeb) _loadProducts(),
        ]);
      } else {
        _showError('Authentication token not found');
      }
    } catch (e) {
      _showError('Failed to initialize: $e');
    }
  }

  // DATA LOADING
  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    
    try {
      final response = await _apiRequest('GET', '/api/ioproduct', queryParams: {
        'company_id': _companyId.toString(),
      });

      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        setState(() {
          _products = (data['data'] as List).map((product) => {
            'product_id': product['product_id'] ?? product['id'],
            'product_name': product['product_name'] ?? product['name'] ?? 'Unknown Product',
            'barcode': product['barcode'] ?? '',
            'price': product['price'] ?? 0,
            'image_url': product['image_url'] ?? '',
            'stock_quantity': product['stock_quantity'] ?? 0,
            'category': product['category'] ?? '',
          }).toList();
        });
      }
    } catch (e) {
      _showError('Error loading products: $e');
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    
    try {
      final response = await _apiRequest('GET', '/api/iolocation', queryParams: {
        'status': 'admin',
        'company_id': _companyId.toString(),
      });

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => _locations = List<Map<String, dynamic>>.from(data['data'] ?? []));
      }
    } catch (e) {
      _showError('Error loading locations: $e');
    } finally {
      setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _loadStores() async {
    setState(() => _isLoadingStores = true);
    
    try {
      final response = await _apiRequest('GET', '/api/iostore', queryParams: {
        'status': 'admin',
        'company_id': _companyId.toString(),
      });

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => _stores = List<Map<String, dynamic>>.from(data['data'] ?? []));
      }
    } catch (e) {
      _showError('Error loading stores: $e');
    } finally {
      setState(() => _isLoadingStores = false);
    }
  }

  // PRODUCT OPERATIONS
  void _onProductSelected(Map<String, dynamic> product) {
    setState(() {
      _selectedProduct = product;
      _controllers['productId']!.text = product['product_id'].toString();
      _controllers['productName']!.text = product['product_name'] ?? '';
      _controllers['barcode']!.text = product['barcode'] ?? '';
      if (product['price'] != null && product['price'] > 0) {
        _controllers['price']!.text = product['price'].toString();
      }
    });
    _showSuccess('Selected: ${product['product_name']}');
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerPage(
          langCode: _langCode,
          primaryColor: _primaryColor,
        ),
      ),
    );

    if (result != null) {
      await _lookupProductByBarcode(result);
    }
  }

  Future<void> _lookupProductByBarcode(String barcode) async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiRequest('GET', '/api/ioproduct/barcode/$barcode', queryParams: {
        'company_id': _companyId.toString(),
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final product = data['data'];
        setState(() {
          _scannedProduct = product;
          _controllers['barcode']!.text = product['barcode'] ?? '';
          _controllers['productId']!.text = product['product_id'].toString();
          _controllers['productName']!.text = product['product_name'] ?? '';
        });
        _showSuccess('Product found successfully');
      } else {
        _showError('Product not found');
      }
    } catch (e) {
      _showError('Error looking up product: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // FORM OPERATIONS
  Future<void> _deductInventory() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      final body = {
        'product_id': int.parse(_controllers['productId']!.text),
        'product_name': _controllers['productName']!.text.trim(),
        'location_id': _selectedLocation!['location_id'],
        'location': _selectedLocation!['location'] ?? _selectedLocation!['location_name'],
        'currency_primary': _selectedCurrency,
        'amount': -int.parse(_controllers['amount']!.text), // Negative for deduction
        'price': double.parse(_controllers['price']!.text),
        'status': _selectedStatus,
        'store_id': _selectedStore!['store_id'],
        'store_name': _selectedStore!['store_name'] ?? _selectedStore!['name'],
        'user_id': _userId,
        'branch_id': _branchId != null ? int.tryParse(_branchId!) : null,
        'txntype': 'STOCK_OUT',
        'company_id': _companyId,
        if (_controllers['barcode']!.text.trim().isNotEmpty)
          'barcode': _controllers['barcode']!.text.trim(),
        if (_controllers['batchNumber']!.text.trim().isNotEmpty)
          'batch_number': _controllers['batchNumber']!.text.trim(),
        if (_controllers['supplierId']!.text.trim().isNotEmpty)
          'supplier_id': int.tryParse(_controllers['supplierId']!.text),
        if (_selectedExpireDate != null)
          'expire_date': _selectedExpireDate!.toIso8601String().split('T')[0],
      };

      final response = await _apiRequest('POST', '/api/inventory', body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccess('Stock deducted successfully');
        _clearForm();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MenuPage(role: 'user', tabIndex: 1),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        _showError(data['message'] ?? 'Failed to deduct stock');
      }
    } catch (e) {
      _showError('Error deducting stock: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill required fields');
      return false;
    }
    if (_selectedLocation == null) {
      _showError('Please select location');
      return false;
    }
    if (_selectedStore == null) {
      _showError('Please select store');
      return false;
    }
    return true;
  }

  void _clearForm() {
    _controllers.values.forEach((controller) => controller.clear());
    setState(() {
      _selectedExpireDate = null;
      _selectedLocation = null;
      _selectedStore = null;
      _selectedProduct = null;
      _scannedProduct = null;
      _selectedCurrency = 'LAK';
      _selectedStatus = 'active';
    });
  }

  // API HELPER
  Future<http.Response> _apiRequest(String method, String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = AppConfig.api(endpoint).replace(queryParameters: queryParams);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers, body: jsonEncode(body));
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  // UI HELPERS
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // BUILD METHODS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deduct Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.orange),
                const SizedBox(height: 16),
                Text('Loading data...', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        : Column(
            children: [
              if (kIsWeb) _buildWebProductSelector(),
              if (_scannedProduct != null) _buildScannedProductInfo(),
              Expanded(child: _buildForm()),
            ],
          ),
    );
  }

  Widget _buildWebProductSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.remove_circle, color: Colors.orange, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Select Product to Deduct',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoadingProducts
                  ? _buildLoadingIndicator('Loading products...')
                  : _products.isEmpty
                    ? _buildEmptyState()
                    : _buildProductDropdown(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _loadProducts,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_products.length} products available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.orange)),
          ),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('No products loaded'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadProducts,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Load Products'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Map<String, dynamic>>(
        value: _selectedProduct != null && _products.any((p) => p['product_id'] == _selectedProduct!['product_id']) 
            ? _selectedProduct : null,
        hint: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select a product'),
        ),
        isExpanded: true,
        items: _products.map((product) => DropdownMenuItem<Map<String, dynamic>>(
          value: product,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildProductImage(product['image_url']),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['product_name'] ?? 'Unknown Product',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // if (product['barcode']?.toString().isNotEmpty == true)
                      //   Text(
                      //     'Barcode: ${product['barcode']}',
                      //     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      //     overflow: TextOverflow.ellipsis,
                      //   ),
                      // if (product['category']?.toString().isNotEmpty == true)
                      //   Text(
                      //     product['category'],
                      //     style: TextStyle(fontSize: 12, color: Colors.blue[600], fontWeight: FontWeight.w500),
                      //     overflow: TextOverflow.ellipsis,
                      //   ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // if (product['price'] != null)
                    //   Text(
                    //     '\$${product['price']}',
                    //     style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                    //   ),
                    if (product['stock_quantity'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: product['stock_quantity'] > 0 
                              ? Colors.green.withOpacity(0.1) 
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Stock: ${product['stock_quantity']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: product['stock_quantity'] > 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        )).toList(),
        onChanged: (value) {
          if (value != null) _onProductSelected(value);
        },
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[100],
                child: Icon(Icons.remove_shopping_cart, color: Colors.grey[400], size: 20),
              ),
            ),
          )
        : Container(
            color: Colors.grey[100],
            child: Icon(Icons.remove_shopping_cart, color: Colors.grey[400], size: 20),
          ),
    );
  }

  Widget _buildScannedProductInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[300]!),
              color: Colors.orange[100],
            ),
            child: Icon(Icons.remove_shopping_cart, color: Colors.orange[600], size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.remove_circle, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Scanned Product',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Product: ${_scannedProduct!['product_name'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  'ID: ${_scannedProduct!['product_id']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                if (_scannedProduct!['barcode'] != null)
                  Text(
                    'Barcode: ${_scannedProduct!['barcode']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[600]),
            onPressed: () {
              setState(() {
                _scannedProduct = null;
                _controllers['productId']!.clear();
                _controllers['productName']!.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deduct Stock Item', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Barcode section
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _controllers['barcode']!,
                    label: 'Barcode *',
                    required: true,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                      onPressed: _scanBarcode,
                      tooltip: 'Scan Barcode',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _controllers['productId']!, 
              label: 'Product ID', 
              keyboardType: TextInputType.number, 
              required: true
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _controllers['productName']!, 
              label: 'Product Name', 
              required: true
            ),
            const SizedBox(height: 16),
            
            _buildDropdownField(
              value: _selectedLocation,
              label: 'Location',
              items: _locations,
              isLoading: _isLoadingLocations,
              onChanged: (value) => setState(() => _selectedLocation = value),
              itemBuilder: (item) => Text(
                item['location'] ?? item['location_name'] ?? 'Unknown',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildDropdownField(
              value: _selectedStore,
              label: 'Store',
              items: _stores,
              isLoading: _isLoadingStores,
              onChanged: (value) => setState(() => _selectedStore = value),
              itemBuilder: (item) => Text(
                item['store_name'] ?? item['name'] ?? 'Unknown Store',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _controllers['amount']!, 
              label: 'Deduct Amount', 
              keyboardType: TextInputType.number, 
              required: true
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _controllers['price']!, 
              label: 'Price', 
              keyboardType: const TextInputType.numberWithOptions(decimal: true), 
              required: true
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _controllers['batchNumber']!, 
              label: 'Batch Number (Optional)'
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _controllers['supplierId']!, 
              label: 'Supplier ID (Optional)', 
              keyboardType: TextInputType.number
            ),
            const SizedBox(height: 16),
            
            _buildDatePicker(),
            const SizedBox(height: 16),
            
            _buildStatusDropdown(),
            const SizedBox(height: 32),
            
            _buildSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: required ? (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      } : null,
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required List<T> items,
    required bool isLoading,
    required ValueChanged<T?> onChanged,
    required Widget Function(T) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isLoading
            ? _buildLoadingIndicator('Loading $label...')
            : DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Text('Select $label')
                  ),
                  isExpanded: true,
                  items: items.map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: itemBuilder(item),
                    ),
                  )).toList(),
                  onChanged: onChanged,
                ),
              ),
        ),
        if (value == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8, bottom: 4),
            child: Text('$label is required', style: TextStyle(color: Colors.red[700], fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Expire Date (Optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedExpireDate ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (date != null) setState(() => _selectedExpireDate = date);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedExpireDate != null
                    ? '${_selectedExpireDate!.day}/${_selectedExpireDate!.month}/${_selectedExpireDate!.year}'
                    : 'Select expire date',
                  style: TextStyle(color: _selectedExpireDate != null ? Colors.black : Colors.grey[600]),
                ),
                Icon(Icons.calendar_today, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Currency', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: ['LAK', 'THB', 'USD']
                        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCurrency = value!),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: ['active', 'inactive']
                        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedStatus = value!),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _deductInventory,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSubmitting ? Colors.grey : Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: _isSubmitting ? 0 : 2,
        ),
        child: _isSubmitting
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Deducting stock...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.remove_shopping_cart, size: 24),
                const SizedBox(width: 8),
                const Text('Deduct Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
      ),
    );
  }
}

// Barcode Scanner Page
class BarcodeScannerPage extends StatefulWidget {
  final String langCode;
  final Color primaryColor;

  const BarcodeScannerPage({
    super.key,
    required this.langCode,
    required this.primaryColor,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late MobileScannerController _controller;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned || !mounted) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    setState(() => _isScanned = true);

    if (Platform.isAndroid || Platform.isIOS) {
      HapticFeedback.lightImpact();
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, barcodes.first.rawValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Camera Error',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          
          // Scanning overlay
          CustomPaint(
            painter: ScannerOverlay(
              scanAreaSize: 250,
              borderColor: _isScanned ? Colors.green : widget.primaryColor,
              borderWidth: 3,
            ),
            child: const SizedBox.expand(),
          ),

          // Success indicator
          if (_isScanned)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Barcode Detected',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom instructions
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
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, size: 48, color: widget.primaryColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Position the barcode within the scanning area',
                    style: TextStyle(
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
                      child: const Text('Cancel', style: TextStyle(fontSize: 16)),
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

// Scanner Overlay Painter
class ScannerOverlay extends CustomPainter {
  final double scanAreaSize;
  final Color borderColor;
  final double borderWidth;

  const ScannerOverlay({
    required this.scanAreaSize,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scanAreaPath = Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: scanAreaSize,
            height: scanAreaSize,
          ),
          const Radius.circular(12),
        ),
      );

    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, scanAreaPath);
    canvas.drawPath(overlayPath, Paint()..color = Colors.black.withOpacity(0.5));

    _drawCornerBrackets(canvas, size);
  }

  void _drawCornerBrackets(Canvas canvas, Size size) {
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
    
    // Draw corner brackets
    _drawCorner(canvas, paint, scanRect.topLeft, cornerLength, true, true);
    _drawCorner(canvas, paint, scanRect.topRight, cornerLength, false, true);
    _drawCorner(canvas, paint, scanRect.bottomLeft, cornerLength, true, false);
    _drawCorner(canvas, paint, scanRect.bottomRight, cornerLength, false, false);
  }

  void _drawCorner(Canvas canvas, Paint paint, Offset corner, double length, 
                  bool isLeft, bool isTop) {
    final horizontalStart = isLeft ? corner : Offset(corner.dx - length, corner.dy);
    final horizontalEnd = isLeft ? Offset(corner.dx + length, corner.dy) : corner;
    
    final verticalStart = isTop ? corner : Offset(corner.dx, corner.dy - length);
    final verticalEnd = isTop ? Offset(corner.dx, corner.dy + length) : corner;

    canvas.drawLine(horizontalStart, horizontalEnd, paint);
    canvas.drawLine(verticalStart, verticalEnd, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}