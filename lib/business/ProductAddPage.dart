import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:mobile_scanner/mobile_scanner.dart';

class ProductAddPage extends StatefulWidget {
  const ProductAddPage({Key? key}) : super(key: key);

  @override
  State<ProductAddPage> createState() => _ProductAddPageState();
}

class _ProductAddPageState extends State<ProductAddPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _productCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _supplierIdController = TextEditingController();
  final _notesController = TextEditingController();
  final _unitController = TextEditingController();

  String _selectedStatus = 'active';
  String? _base64Image;
  File? _imageFile;
  bool _isLoading = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Focus nodes for better keyboard navigation
  final _productNameFocus = FocusNode();
  final _productCodeFocus = FocusNode();
  final _categoryFocus = FocusNode();
  final _brandFocus = FocusNode();

  final List<String> _statusOptions = ['active', 'inactive', 'pending'];

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
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
    _productNameController.dispose();
    _productCodeController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _supplierIdController.dispose();
    _notesController.dispose();
    _unitController.dispose();
    _productNameFocus.dispose();
    _productCodeFocus.dispose();
    _categoryFocus.dispose();
    _brandFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Barcode Scanner Methods
  Future<void> _scanBarcode(String fieldType) async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerPage(fieldType: fieldType),
        ),
      );

      if (result != null && result.isNotEmpty) {
        setState(() {
          if (fieldType == 'product_code') {
            _productCodeController.text = result;
          } else if (fieldType == 'barcode') {
            _barcodeController.text = result;
          }
        });

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Barcode scanned: $result'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ DEBUG: Error scanning barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error scanning barcode: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show image source selection dialog
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_camera,
                    label: 'Camera',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
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

        print('📷 DEBUG: Image selected and converted to base64');

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Image selected successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ DEBUG: Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error selecting image: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createProduct() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Please fill in all required fields'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = prefs.getInt('company_id') ?? 1;

      final url = AppConfig.api('/api/ioproduct');
      print('🌐 DEBUG: Creating product at: $url');

      // In your _createProduct() method, change this line:

      final productData = {
        'company_id': companyId,
        'product_name': _productNameController.text.trim(),
        'product_code': _productCodeController.text.trim().isNotEmpty
            ? _productCodeController.text.trim()
            : null,
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'category': _categoryController.text.trim().isNotEmpty
            ? _categoryController.text.trim()
            : null,
        'brand': _brandController.text.trim().isNotEmpty
            ? _brandController.text.trim()
            : null,
        'barcode': _barcodeController.text.trim().isNotEmpty
            ? _barcodeController.text.trim()
            : null,
        'supplier_id': _supplierIdController.text.trim().isNotEmpty
            ? int.tryParse(_supplierIdController.text.trim())
            : null,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        'unit': _unitController.text.trim().isNotEmpty
            ? int.tryParse(_unitController.text.trim())
            : null,
        'status': _selectedStatus,
        'image': _base64Image, // ✅ Changed from 'image_url' to 'image'
      };
      print('📝 DEBUG: Product data: ${productData.toString()}');

      final response = await http.post(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(productData),
      );

      print('📡 DEBUG: Response Status: ${response.statusCode}');
      print('📝 DEBUG: Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          // Show success dialog instead of just snackbar
          _showSuccessDialog();
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ DEBUG: Error creating product: $e');
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Text(
          'Product "${_productNameController.text}" has been created successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to product list
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text('Failed to create product:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Try Again',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
    bool showScanButton = false,
    String? scanType,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        textInputAction: nextFocus != null
            ? TextInputAction.next
            : TextInputAction.done,
        onFieldSubmitted: (_) {
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          }
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          suffixIcon: showScanButton
              ? IconButton(
                  icon: Icon(
                    Icons.qr_code_scanner,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                  onPressed: () => _scanBarcode(scanType!),
                  tooltip: 'Scan barcode',
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Add New Product'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          if (_isLoading)
            Container(
              margin: EdgeInsets.all(16),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getButtonTextColor(currentTheme),
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
              _buildSectionCard(
                title: 'Product Image',
                icon: Icons.image,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _imageFile != null
                                ? ThemeConfig.getPrimaryColor(currentTheme)
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  children: [
                                    Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    size: 48,
                                    color: ThemeConfig.getPrimaryColor(
                                      currentTheme,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Tap to add image',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Recommended: 800x800px',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Basic Information
              _buildSectionCard(
                title: 'Basic Information',
                icon: Icons.info_outline,
                children: [
                  _buildEnhancedTextField(
                    controller: _productNameController,
                    label: 'Product Name *',
                    icon: Icons.inventory,
                    focusNode: _productNameFocus,
                    nextFocus: _productCodeFocus,
                    hint: 'Enter product name',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Product name is required';
                      }
                      return null;
                    },
                  ),

                  _buildEnhancedTextField(
                    controller: _productCodeController,
                    label: 'Product Code',
                    icon: Icons.qr_code,
                    focusNode: _productCodeFocus,
                    nextFocus: _categoryFocus,
                    hint: 'Enter product code or scan barcode',
                    showScanButton: true,
                    scanType: 'product_code',
                  ),

                  _buildEnhancedTextField(
                    controller: _categoryController,
                    label: 'Category',
                    icon: Icons.category,
                    focusNode: _categoryFocus,
                    nextFocus: _brandFocus,
                    hint: 'Enter product category',
                  ),

                  _buildEnhancedTextField(
                    controller: _brandController,
                    label: 'Brand',
                    icon: Icons.branding_watermark,
                    focusNode: _brandFocus,
                    hint: 'Enter brand name',
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Additional Information
              _buildSectionCard(
                title: 'Additional Details',
                icon: Icons.more_horiz,
                children: [
                  _buildEnhancedTextField(
                    controller: _barcodeController,
                    label: 'Barcode',
                    icon: Icons.qr_code_scanner,
                    hint: 'Enter barcode number or scan',
                    showScanButton: true,
                    scanType: 'barcode',
                  ),

                  _buildEnhancedTextField(
                    controller: _supplierIdController,
                    label: 'Supplier ID',
                    icon: Icons.business,
                    keyboardType: TextInputType.number,
                    hint: 'Enter supplier ID',
                  ),

                  _buildEnhancedTextField(
                    controller: _unitController,
                    label: 'Unit Quantity',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    hint: 'Enter quantity in stock',
                  ),

                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(
                          Icons.info,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(status.toUpperCase()),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Description
              _buildSectionCard(
                title: 'Description & Notes',
                icon: Icons.description,
                children: [
                  _buildEnhancedTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    icon: Icons.description,
                    maxLines: 3,
                    hint: 'Enter product description',
                  ),

                  _buildEnhancedTextField(
                    controller: _notesController,
                    label: 'Notes',
                    icon: Icons.note,
                    maxLines: 3,
                    hint: 'Enter additional notes',
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Create Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(
                        currentTheme,
                      ),
                      foregroundColor: ThemeConfig.getButtonTextColor(
                        currentTheme,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: ThemeConfig.getPrimaryColor(
                        currentTheme,
                      ).withOpacity(0.3),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ThemeConfig.getButtonTextColor(
                                      currentTheme,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Creating Product...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Create Product',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

// Barcode Scanner Page
class BarcodeScannerPage extends StatefulWidget {
  final String fieldType;

  const BarcodeScannerPage({Key? key, required this.fieldType})
    : super(key: key);

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.fieldType == 'product_code'
              ? 'Scan Product Code'
              : 'Scan Barcode',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: Icon(Icons.flip_camera_ios),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner View
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (!isScanned) {
                isScanned = true;
                final List<Barcode> barcodes = capture.barcodes;

                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.displayValue ?? '';

                  if (code.isNotEmpty) {
                    // Vibrate on successful scan (if available)
                    // HapticFeedback.mediumImpact();

                    // Return the scanned code
                    Navigator.of(context).pop(code);
                  } else {
                    setState(() {
                      isScanned = false;
                    });
                  }
                }
              }
            },
          ),

          // Scanner Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.white,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 5,
                cutOutSize: 250,
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.fieldType == 'product_code'
                          ? 'Position the product code within the frame to scan'
                          : 'Position the barcode within the frame to scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// QR Scanner Overlay Shape
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + borderRadius,
          rect.top,
        )
        ..lineTo(rect.right, rect.top);
    }

    Path _getRightTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.right - borderRadius, rect.top)
        ..quadraticBezierTo(
          rect.right,
          rect.top,
          rect.right,
          rect.top + borderRadius,
        )
        ..lineTo(rect.right, rect.bottom);
    }

    Path _getRightBottomPath(Rect rect) {
      return Path()
        ..moveTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.bottom - borderRadius)
        ..quadraticBezierTo(
          rect.right,
          rect.bottom,
          rect.right - borderRadius,
          rect.bottom,
        )
        ..lineTo(rect.left, rect.bottom);
    }

    Path _getLeftBottomPath(Rect rect) {
      return Path()
        ..moveTo(rect.right, rect.bottom)
        ..lineTo(rect.left + borderRadius, rect.bottom)
        ..quadraticBezierTo(
          rect.left,
          rect.bottom,
          rect.left,
          rect.bottom - borderRadius,
        )
        ..lineTo(rect.left, rect.top);
    }

    final width = rect.width;
    // ignore: unused_local_variable
    final borderWidthSize = width / 2;
    final height = rect.height;
    // ignore: unused_local_variable
    final borderHeightSize = height / 2;
    final cutOutWidth = cutOutSize < width ? cutOutSize : width - borderWidth;
    final cutOutHeight = cutOutSize < height
        ? cutOutSize
        : height - borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutWidth) / 2 + borderWidth,
      rect.top + (height - cutOutHeight) / 2 + borderWidth,
      cutOutWidth - borderWidth * 2,
      cutOutHeight - borderWidth * 2,
    );

    final cutOutRRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    final leftTopCorner = Rect.fromLTWH(
      cutOutRect.left,
      cutOutRect.top,
      borderLength,
      borderLength,
    );

    final rightTopCorner = Rect.fromLTWH(
      cutOutRect.right - borderLength,
      cutOutRect.top,
      borderLength,
      borderLength,
    );

    final rightBottomCorner = Rect.fromLTWH(
      cutOutRect.right - borderLength,
      cutOutRect.bottom - borderLength,
      borderLength,
      borderLength,
    );

    final leftBottomCorner = Rect.fromLTWH(
      cutOutRect.left,
      cutOutRect.bottom - borderLength,
      borderLength,
      borderLength,
    );

    return Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()
        ..addRRect(cutOutRRect)
        ..addPath(_getLeftTopPath(leftTopCorner), Offset.zero)
        ..addPath(_getRightTopPath(rightTopCorner), Offset.zero)
        ..addPath(_getRightBottomPath(rightBottomCorner), Offset.zero)
        ..addPath(_getLeftBottomPath(leftBottomCorner), Offset.zero),
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    // ignore: unused_local_variable
    final borderWidthSize = width / 2;
    final height = rect.height;
    // ignore: unused_local_variable
    final borderHeightSize = height / 2;
    final cutOutWidth = cutOutSize < width ? cutOutSize : width - borderWidth;
    final cutOutHeight = cutOutSize < height
        ? cutOutSize
        : height - borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutWidth) / 2 + borderWidth,
      rect.top + (height - cutOutHeight) / 2 + borderWidth,
      cutOutWidth - borderWidth * 2,
      cutOutHeight - borderWidth * 2,
    );

    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(rect)
      ..addRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      );

    canvas.drawPath(backgroundPath, paint..blendMode = BlendMode.srcOver);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw corner borders
    final path = Path();

    // Left top corner
    path.moveTo(cutOutRect.left - borderWidth, cutOutRect.top + borderLength);
    path.lineTo(
      cutOutRect.left - borderWidth,
      cutOutRect.top - borderWidth + borderRadius,
    );
    path.arcToPoint(
      Offset(cutOutRect.left + borderRadius, cutOutRect.top - borderWidth),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(cutOutRect.left + borderLength, cutOutRect.top - borderWidth);

    // Right top corner
    path.moveTo(cutOutRect.right - borderLength, cutOutRect.top - borderWidth);
    path.lineTo(cutOutRect.right - borderRadius, cutOutRect.top - borderWidth);
    path.arcToPoint(
      Offset(cutOutRect.right + borderWidth, cutOutRect.top + borderRadius),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(cutOutRect.right + borderWidth, cutOutRect.top + borderLength);

    // Right bottom corner
    path.moveTo(
      cutOutRect.right + borderWidth,
      cutOutRect.bottom - borderLength,
    );
    path.lineTo(
      cutOutRect.right + borderWidth,
      cutOutRect.bottom - borderRadius,
    );
    path.arcToPoint(
      Offset(cutOutRect.right - borderRadius, cutOutRect.bottom + borderWidth),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(
      cutOutRect.right - borderLength,
      cutOutRect.bottom + borderWidth,
    );

    // Left bottom corner
    path.moveTo(
      cutOutRect.left + borderLength,
      cutOutRect.bottom + borderWidth,
    );
    path.lineTo(
      cutOutRect.left + borderRadius,
      cutOutRect.bottom + borderWidth,
    );
    path.arcToPoint(
      Offset(cutOutRect.left - borderWidth, cutOutRect.bottom - borderRadius),
      radius: Radius.circular(borderRadius),
    );
    path.lineTo(
      cutOutRect.left - borderWidth,
      cutOutRect.bottom - borderLength,
    );

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
