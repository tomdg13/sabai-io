import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:csv/csv.dart';

class SettlementUploadPage extends StatefulWidget {
  const SettlementUploadPage({Key? key}) : super(key: key);

  @override
  State<SettlementUploadPage> createState() => _SettlementUploadPageState();
}

class _SettlementUploadPageState extends State<SettlementUploadPage> with TickerProviderStateMixin {
  // File handling
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  String? _fileName;
  List<Map<String, dynamic>>? _parsedData;
  
  // Loading states
  bool _isParsing = false;
  bool _isUploading = false;
  
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Upload progress
  double _uploadProgress = 0.0;
  int _successCount = 0;
  int _errorCount = 0;
  List<String> _errorMessages = [];

  // Column mapping for flexible header matching
  static const Map<String, String> _columnMapping = {
    'transaction_time': 'Transaction Time',
    'payment_time': 'Payment Time',
    'order_number': 'Order Number',
    'psp_order_number': 'PSP Order Number',
    'original_order_number': 'Original Order Number',
    'original_psp_order_number': 'Original PSP Order Number',
    'transaction_amount': 'Transaction Amount',
    'tips_amount': 'Tips Amount',
    'transaction_currency': 'Transaction Currency',
    'merchant_settlement_amount': 'Merchant Settlement Amount',
    'merchant_settlement_currency': 'Merchant Settlement Currency',
    'mdr_amount': 'MDR Amount',
    'net_merchant_settlement_amount': 'Net Merchant Settlement Amount',
    'brand_settlement_amount': 'Brand Settlement Amount',
    'brand_settlement_currency': 'Brand  Settlement Currency', // Note the double space in your CSV
    'interchange_fee_amount': 'Interchange Fee Amount',
    'net_brand_settlement_amount': 'Net Brand Settlement Amount',
    'reconciliation_flag': 'Reconciliation Flag',
    'transaction_type': 'Transaction Type',
    'psp_name': 'PSP Name',
    'payment_brand': 'Payment Brand',
    'card_number': 'Card Number',
    'authorization_code': 'Authorization Code',
    'mcc': 'MCC',
    'crossborder_flag': 'Crossboarder Flag', // Handle the typo in your CSV
    'group_id': 'Group ID',
    'group_name': 'Group Name',
    'merchant_id': 'Merchant ID',
    'merchant_name': 'Merchant Name',
    'store_id': 'Store ID',
    'store_name': 'Store Name',
    'terminal_id': 'Terminal ID',
    'terminal_settlement_time': 'Terminal Settlement Time',
    'batch_number': 'Batch Number',
    'terminal_trace_number': 'Terminal Trace Number',
    'remark': 'Remark'
  };

  static const List<String> _requiredColumns = [
    'transaction_time', 'payment_time', 'order_number', 'psp_order_number',
    'transaction_amount', 'transaction_currency', 'merchant_settlement_amount',
    'merchant_settlement_currency', 'mdr_amount', 'net_merchant_settlement_amount',
    'reconciliation_flag', 'transaction_type', 'psp_name', 'payment_brand',
    'card_number', 'authorization_code', 'mcc', 'group_id',
    'group_name', 'merchant_id', 'merchant_name', 'store_id', 'store_name',
    'terminal_id', 'terminal_settlement_time', 'batch_number', 'terminal_trace_number'
  ];

  // Optional columns that will be set to default values if missing
  static const List<String> _optionalColumns = [
    'crossborder_flag', 'original_order_number', 'original_psp_order_number',
    'tips_amount', 'brand_settlement_amount', 'brand_settlement_currency',
    'interchange_fee_amount', 'net_brand_settlement_amount', 'remark'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Initialization methods
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
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  // File picking methods
  Future<void> _pickFile() async {
    try {
      _resetState();
      
      if (kIsWeb) {
        await _pickFileWeb();
      } else {
        await _pickFileMobile();
      }
    } catch (e) {
      _showSnackBar('Error selecting file: $e', isError: true);
    }
  }

  Future<void> _pickFileWeb() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = '.xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv';
    input.click();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files!.isEmpty) return;

