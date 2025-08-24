import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class ProductEditPage extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductEditPage({Key? key, required this.productData}) : super(key: key);

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _productNameController;
  late final TextEditingController _productCodeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _supplierIdController;
  late final TextEditingController _notesController;
  late final TextEditingController _unitController;

  String _selectedStatus = 'active';
  String? _base64Image;
  String? _currentImageUrl;
  File? _imageFile;
  bool _isLoading = false;
  bool _isDeleting = false;
  String currentTheme = ThemeConfig.defaultTheme;

  final List<String> _statusOptions = ['active', 'inactive', 'pending', 'deleted'];

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _initializeControllers();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    _productNameController = TextEditingController(text: widget.productData['product_name'] ?? '');
    _productCodeController = TextEditingController(text: widget.productData['product_code'] ?? '');
    _descriptionController = TextEditingController(text: widget.productData['description'] ?? '');
    _categoryController = TextEditingController(text: widget.productData['category'] ?? '');
    _brandController = TextEditingController(text: widget.productData['brand'] ?? '');
    _barcodeController = TextEditingController(text: widget.productData['barcode'] ?? '');
    _supplierIdController = TextEditingController(text: widget.productData['supplier_id']?.toString() ?? '');
    _notesController = TextEditingController(text: widget.productData['notes'] ?? '');
    _unitController = TextEditingController(text: widget.productData['unit']?.toString() ?? '');
    
    _selectedStatus = widget.productData['status'] ?? 'active';
    _currentImageUrl = widget.productData['image_url'];
    
    print('🔧 DEBUG: Initialized edit form with product: ${widget.productData['product_name']}');
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productCodeController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _supplierIdController.dispose();
    _notesController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        
        setState(() {
          _imageFile = imageFile;
          _base64Image = 'data:image/jpeg;base64,$base64String';
        });

        print('📷 DEBUG: New image selected for product update');
      }
    } catch (e) {
      print('❌ DEBUG: Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final productId = widget.productData['product_id'];

      final url = AppConfig.api('/api/ioproduct/$productId');
      print('🌐 DEBUG: Updating product at: $url');

      final productData = <String, dynamic>{};
      
      // Only include fields that have values
      if (_productNameController.text.trim().isNotEmpty) {
        productData['product_name'] = _productNameController.text.trim();
      }
      if (_productCodeController.text.trim().isNotEmpty) {
        productData['product_code'] = _productCodeController.text.trim();
      }
      if (_descriptionController.text.trim().isNotEmpty) {
        productData['description'] = _descriptionController.text.trim();
      }
      if (_categoryController.text.trim().isNotEmpty) {
        productData['category'] = _categoryController.text.trim();
      }
      if (_brandController.text.trim().isNotEmpty) {
        productData['brand'] = _brandController.text.trim();
      }
      if (_barcodeController.text.trim().isNotEmpty) {
        productData['barcode'] = _barcodeController.text.trim();
      }
      if (_supplierIdController.text.trim().isNotEmpty) {
        productData['supplier_id'] = int.tryParse(_supplierIdController.text.trim());
      }
      if (_notesController.text.trim().isNotEmpty) {
        productData['notes'] = _notesController.text.trim();
      }
      if (_unitController.text.trim().isNotEmpty) {
        productData['unit'] = int.tryParse(_unitController.text.trim());
      }
      
      productData['status'] = _selectedStatus;
      
      if (_base64Image != null) {
        productData['image_url'] = _base64Image;
      }

      print('📝 DEBUG: Update data: ${productData.toString()}');

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(productData),
      );

      print('📡 DEBUG: Update Response Status: ${response.statusCode}');
      print('📝 DEBUG: Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error updating product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct() async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Product'),
          content: Text('Are you sure you want to delete "${_productNameController.text}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final productId = widget.productData['product_id'];

      final url = AppConfig.api('/api/ioproduct/$productId');
      print('🗑️ DEBUG: Deleting product at: $url');

      final response = await http.delete(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📡 DEBUG: Delete Response Status: ${response.statusCode}');
      print('📝 DEBUG: Delete Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product deleted successfully!'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context, 'deleted'); // Return 'deleted' to indicate deletion
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error deleting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Product Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _currentImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildImagePlaceholder();
                              },
                            ),
                          )
                        : _buildImagePlaceholder(),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap to change image',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image,
          size: 40,
          color: Colors.grey[600],
        ),
        SizedBox(height: 8),
        Text(
          'No image',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Product'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _deleteProduct,
            icon: _isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeConfig.getButtonTextColor(currentTheme),
                      ),
                    ),
                  )
                : Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Product',
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ThemeConfig.getButtonTextColor(currentTheme),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image Section
              _buildImageSection(),
              
              SizedBox(height: 16),

              // Basic Information
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _productNameController,
                        decoration: InputDecoration(
                          labelText: 'Product Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Product name is required';
                          }
                          return null;
                        },
                      ),
                      
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _productCodeController,
                        decoration: InputDecoration(
                          labelText: 'Product Code',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _brandController,
                        decoration: InputDecoration(
                          labelText: 'Brand',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.branding_watermark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Additional Information
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code_scanner),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _supplierIdController,
                        decoration: InputDecoration(
                          labelText: 'Supplier ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _unitController,
                        decoration: InputDecoration(
                          labelText: 'Unit Quantity',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      
                      SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.info),
                        ),
                        items: _statusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStatus = newValue!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Description
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description & Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Update Button
              ElevatedButton(
                onPressed: _isLoading || _isDeleting ? null : _updateProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                  foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ThemeConfig.getButtonTextColor(currentTheme),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Updating Product...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text(
                            'Update Product',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
              ),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}