      final file = files[0];
      if (!_isValidFileType(file.name)) return;

      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) async {
        final Uint8List bytes = reader.result as Uint8List;
        await _processFile(file.name, bytes);
      });
      reader.readAsArrayBuffer(file);
    });
  }

  Future<void> _pickFileMobile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (!_isValidFileType(file.name)) return;
      
      await _processFile(file.name, file.bytes!);
    }
  }

  bool _isValidFileType(String fileName) {
    String extension = fileName.toLowerCase().split('.').last;
    List<String> allowedExtensions = ['xlsx', 'xls', 'csv'];
    
    print('🔍 Checking file: $fileName, extension: $extension');
    
    if (!allowedExtensions.contains(extension)) {
      print('❌ Invalid file type: $extension');
      _showSnackBar('Please select a valid file (.xlsx, .xls, or .csv)', isError: true);
      return false;
    }
    
    print('✅ Valid file type: $extension');
    return true;
  }

  Future<void> _processFile(String fileName, Uint8List bytes) async {
    print('📁 Processing file: $fileName (${bytes.length} bytes)');
    
    setState(() {
      _fileName = fileName;
      _fileBytes = bytes;
      _isParsing = true;
    });

    try {
      String extension = fileName.toLowerCase().split('.').last;
      print('📋 File extension: $extension');
      
      if (extension == 'csv') {
        print('🔄 Parsing as CSV file...');
        await _parseCsvFile();
      } else {
        print('🔄 Parsing as Excel file...');
        await _parseExcelFile();
      }
    } catch (e) {
      print('❌ Error processing file: $e');
      _showSnackBar('Error processing file: $e', isError: true);
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  // File parsing methods
  Future<void> _parseCsvFile() async {
    print('📊 Starting CSV parsing...');
    try {
      String csvString = String.fromCharCodes(_fileBytes!);
      print('📝 CSV content length: ${csvString.length} characters');
      print('📝 First 200 characters: ${csvString.substring(0, csvString.length > 200 ? 200 : csvString.length)}');
      
      List<List<dynamic>> csvTable = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);
      
      print('📊 CSV parsed: ${csvTable.length} rows found');
      if (csvTable.isNotEmpty) {
        print('📋 Headers: ${csvTable.first}');
      }
      
      await _processTableData(csvTable);
    } catch (e) {
      print('❌ CSV parsing error: $e');
      _showSnackBar('Error parsing CSV file: $e', isError: true);
    }
  }

  Future<void> _parseExcelFile() async {
    print('📊 Starting Excel parsing...');
    try {
      var excel = excel_pkg.Excel.decodeBytes(_fileBytes!);
      print('📋 Excel sheets found: ${excel.tables.keys.toList()}');
      
      var table = excel.tables[excel.tables.keys.first];
      
      if (table == null || table.rows.isEmpty) {
        throw Exception('Excel file is empty or invalid');
      }

      print('📊 Excel parsed: ${table.rows.length} rows found');

      List<List<dynamic>> excelTable = table.rows.map((row) => 
        row.map((cell) => cell?.value?.toString() ?? '').toList()
      ).toList();
      
      if (excelTable.isNotEmpty) {
        print('📋 Headers: ${excelTable.first}');
      }
      
      await _processTableData(excelTable);
    } catch (e) {
      print('❌ Excel parsing error: $e');
      _showSnackBar('Error parsing Excel file: $e', isError: true);
    }
  }

  Future<void> _processTableData(List<List<dynamic>> tableData) async {
    print('🔄 Processing table data...');
    if (tableData.isEmpty) {
      throw Exception('File is empty or invalid');
    }

    List<String> headers = tableData.first.map((cell) => cell.toString().trim()).toList();
    print('📋 Found ${headers.length} headers: $headers');
    
    Map<String, String> headerToApiField = _createHeaderMapping(headers);
    print('🔗 Header mapping: $headerToApiField');
    
    List<String> missingColumns = _validateRequiredColumns(headerToApiField);
    if (missingColumns.isNotEmpty) {
      print('❌ Missing columns: $missingColumns');
      throw Exception('Missing required columns: ${missingColumns.join(', ')}');
    }

    print('✅ All required columns found');
    List<Map<String, dynamic>> parsedData = [];
    
    for (int i = 1; i < tableData.length; i++) {
      var row = tableData[i];
      if (_isEmptyRow(row)) {
        print('⏭️ Skipping empty row $i');
        continue;
      }

      Map<String, dynamic> rowData = {};
      
      // First, set default values for optional columns
      for (String optionalColumn in _optionalColumns) {
        rowData[optionalColumn] = _getDefaultValue(optionalColumn);
      }
      
      // Then process the actual data from the file
      for (int j = 0; j < headers.length && j < row.length; j++) {
        String header = headers[j];
        String apiField = headerToApiField[header] ?? _normalizeColumnName(header);
        var convertedValue = _convertCellValue(apiField, row[j]);
        rowData[apiField] = convertedValue;
      }
      
      // Clean up any duplicate crossborder fields and fix typos
      if (rowData.containsKey('crossboarder_flag') && rowData.containsKey('crossborder_flag')) {
        // Use the one from file data, remove the typo version
        rowData.remove('crossboarder_flag');
        print('🔧 Removed duplicate crossboarder_flag, kept crossborder_flag');
      } else if (rowData.containsKey('crossboarder_flag')) {
        // Rename the typo version to correct field name
        rowData['crossborder_flag'] = rowData['crossboarder_flag'];
        rowData.remove('crossboarder_flag');
        print('🔧 Fixed typo: crossboarder_flag → crossborder_flag');
      }
      
      parsedData.add(rowData);
      
      // Log first few rows for debugging
      if (i <= 3) {
        print('📄 Row $i data: $rowData');
      }
    }

    print('✅ Processed ${parsedData.length} data rows');
    setState(() {
      _parsedData = parsedData;
    });

    _showSnackBar('File parsed successfully! Found ${parsedData.length} records.', isError: false);
  }

  // Data processing helper methods
  Map<String, String> _createHeaderMapping(List<String> headers) {
    print('Creating header mapping...');
    Map<String, String> headerToApiField = {};
    
    for (String header in headers) {
      print('Processing header: "$header"');
      bool mapped = false;
      
      // Special handling for exact matches from your CSV
      Map<String, String> exactMatches = {
        'Crossboarder Flag': 'crossborder_flag', // Your CSV has this typo
        'Brand  Settlement Currency': 'brand_settlement_currency', // Note double space
        'Transaction Time': 'transaction_time',
        'Payment Time': 'payment_time',
        'Order Number': 'order_number',
        'PSP Order Number': 'psp_order_number',
        'Original Order Number': 'original_order_number',
        'Original PSP Order Number': 'original_psp_order_number',
        'Transaction Amount': 'transaction_amount',
        'Tips Amount': 'tips_amount',
        'Transaction Currency': 'transaction_currency',
        'Merchant Settlement Amount': 'merchant_settlement_amount',
        'Merchant Settlement Currency': 'merchant_settlement_currency',
        'MDR Amount': 'mdr_amount',
        'Net Merchant Settlement Amount': 'net_merchant_settlement_amount',
        'Brand Settlement Amount': 'brand_settlement_amount',
        'Brand Settlement Currency': 'brand_settlement_currency',
        'Interchange Fee Amount': 'interchange_fee_amount',
        'Net Brand Settlement Amount': 'net_brand_settlement_amount',
        'Reconciliation Flag': 'reconciliation_flag',
        'Transaction Type': 'transaction_type',
        'PSP Name': 'psp_name',
        'Payment Brand': 'payment_brand',
        'Card Number': 'card_number',
        'Authorization Code': 'authorization_code',
        'MCC': 'mcc',
        'Group ID': 'group_id',
        'Group Name': 'group_name',
        'Merchant ID': 'merchant_id',
        'Merchant Name': 'merchant_name',
        'Store ID': 'store_id',
        'Store Name': 'store_name',
        'Terminal ID': 'terminal_id',
        'Terminal Settlement Time': 'terminal_settlement_time',
        'Batch Number': 'batch_number',
        'Terminal Trace Number': 'terminal_trace_number',
        'Remark': 'remark'
      };
      
      // Check for exact match first
      if (exactMatches.containsKey(header)) {
        headerToApiField[header] = exactMatches[header]!;
        print('Exact match: "$header" → "${exactMatches[header]}"');
        mapped = true;
      } else {
        // Fallback to normalized matching
        for (String apiField in _columnMapping.keys) {
          String expectedHeader = _columnMapping[apiField]!;
          String normalizedHeader = _normalizeColumnName(header);
          String normalizedExpected = _normalizeColumnName(expectedHeader);
          String normalizedApiField = _normalizeColumnName(apiField);
          
          if (normalizedHeader == normalizedExpected || normalizedHeader == normalizedApiField) {
            headerToApiField[header] = apiField;
            print('Normalized match: "$header" → "$apiField"');
            mapped = true;
            break;
          }
        }
      }
      
      if (!mapped) {
        print('No mapping found for header: "$header"');
      }
    }
    
    print('Final mapping: $headerToApiField');
    print('Optional columns will be set to defaults: $_optionalColumns');
    return headerToApiField;
  }

  List<String> _validateRequiredColumns(Map<String, String> headerToApiField) {
    List<String> missingColumns = [];
    
    for (String apiField in _requiredColumns) {
      if (!headerToApiField.containsValue(apiField)) {
        String expectedHeader = _columnMapping[apiField] ?? apiField;
        missingColumns.add('$expectedHeader (or $apiField)');
      }
    }
    
    return missingColumns;
  }

  bool _isEmptyRow(List<dynamic> row) {
    return row.every((cell) => cell == null || cell.toString().trim().isEmpty);
  }

  String _normalizeColumnName(String columnName) {
    return columnName
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^\w]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  dynamic _convertCellValue(String columnName, dynamic value) {
    if (value == null) return null;
    
    String valueStr = value.toString().trim();
    if (valueStr.isEmpty) return null;

    // Date/time columns - convert to ISO format
    const dateTimeColumns = {
      'transaction_time', 'payment_time', 'terminal_settlement_time'
    };
    
    if (dateTimeColumns.contains(columnName)) {
      try {
        // Handle different date formats
        DateTime dateTime;
        
        if (valueStr.contains('UTC +')) {
          // Handle format like "2025-09-18 14:51:28 UTC +07:00"
          String cleanDate = valueStr.replaceAll(' UTC +07:00', '+07:00').replaceAll(' ', 'T');
          dateTime = DateTime.parse(cleanDate);
        } else if (valueStr.contains('T')) {
          // Already in ISO format
          dateTime = DateTime.parse(valueStr);
        } else {
          // Try parsing as-is
          dateTime = DateTime.parse(valueStr);
        }
        
        String isoString = dateTime.toUtc().toIso8601String();
        // Ensure it ends with Z
        if (!isoString.endsWith('Z')) {
          isoString = isoString + 'Z';
        }
        
        print('📅 Date converted: "$valueStr" → "$isoString"');
        return isoString;
      } catch (e) {
        print('⚠️ Date parsing error for $columnName: $valueStr -> $e');
        return valueStr; // Return original if parsing fails
      }
    }

    // Numeric integer columns
    const numericIntColumns = {
      'company_id', 'order_number', 'psp_order_number', 'original_order_number',
      'original_psp_order_number', 'authorization_code', 'mcc', 'terminal_id',
      'batch_number', 'terminal_trace_number'
    };
    
    // Numeric decimal columns (should be double with 2 decimal places)
    const numericDoubleColumns = {
      'transaction_amount', 'tips_amount', 'merchant_settlement_amount',
      'mdr_amount', 'net_merchant_settlement_amount', 'brand_settlement_amount',
      'interchange_fee_amount', 'net_brand_settlement_amount'
    };

    if (numericIntColumns.contains(columnName)) {
      return int.tryParse(valueStr) ?? valueStr;
    } else if (numericDoubleColumns.contains(columnName)) {
      double? doubleValue = double.tryParse(valueStr);
      return doubleValue != null ? double.parse(doubleValue.toStringAsFixed(2)) : valueStr;
    }
    
    return valueStr;
  }

  // Get default values for optional columns
  dynamic _getDefaultValue(String columnName) {
    switch (columnName) {
      case 'crossborder_flag':
        return 'Domestic'; // Default to Domestic
      case 'original_order_number':
      case 'original_psp_order_number':
      case 'tips_amount':
      case 'brand_settlement_amount':
      case 'brand_settlement_currency':
      case 'interchange_fee_amount':
      case 'net_brand_settlement_amount':
      case 'remark':
        return null; // These can be null
      default:
        return null;
    }
  }

  // Upload methods
  Future<void> _uploadData() async {
    if (_parsedData == null || _parsedData!.isEmpty) {
      _showSnackBar('No data to upload. Please select and parse a file first.', isError: true);
      return;
    }

    _resetUploadState();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('🔑 Original token: $token');
      
      // Check if token is expired by parsing JWT
      if (token != null && _isTokenExpired(token)) {
        print('⚠️ Token is expired, please login again');
        _showSnackBar('Session expired. Please login again and try uploading.', isError: true);
        setState(() {
          _isUploading = false;
        });
        return;
      }
      
      print('🏢 Company ID: $companyId');
      
      final url = AppConfig.api('/api/settlement-details');
      print('🌐 API URL: $url');
      
      for (int i = 0; i < _parsedData!.length; i++) {
        await _uploadSingleRecord(i, url.toString(), token, companyId);
        _updateProgress(i + 1);
      }

      _showUploadResultDialog();
    } catch (e) {
      print('💥 Upload error: $e');
      _showSnackBar('Error uploading data: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  bool _isTokenExpired(String token) {
    try {
      // Split JWT token
      List<String> parts = token.split('.');
      if (parts.length != 3) return true;
      
      // Decode payload (base64)
      String payload = parts[1];
      
      // Add padding if needed
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      
      String decodedPayload = String.fromCharCodes(base64.decode(payload));
      Map<String, dynamic> payloadMap = jsonDecode(decodedPayload);
      
      int exp = payloadMap['exp'] ?? 0;
      int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      print('🕐 Token exp: $exp, Current: $currentTime, Expired: ${exp < currentTime}');
      
      return exp < currentTime;
    } catch (e) {
      print('❌ Error checking token expiry: $e');
      return true; // Assume expired if we can't parse
    }
  }

  Future<void> _uploadSingleRecord(int index, String apiUrl, String? token, dynamic companyId) async {
    try {
      Map<String, dynamic> settlementData = Map.from(_parsedData![index]);
      settlementData['company_id'] = companyId;
      
      print('🚀 Uploading record ${index + 1}: ${settlementData.keys.length} fields');
      
      // Log the exact JSON being sent (first 3 records only)
      if (index < 3) {
        String jsonString = jsonEncode(settlementData);
        print('📤 Record ${index + 1} JSON: $jsonString');
      }
      
      print('🌐 Sending request to: $apiUrl');
      print('🔑 Authorization header: ${token != null ? 'Bearer $token' : 'No token'}');
      print('📋 Headers being sent:');
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      headers.forEach((key, value) => print('  $key: $value'));
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(settlementData),
      );

      print('📡 Response ${index + 1}: Status ${response.statusCode}');
      print('📨 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _successCount++;
        print('✅ Record ${index + 1} uploaded successfully');
      } else if (response.statusCode == 401 && index == 0) {
        // Try without Bearer prefix on first record only
        print('🔄 Trying without Bearer prefix...');
        final retryResponse = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': token, // No Bearer prefix
          },
          body: jsonEncode(settlementData),
        );
        
        print('📡 Retry Response: Status ${retryResponse.statusCode}');
        print('📨 Retry Response body: ${retryResponse.body}');
        
        if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
          print('✅ Success without Bearer prefix! API expects raw token.');
          _successCount++;
        } else {
          _errorCount++;
          print('❌ Still failed without Bearer prefix');
          try {
            final errorData = jsonDecode(response.body);
            _errorMessages.add('Row ${index + 1}: ${errorData['message'] ?? 'Unknown error'}');
          } catch (e) {
            _errorMessages.add('Row ${index + 1}: HTTP ${response.statusCode} - ${response.body}');
          }
        }
      } else {
        _errorCount++;
        print('❌ Record ${index + 1} failed: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          _errorMessages.add('Row ${index + 1}: ${errorData['message'] ?? 'Unknown error'}');
        } catch (e) {
          _errorMessages.add('Row ${index + 1}: HTTP ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      _errorCount++;
      print('💥 Exception uploading record ${index + 1}: $e');
      _errorMessages.add('Row ${index + 1}: $e');
    }
  }

  // State management methods
  void _resetState() {
    setState(() {
      _isParsing = true;
      _parsedData = null;
      _errorMessages.clear();
    });
  }

  void _resetUploadState() {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _successCount = 0;
      _errorCount = 0;
      _errorMessages.clear();
    });
  }

  void _updateProgress(int completedCount) {
    setState(() {
      _uploadProgress = completedCount / _parsedData!.length;
    });
  }

  // UI helper methods
  void _showSnackBar(String message, {required bool isError}) {
    print('${isError ? '❌' : '✅'} SnackBar: $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showUploadResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _errorCount == 0 ? Icons.check_circle : Icons.warning,
              color: _errorCount == 0 ? Colors.green : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 12),
            Text('Upload Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Summary:'),
            SizedBox(height: 8),
            Text('✅ Successful: $_successCount records'),
            Text('❌ Failed: $_errorCount records'),
            if (_errorMessages.isNotEmpty) ...[
              SizedBox(height: 16),
              Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                height: 200,
                child: SingleChildScrollView(
                  child: Text(
                    _errorMessages.take(10).join('\n'),
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ),
              if (_errorMessages.length > 10)
                Text('... and ${_errorMessages.length - 10} more errors'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_errorCount == 0) {
                Navigator.of(context).pop(true);
              }
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

  // UI Widget builders
  Widget _buildFileUploadSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: ThemeConfig.getPrimaryColor(currentTheme)),
                SizedBox(width: 12),
                Text(
                  'Upload Excel or CSV File',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildUploadArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _isParsing ? null : _pickFile,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _fileName != null 
                ? ThemeConfig.getPrimaryColor(currentTheme)
                : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: _isParsing
            ? _buildLoadingIndicator('Parsing file...')
            : _fileName != null
                ? _buildFileInfo()
                : _buildUploadPrompt(),
      ),
    );
  }

  Widget _buildLoadingIndicator(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: ThemeConfig.getPrimaryColor(currentTheme)),
        SizedBox(height: 12),
        Text(text),
      ],
    );
  }

  Widget _buildFileInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.description,
          size: 48,
          color: ThemeConfig.getPrimaryColor(currentTheme),
        ),
        SizedBox(height: 8),
        Text(
          _fileName!,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          textAlign: TextAlign.center,
        ),
        if (_parsedData != null)
          Text(
            '${_parsedData!.length} records found',
            style: TextStyle(color: Colors.green, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildUploadPrompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_upload, size: 48, color: Colors.grey[400]),
        SizedBox(height: 12),
        Text(
          'Click to select Excel or CSV file',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Supports .xlsx, .xls, and .csv files',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDataPreview() {
    if (_parsedData == null || _parsedData!.isEmpty) return SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: ThemeConfig.getPrimaryColor(currentTheme)),
                SizedBox(width: 12),
                Text(
                  'Data Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
                Spacer(),
                Text(
                  '${_parsedData!.length} records',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: _parsedData!.first.keys.take(5).map((key) => 
                        DataColumn(label: Text(key, style: TextStyle(fontWeight: FontWeight.bold)))
                    ).toList(),
                    rows: _parsedData!.take(5).map((row) => 
                        DataRow(
                          cells: row.values.take(5).map((value) => 
                              DataCell(Text(value?.toString() ?? ''))
                          ).toList(),
                        )
                    ).toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Showing first 5 columns and 5 rows',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    if (!_isUploading && _uploadProgress == 0.0) return SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload, color: ThemeConfig.getPrimaryColor(currentTheme)),
                SizedBox(width: 12),
                Text(
                  'Upload Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeConfig.getPrimaryColor(currentTheme),
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(_uploadProgress * 100).toInt()}% Complete'),
                Text('$_successCount success, $_errorCount errors'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return Container(
      height: 56,
      child: ElevatedButton(
        onPressed: (_parsedData == null || _parsedData!.isEmpty || _isUploading) 
            ? null 
            : _uploadData,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
        ),
        child: _isUploading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeConfig.getButtonTextColor(currentTheme),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Uploading Data...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Upload to API',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Settlement Details Upload'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isWideScreen ? 800 : double.infinity),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16.0,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFileUploadSection(),
                  SizedBox(height: 20),
                  _buildDataPreview(),
                  SizedBox(height: 20),
                  _buildUploadProgress(),
                  SizedBox(height: 30),
                  _buildUploadButton(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}