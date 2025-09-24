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
  Uint8List? _fileBytes;
  String? _fileName;
  List<Map<String, dynamic>>? _parsedData;
  
  // State management
  bool _isParsing = false;
  bool _isUploading = false;
  bool _isConverting = false;
  String _fileType = 'settlement';
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Upload tracking
  double _uploadProgress = 0.0;
  int _successCount = 0;
  int _errorCount = 0;
  List<String> _errorMessages = [];

  // PSP to Settlement field mapping
  static const Map<String, String> _pspFieldMapping = {
    'company_id': '',
    'transaction_time': 'Merchant Txn Time',
    'payment_time': 'Txn Pay Time', 
    'order_number': 'Merchant Txn ID',
    'psp_order_number': 'PSP Txn ID',
    'original_order_number': 'Original Merchant Txn ID',
    'original_psp_order_number': 'Original PSP Txn ID',
    'system_transaction_id': 'System Txn ID',
    'original_system_transaction_id': 'Original System Txn ID',
    'system_transaction_time': 'System Txn Time',
    'transaction_amount': 'Merchant Txn Amt',
    'tips_amount': 'Tips Amount',
    'transaction_currency': 'Merchant Txn Curr',
    'user_billing_amount': 'User Billing Amt',
    'user_billing_currency': 'User Billing Curr',
    'merchant_local_amount': 'Merchant Local Amt',
    'merchant_local_currency': 'Merchant Local Curr',
    'merchant_capture_amount': 'Merchant Capture Amt',
    'local_capture_amount': 'Local Capture Amt',
    'local_tips_amount': 'Local Tips Amt',
    'local_surcharge_fee_amount': 'Local Surcharge Fee Amt',
    'surcharge_fee_amount': 'Surcharge Fee Amt',
    'merchant_discount_amount': 'Merchant Discount Amt',
    'merchant_settlement_amount': 'Merchant Sttl Amt',
    'merchant_settlement_currency': 'Merchant Sttl Curr',
    'net_merchant_settlement_amount': 'Net Merchant Sttl Amt',
    'brand_settlement_amount': 'PSP Sttl Amt',
    'brand_settlement_currency': 'PSP Sttl Curr',
    'net_brand_settlement_amount': 'Net PSP Sttl Amt',
    'mdr_amount': 'MDR Amount',
    'interchange_fee_amount': 'PSP Interchange Fee',
    'psp_scheme_fee': 'PSP Scheme Fee',
    'acquirer_service_fee': 'Acquirer Service Fee',
    'transaction_service_fee': 'Txn Service Fee',
    'vat_amount': 'VAT Amount',
    'wht_amount': 'WHT Amount',
    'rate_local_to_transaction': 'Rate of Local to Txn',
    'rate_transaction_to_settlement': 'Rate from Merchant Txn to Sttl',
    'reconciliation_flag': 'Txn Status',
    'transaction_type': 'Txn Type',
    'transaction_status': 'Txn Status',
    'system_result_code': 'System Result Code',
    'psp_result_code': 'PSP Result Code',
    'crossborder_flag': 'Crossborder Flag',
    'psp_name': 'PSP Name',
    'payment_brand': 'Payment Brand',
    'card_number': 'Card Number',
    'authorization_code': 'PSP Authorization Code',
    'funding_type': 'Funding Type',
    'product_id': 'Product ID',
    'product_type_id': 'Product Type ID',
    'payment_method_variant': 'Payment Method Variant',
    'transaction_initiation_mode': 'Txn Initiation Mode',
    'eci': 'ECI',
    'linkpay_order_id': 'LinkPay Order ID',
    'group_id': 'Group ID',
    'group_name': 'Group Name',
    'merchant_id': 'Merchant ID',
    'merchant_name': 'Merchant Name',
    'store_id': 'Store ID',
    'store_name': 'Store Name',
    'mcc': 'Store MCC',
    'merchant_nation': 'Merchant Nation',
    'merchant_city': 'Merchant City',
    'merchant_order_reference': 'Merchant Order Reference',
    'issuer_country': 'Issuer Country',
    'terminal_id': 'Terminal ID',
    'terminal_settlement_time': 'Terminal Sttl Time',
    'batch_number': 'Batch Number',
    'terminal_trace_number': 'Terminal Trace Number',
    'mdr_rules': 'MDR Rules',
    'api_type': 'API Type',
    'api_code': 'API Code', // Added this line
    'remark': 'Metadata',
    'metadata': 'Metadata',
    'source_filename': '',
    'settlement_account_name': 'Settlement Account Name',
    'settlement_account_number': 'Settlement Account Number',
  };

  // Alternative column names for PSP files
  static const Map<String, List<String>> _pspAlternativeColumns = {
    'Merchant Txn Time': ['Transaction Time', 'Merchant Transaction Time', 'Txn Time'],
    'Merchant Txn ID': ['Transaction ID', 'Merchant Transaction ID', 'Order ID'],
    'PSP Txn ID': ['PSP Transaction ID', 'PSP Order ID', 'Payment ID'],
    'Merchant Txn Amt': ['Transaction Amount', 'Merchant Transaction Amount', 'Amount'],
    'Merchant Txn Curr': ['Transaction Currency', 'Currency', 'Txn Currency'],
    'PSP Name': ['Payment Service Provider', 'Provider Name', 'Gateway'],
    'Payment Brand': ['Card Brand', 'Brand', 'Card Type'],
    'Card Number': ['Card No', 'PAN', 'Card'],
    'PSP Authorization Code': ['Auth Code', 'Authorization', 'Approval Code'],
    'Merchant Sttl Amt': ['Settlement Amount', 'Settlement Amt', 'Sttl Amount'],
    'Net Merchant Sttl Amt': ['Net Settlement', 'Net Settlement Amount', 'Net Amount'],
    'PSP Interchange Fee': ['Interchange Fee', 'IC Fee', 'Network Fee'],
    'Txn Status': ['Transaction Status', 'Status', 'Payment Status'],
    'Txn Type': ['Transaction Type', 'Type', 'Payment Type'],
    'Crossborder Flag': ['Cross Border', 'International', 'Border Flag'],
    'Store MCC': ['MCC', 'Merchant Category Code', 'Category Code'],
    'Merchant Name': ['Merchant', 'Business Name', 'Store Name'],
    'Group Name': ['Group', 'Organization', 'Company Name'],
    'System Txn ID': ['System Transaction ID', 'Internal ID', 'Reference ID'],
    'User Billing Amt': ['Billing Amount', 'Customer Amount', 'Cardholder Amount'],
    'Funding Type': ['Card Type', 'Payment Method', 'Fund Source'],
    'Txn Initiation Mode': ['Initiation Mode', 'Entry Mode', 'Transaction Mode'],
    'API Code': ['API Type Code', 'API Version', 'Interface Code', 'Gateway Code'], // Added this line
  };

  // Settlement column mapping
  static const Map<String, String> _columnMapping = {
    'company_id': 'Company ID',
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
    'brand_settlement_currency': 'Brand Settlement Currency',
    'interchange_fee_amount': 'Interchange Fee Amount',
    'net_brand_settlement_amount': 'Net Brand Settlement Amount',
    'reconciliation_flag': 'Reconciliation Flag',
    'transaction_type': 'Transaction Type',
    'psp_name': 'PSP Name',
    'payment_brand': 'Payment Brand',
    'card_number': 'Card Number',
    'authorization_code': 'Authorization Code',
    'mcc': 'MCC',
    'crossborder_flag': 'Crossborder Flag',
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
    'remark': 'Remark',
    'source_filename': 'Source Filename',
    'merchant_nation': 'Merchant Nation',
    'merchant_city': 'Merchant City',
    'system_transaction_time': 'System Transaction Time',
    'api_type': 'API Type',
    'api_code': 'API Code', // Added this line
    'payment_method_variant': 'Payment Method Variant',
    'funding_type': 'Funding Type',
    'product_id': 'Product ID',
    'product_type_id': 'Product Type ID',
    'issuer_country': 'Issuer Country',
    'merchant_order_reference': 'Merchant Order Reference',
    'system_transaction_id': 'System Transaction ID',
    'original_system_transaction_id': 'Original System Transaction ID',
    'merchant_local_amount': 'Merchant Local Amount',
    'local_tips_amount': 'Local Tips Amount',
    'local_surcharge_fee_amount': 'Local Surcharge Fee Amount',
    'local_capture_amount': 'Local Capture Amount',
    'merchant_local_currency': 'Merchant Local Currency',
    'rate_local_to_transaction': 'Rate Local to Transaction',
    'surcharge_fee_amount': 'Surcharge Fee Amount',
    'merchant_capture_amount': 'Merchant Capture Amount',
    'merchant_discount_amount': 'Merchant Discount Amount',
    'rate_transaction_to_settlement': 'Rate Transaction to Settlement',
    'mdr_rules': 'MDR Rules',
    'psp_scheme_fee': 'PSP Scheme Fee',
    'acquirer_service_fee': 'Acquirer Service Fee',
    'transaction_service_fee': 'Transaction Service Fee',
    'vat_amount': 'VAT Amount',
    'wht_amount': 'WHT Amount',
    'user_billing_amount': 'User Billing Amount',
    'user_billing_currency': 'User Billing Currency',
    'eci': 'ECI',
    'transaction_initiation_mode': 'Transaction Initiation Mode',
    'linkpay_order_id': 'LinkPay Order ID',
    'transaction_status': 'Transaction Status',
    'system_result_code': 'System Result Code',
    'psp_result_code': 'PSP Result Code',
    'settlement_account_name': 'Settlement Account Name',
    'settlement_account_number': 'Settlement Account Number',
    'metadata': 'Metadata',
  };

  static const List<String> _requiredColumns = [
    'company_id', 'transaction_time', 'order_number', 'transaction_amount',
    'transaction_currency', 'merchant_settlement_amount', 'merchant_settlement_currency',
    'reconciliation_flag', 'transaction_type', 'psp_name', 'payment_brand',
    'merchant_id', 'merchant_name', 'store_id', 'store_name', 'terminal_id'
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

  List<String> _cleanHeaders(List<String> headers) {
    return headers.map((header) => header
        .replaceAll('\uFEFF', '')
        .replaceAll('ï»¿', '')
        .replaceAll('\u00EF\u00BB\u00BF', '')
        .trim()).toList();
  }

  String _findPSPColumn(List<String> headers, String targetColumn) {
    // First try exact match
    for (String header in headers) {
      if (header.trim() == targetColumn.trim()) {
        return header;
      }
    }
    
    // Try alternative column names
    if (_pspAlternativeColumns.containsKey(targetColumn)) {
      for (String alternative in _pspAlternativeColumns[targetColumn]!) {
        for (String header in headers) {
          if (header.trim().toLowerCase() == alternative.toLowerCase()) {
            return header;
          }
        }
      }
    }
    
    // Try partial matching
    for (String header in headers) {
      String normalizedHeader = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      String normalizedTarget = targetColumn.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      if (normalizedHeader.contains(normalizedTarget) || normalizedTarget.contains(normalizedHeader)) {
        return header;
      }
    }
    
    return '';
  }

  String _detectFileType(List<String> headers) {
    print('=== FILE TYPE DETECTION ===');
    print('Headers found: ${headers.length}');
    print('Headers: $headers');
    print('');
    
    List<String> pspIndicators = [
      'PSP Txn ID', 'PSP Name', 'PSP Sttl Amt', 'System Txn ID',
      'Merchant Txn Time', 'PSP Authorization Code', 'PSP Interchange Fee',
      'Rate of Local to Txn', 'Net PSP Sttl Amt'
    ];
    
    List<String> settlementIndicators = [
      'Transaction Time', 'Payment Time', 'Order Number', 'Settlement Amount',
      'Terminal ID', 'Batch Number', 'Terminal Trace Number'
    ];
    
    int pspMatches = 0;
    int settlementMatches = 0;
    List<String> foundPspFields = [];
    List<String> foundSettlementFields = [];
    
    print('Checking PSP indicators:');
    for (String indicator in pspIndicators) {
      String found = _findPSPColumn(headers, indicator);
      if (found.isNotEmpty) {
        pspMatches++;
        foundPspFields.add(indicator);
        print('✓ Found PSP: $indicator -> $found');
      } else {
        print('✗ Missing PSP: $indicator');
      }
    }
    
    print('');
    print('Checking Settlement indicators:');
    for (String indicator in settlementIndicators) {
      bool found = false;
      for (String header in headers) {
        if (header.toLowerCase().contains(indicator.toLowerCase())) {
          settlementMatches++;
          foundSettlementFields.add(indicator);
          found = true;
          print('✓ Found Settlement: $indicator -> $header');
          break;
        }
      }
      if (!found) {
        print('✗ Missing Settlement: $indicator');
      }
    }
    
    String detectedType = pspMatches >= 3 ? 'psp' : 'settlement';
    
    print('');
    print('DETECTION RESULTS:');
    print('PSP matches: $pspMatches/${pspIndicators.length}');
    print('Settlement matches: $settlementMatches/${settlementIndicators.length}');
    print('Detected type: $detectedType');
    print('Found PSP fields: $foundPspFields');
    print('Found Settlement fields: $foundSettlementFields');
    print('=== END DETECTION ===');
    print('');
    
    // Show field detection results in SnackBar
    String message = 'File Type: $detectedType\n';
    if (detectedType == 'psp') {
      message += 'PSP fields found (${foundPspFields.length}): ${foundPspFields.take(3).join(', ')}';
      if (foundPspFields.length > 3) message += '...';
    } else {
      message += 'Settlement fields found (${foundSettlementFields.length}): ${foundSettlementFields.take(3).join(', ')}';
      if (foundSettlementFields.length > 3) message += '...';
    }
    
    _showFieldInfoSnackBar(message);
    
    return detectedType;
  }

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
    
    if (!allowedExtensions.contains(extension)) {
      _showSnackBar('Please select a valid file (.xlsx, .xls, or .csv)', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _processFile(String fileName, Uint8List bytes) async {
    print('=== FILE PROCESSING START ===');
    print('File name: $fileName');
    print('File size: ${bytes.length} bytes');
    
    setState(() {
      _fileName = fileName;
      _fileBytes = bytes;
      _isParsing = true;
    });

    try {
      String extension = fileName.toLowerCase().split('.').last;
      print('File extension: $extension');
      
      if (extension == 'csv') {
        await _parseCsvFile();
      } else {
        await _parseExcelFile();
      }
    } catch (e) {
      print('ERROR in file processing: $e');
      _showSnackBar('Error processing file: $e', isError: true);
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  Future<void> _parseCsvFile() async {
    try {
      print('=== CSV PARSING ===');
      String csvString = String.fromCharCodes(_fileBytes!);
      print('CSV string length: ${csvString.length}');
      print('First 200 characters: ${csvString.substring(0, csvString.length > 200 ? 200 : csvString.length)}');
      
      List<List<dynamic>> csvTable = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);
      
      print('CSV rows parsed: ${csvTable.length}');
      if (csvTable.isNotEmpty) {
        print('First row (headers): ${csvTable[0]}');
        if (csvTable.length > 1) {
          print('Second row sample: ${csvTable[1].take(3).toList()}...');
        }
      }
      
      await _processTableData(csvTable);
    } catch (e) {
      print('ERROR parsing CSV: $e');
      _showSnackBar('Error parsing CSV file: $e', isError: true);
    }
  }

  Future<void> _parseExcelFile() async {
    try {
      var excel = excel_pkg.Excel.decodeBytes(_fileBytes!);
      var table = excel.tables[excel.tables.keys.first];
      
      if (table == null || table.rows.isEmpty) {
        throw Exception('Excel file is empty or invalid');
      }

      List<List<dynamic>> excelTable = table.rows.map((row) => 
        row.map((cell) => cell?.value?.toString() ?? '').toList()
      ).toList();
      
      await _processTableData(excelTable);
    } catch (e) {
      _showSnackBar('Error parsing Excel file: $e', isError: true);
    }
  }

  Future<void> _processTableData(List<List<dynamic>> tableData) async {
    if (tableData.isEmpty) {
      throw Exception('File is empty or invalid');
    }

    List<String> rawHeaders = tableData.first.map((cell) => cell.toString()).toList();
    List<String> headers = _cleanHeaders(rawHeaders);
    
    _fileType = _detectFileType(headers);
    
    if (_fileType == 'psp') {
      await _processPSPData(tableData);
    } else {
      await _processSettlementData(tableData);
    }
  }

  Future<void> _processPSPData(List<List<dynamic>> tableData) async {
    print('=== PSP DATA PROCESSING ===');
    List<String> headers = _cleanHeaders(tableData.first.map((cell) => cell.toString()).toList());
    List<Map<String, dynamic>> pspData = [];
    
    Map<String, String> foundColumns = {};
    List<String> mappedFields = [];
    List<String> missingFields = [];
    
    print('Searching for PSP field mappings...');
    for (String targetColumn in _pspFieldMapping.values) {
      if (targetColumn.isNotEmpty) {
        String foundColumn = _findPSPColumn(headers, targetColumn);
        if (foundColumn.isNotEmpty) {
          foundColumns[targetColumn] = foundColumn;
          mappedFields.add(targetColumn);
          print('✓ Mapped: $targetColumn -> $foundColumn');
        } else {
          missingFields.add(targetColumn);
          print('✗ Missing: $targetColumn');
        }
      }
    }
    
    print('');
    print('PSP MAPPING SUMMARY:');
    print('Total expected fields: ${_pspFieldMapping.values.where((v) => v.isNotEmpty).length}');
    print('Found fields: ${mappedFields.length}');
    print('Missing fields: ${missingFields.length}');
    print('Mapped fields: $mappedFields');
    print('Missing fields: $missingFields');
    print('');
    
    // Show column mapping results in SnackBar
    String mappingMessage = 'PSP Column Mapping:\n';
    mappingMessage += 'Found: ${mappedFields.length} fields\n';
    mappingMessage += 'Missing: ${missingFields.length} fields\n';
    mappingMessage += 'Key fields: ${mappedFields.take(3).join(', ')}';
    if (mappedFields.length > 3) mappingMessage += '...';
    
    _showFieldInfoSnackBar(mappingMessage);
    
    print('Processing data rows...');
    for (int i = 1; i < tableData.length; i++) {
      var row = tableData[i];
      if (_isEmptyRow(row)) continue;
      
      if (row.isNotEmpty && row[0].toString().contains('***END***')) continue;

      Map<String, dynamic> rowData = {};
      
      foundColumns.forEach((targetColumn, foundColumn) {
        int columnIndex = headers.indexOf(foundColumn);
        if (columnIndex >= 0 && columnIndex < row.length) {
          var value = row[columnIndex];
          if (value != null && value.toString().isNotEmpty) {
            rowData[targetColumn] = value;
          }
        }
      });
      
      if (rowData.isNotEmpty) {
        pspData.add(rowData);
        if (pspData.length <= 3) { // Log first 3 rows
          print('Row ${i} data keys: ${rowData.keys.take(5).toList()}');
        }
      }
    }

    print('');
    print('PSP data processing complete: ${pspData.length} rows processed');
    
    if (pspData.isEmpty) {
      print('ERROR: No PSP data found after processing');
      _showSnackBar('No valid PSP data found in file. Check if column headers match expected format.', isError: true);
      return;
    }

    await _convertPSPToSettlement(pspData);
  }

  Future<void> _convertPSPToSettlement(List<Map<String, dynamic>> pspData) async {
    print('=== PSP TO SETTLEMENT CONVERSION ===');
    print('Converting ${pspData.length} PSP records to settlement format...');
    
    setState(() {
      _isConverting = true;
    });

    try {
      List<Map<String, dynamic>> convertedData = [];
      
      for (int i = 0; i < pspData.length; i++) {
        Map<String, dynamic> pspRow = pspData[i];
        Map<String, dynamic> settlementRow = {};
        
        // Initialize with defaults
        for (String field in _columnMapping.keys) {
          settlementRow[field] = _getDefaultValue(field);
        }
        
        // Map PSP fields to settlement fields
        int mappedFieldCount = 0;
        _pspFieldMapping.forEach((settlementField, pspField) {
          if (pspField.isNotEmpty && pspRow.containsKey(pspField)) {
            var value = pspRow[pspField];
            settlementRow[settlementField] = _convertValue(settlementField, value);
            mappedFieldCount++;
            
            if (i == 0) { // Log first row conversion details
              print('Convert: $settlementField = $value (from $pspField)');
            }
          }
        });
        
        if (i == 0) {
          print('First record mapped $mappedFieldCount fields from PSP to settlement format');
        }
        
        // Set computed fields
        settlementRow['batch_number'] = 1;
        settlementRow['terminal_trace_number'] = i + 1;
        settlementRow['source_filename'] = _fileName ?? 'psp_conversion';
        
        convertedData.add(settlementRow);
      }

      setState(() {
        _parsedData = convertedData;
      });

      print('');
      print('CONVERSION COMPLETE:');
      print('Converted ${convertedData.length} records from PSP to settlement format');
      print('Sample converted record fields: ${convertedData.isNotEmpty ? convertedData[0].keys.take(10).toList() : 'None'}');
      print('=== END CONVERSION ===');

      _showSnackBar('PSP file converted successfully! Found ${convertedData.length} records.', 
                   isError: false);
    } catch (e) {
      print('ERROR in PSP conversion: $e');
      _showSnackBar('Error converting PSP data: $e', isError: true);
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  Future<void> _processSettlementData(List<List<dynamic>> tableData) async {
    print('=== SETTLEMENT DATA PROCESSING ===');
    List<String> headers = tableData.first.map((cell) => cell.toString().trim()).toList();
    print('Settlement headers found: ${headers.length}');
    print('Headers: $headers');
    
    Map<String, String> headerToApiField = _createHeaderMapping(headers);
    
    List<String> mappedHeaders = [];
    List<String> unmappedHeaders = [];
    
    print('');
    print('HEADER MAPPING ANALYSIS:');
    for (String header in headers) {
      if (headerToApiField.containsKey(header)) {
        mappedHeaders.add(header);
        print('✓ Mapped: $header -> ${headerToApiField[header]}');
      } else {
        unmappedHeaders.add(header);
        print('✗ Unmapped: $header');
      }
    }
    
    print('');
    print('MAPPING SUMMARY:');
    print('Total headers: ${headers.length}');
    print('Mapped headers: ${mappedHeaders.length}');
    print('Unmapped headers: ${unmappedHeaders.length}');
    print('Mapped: $mappedHeaders');
    print('Unmapped: $unmappedHeaders');
    
    // Show settlement mapping results in SnackBar
    String mappingMessage = 'Settlement Column Mapping:\n';
    mappingMessage += 'Total headers: ${headers.length}\n';
    mappingMessage += 'Mapped: ${mappedHeaders.length}\n';
    mappingMessage += 'Unmapped: ${unmappedHeaders.length}\n';
    mappingMessage += 'Key mapped: ${mappedHeaders.take(3).join(', ')}';
    if (mappedHeaders.length > 3) mappingMessage += '...';
    
    _showFieldInfoSnackBar(mappingMessage);
    
    List<String> missingColumns = _validateRequiredColumns(headerToApiField);
    if (missingColumns.isNotEmpty) {
      print('');
      print('ERROR: Missing required columns:');
      for (String missing in missingColumns) {
        print('  - $missing');
      }
      
      String errorMessage = 'Missing required columns:\n${missingColumns.take(5).join(', ')}';
      if (missingColumns.length > 5) errorMessage += '\nand ${missingColumns.length - 5} more...';
      _showSnackBar(errorMessage, isError: true);
      throw Exception('Missing required columns: ${missingColumns.join(', ')}');
    }

    print('');
    print('Processing data rows...');
    List<Map<String, dynamic>> parsedData = [];
    
    for (int i = 1; i < tableData.length; i++) {
      var row = tableData[i];
      if (_isEmptyRow(row)) continue;

      Map<String, dynamic> rowData = {};
      
      for (String field in _columnMapping.keys) {
        rowData[field] = _getDefaultValue(field);
      }
      
      for (int j = 0; j < headers.length && j < row.length; j++) {
        String header = headers[j];
        String apiField = headerToApiField[header] ?? _normalizeColumnName(header);
        var convertedValue = _convertValue(apiField, row[j]);
        if (convertedValue != null) {
          rowData[apiField] = convertedValue;
        }
      }
      
      parsedData.add(rowData);
      
      if (parsedData.length <= 3) { // Log first 3 rows
        print('Row ${i} sample data: ${rowData.entries.take(5).map((e) => '${e.key}: ${e.value}').join(', ')}');
      }
    }

    setState(() {
      _parsedData = parsedData;
    });

    print('');
    print('Settlement processing complete: ${parsedData.length} records processed');
    print('=== END SETTLEMENT PROCESSING ===');

    _showSnackBar('Settlement file parsed successfully! Found ${parsedData.length} records.', 
                 isError: false);
  }

  void _showFieldInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: 12),
        ),
        backgroundColor: Colors.blue[700],
        duration: Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Map<String, String> _createHeaderMapping(List<String> headers) {
    Map<String, String> headerToApiField = {};
    
    for (String header in headers) {
      for (String apiField in _columnMapping.keys) {
        String expectedHeader = _columnMapping[apiField]!;
        if (header.trim() == expectedHeader.trim()) {
          headerToApiField[header] = apiField;
          break;
        }
      }
      
      if (!headerToApiField.containsKey(header)) {
        for (String apiField in _columnMapping.keys) {
          String normalizedHeader = _normalizeColumnName(header);
          String normalizedApiField = _normalizeColumnName(apiField);
          
          if (normalizedHeader == normalizedApiField) {
            headerToApiField[header] = apiField;
            break;
          }
        }
      }
    }
    
    return headerToApiField;
  }

  List<String> _validateRequiredColumns(Map<String, String> headerToApiField) {
    List<String> missingColumns = [];
    
    for (String apiField in _requiredColumns) {
      if (!headerToApiField.containsValue(apiField)) {
        String expectedHeader = _columnMapping[apiField] ?? apiField;
        missingColumns.add(expectedHeader);
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

  dynamic _convertValue(String columnName, dynamic value) {
    if (value == null) return null;
    
    String valueStr = value.toString().trim();
    if (valueStr.isEmpty) return null;

    // Date/time conversion
    const dateTimeColumns = {
      'transaction_time', 'payment_time', 'terminal_settlement_time', 'system_transaction_time'
    };
    
    if (dateTimeColumns.contains(columnName)) {
      try {
        DateTime dateTime = DateTime.parse(valueStr);
        return dateTime.toIso8601String(); // Keep as ISO string for MySQL datetime
      } catch (e) {
        print('Date parsing error for $columnName: $valueStr -> $e');
        return valueStr;
      }
    }

    // Integer columns (based on your DB schema)
    const integerColumns = {
      'company_id', 'mcc', 'batch_number', 'terminal_trace_number'
    };
    
    // Bigint columns (based on your DB schema)
    const bigintColumns = {
      'psp_order_number', 'original_psp_order_number', 'authorization_code'
    };
    
    // Decimal columns that must be numbers (based on your DB schema)
    const decimalColumns = {
      'transaction_amount', 'tips_amount', 'merchant_settlement_amount',
      'mdr_amount', 'net_merchant_settlement_amount', 'brand_settlement_amount',
      'interchange_fee_amount', 'net_brand_settlement_amount',
      'merchant_capture_amount', 'user_billing_amount', 'merchant_local_amount',
      'local_tips_amount', 'local_surcharge_fee_amount', 'local_capture_amount',
      'surcharge_fee_amount', 'merchant_discount_amount', 'psp_scheme_fee',
      'acquirer_service_fee', 'transaction_service_fee', 'vat_amount', 'wht_amount',
      'rate_local_to_transaction', 'rate_transaction_to_settlement'
    };

    if (integerColumns.contains(columnName)) {
      int? intValue = int.tryParse(valueStr);
      if (intValue != null) {
        return intValue;
      }
      print('Integer conversion failed for $columnName: $valueStr');
      return 0;
    }
    
    if (bigintColumns.contains(columnName)) {
      // Handle bigint values - can be larger than regular int
      int? bigintValue = int.tryParse(valueStr);
      if (bigintValue != null) {
        return bigintValue;
      }
      print('Bigint conversion failed for $columnName: $valueStr');
      return null; // Allow null for optional bigint fields
    }
    
    if (decimalColumns.contains(columnName)) {
      double? doubleValue = double.tryParse(valueStr);
      if (doubleValue != null) {
        return double.parse(doubleValue.toStringAsFixed(2));
      }
      print('Decimal conversion failed for $columnName: $valueStr');
      return 0.0; // Return 0.0 for required decimal fields
    }
    
    // String field length validation based on DB schema
    const stringLengthLimits = {
      'order_number': 100,
      'original_order_number': 100,
      'transaction_currency': 3,
      'merchant_settlement_currency': 3,
      'brand_settlement_currency': 3,
      'reconciliation_flag': 20,
      'transaction_type': 20,
      'psp_name': 50,
      'payment_brand': 50,
      'card_number': 20,
      'crossborder_flag': 20,
      'group_id': 20,
      'group_name': 100,
      'merchant_id': 50,
      'merchant_name': 100,
      'store_id': 50,
      'store_name': 100,
      'terminal_id': 50,
      'source_filename': 255,
      'merchant_nation': 10,
      'merchant_city': 100,
      'api_type': 50,
      'api_code': 50, // Added this line
      'payment_method_variant': 100,
      'funding_type': 20,
      'product_id': 50,
      'product_type_id': 50,
      'issuer_country': 10,
      'merchant_order_reference': 100,
      'system_transaction_id': 100,
      'original_system_transaction_id': 100,
      'merchant_local_currency': 3,
      'user_billing_currency': 3,
      'mdr_rules': 100,
      'eci': 10,
      'transaction_initiation_mode': 50,
      'linkpay_order_id': 100,
      'transaction_status': 50,
      'system_result_code': 20,
      'psp_result_code': 20,
      'settlement_account_name': 200,
      'settlement_account_number': 100,
    };
    
    // Truncate strings that are too long
    if (stringLengthLimits.containsKey(columnName)) {
      int maxLength = stringLengthLimits[columnName]!;
      if (valueStr.length > maxLength) {
        String truncated = valueStr.substring(0, maxLength);
        print('String truncated for $columnName: ${valueStr.length} -> $maxLength chars');
        return truncated;
      }
    }
    
    // Enum validation with database-appropriate values
    if (columnName == 'reconciliation_flag') {
      const validValues = ['Matched', 'Unmatched', 'Pending', 'Failed', 'Reconciled'];
      String normalizedValue = valueStr;
      // Map common PSP status values to DB enum values
      switch (valueStr.toLowerCase()) {
        case 'success':
        case 'completed':
        case 'settled':
          normalizedValue = 'Matched';
          break;
        case 'failed':
        case 'error':
          normalizedValue = 'Failed';
          break;
        case 'pending':
        case 'processing':
          normalizedValue = 'Pending';
          break;
        default:
          normalizedValue = validValues.contains(valueStr) ? valueStr : 'Matched';
      }
      return normalizedValue;
    }
    
    if (columnName == 'transaction_type') {
      const validValues = ['PURCHASE', 'REFUND', 'VOID', 'PREAUTH', 'CAPTURE'];
      String upperValue = valueStr.toUpperCase();
      return validValues.contains(upperValue) ? upperValue : 'PURCHASE';
    }
    
    if (columnName == 'crossborder_flag') {
      return (valueStr.toLowerCase() == 'international' || valueStr.toLowerCase() == 'crossborder') 
          ? 'International' : 'Domestic';
    }
    
    // Add specific conversion for api_code
    if (columnName == 'api_code') {
      const validValues = ['STANDARD_API', 'PREMIUM_API', 'CUSTOM_API'];
      String upperValue = valueStr.toUpperCase();
      return validValues.contains(upperValue) ? upperValue : 'STANDARD_API';
    }
    
    return valueStr;
  }

  dynamic _getDefaultValue(String columnName) {
    switch (columnName) {
      case 'company_id':
        return CompanyConfig.getCompanyId();
      case 'crossborder_flag':
        return 'Domestic';
      case 'reconciliation_flag':
        return 'Matched';
      case 'transaction_type':
        return 'PURCHASE';
      case 'funding_type':
        return 'Debit';
      case 'transaction_status':
        return 'Success';
      case 'order_number':
        return '92025082815352484721885';
      case 'original_order_number':
        return '4bc95ee7ce524907a61e311d322b6703';
      // Changed: authorization_code should be null by default (BIGINT in DB)
      case 'authorization_code':
        return null;
      case 'mcc':
        return 744;
      // Changed: terminal_id is now a string, default to null
      case 'terminal_id':
        return null;
      // Updated: These should have realistic default amounts
      case 'transaction_amount':
      case 'merchant_settlement_amount':
      case 'net_merchant_settlement_amount':
        return 0.0; // Changed from -1.0 to 0.0 for valid amounts
      case 'source_filename':
        return _fileName ?? 'manual_upload';
      case 'merchant_nation':
      case 'issuer_country':
        return 'LAO';
      case 'merchant_city':
        return 'Vientiane';
      case 'transaction_initiation_mode':
        return 'manual';
      case 'system_result_code':
        return 'S0000';
      case 'psp_name':
        return 'UnionPay';
      case 'payment_brand':
        return 'UnionPay';
      case 'card_number':
        return '623479******0250';
      case 'group_id':
        return 'LDB001';
      case 'group_name':
        return 'LDB Merchant';
      case 'merchant_id':
        return 'M020HQV00000001';
      case 'merchant_name':
        return 'Tomshop';
      case 'store_id':
        return 'S020HQV00000002';
      case 'store_name':
        return 'TomAuto Settle_02';
      case 'mdr_rules':
        return 'Combination';
      case 'metadata':
        return 'meta';
      case 'api_code': // Added this case
        return 'STANDARD_API';
      case 'transaction_currency':
      case 'merchant_settlement_currency':
      case 'brand_settlement_currency':
      case 'merchant_local_currency':
      case 'user_billing_currency':
        return 'USD';
      case 'system_transaction_id':
        return '95c137158fba48d0a0a6159682896c6e';
      case 'original_system_transaction_id':
        return '45a55959fa504be293c73d1bd0f98314';
      case 'system_transaction_time':
        return '2025-08-28T08:35:24.000Z'; // ISO format for datetime
      // All optional decimal fields default to 0.0
      case 'tips_amount':
      case 'mdr_amount':
      case 'brand_settlement_amount':
      case 'interchange_fee_amount':
      case 'net_brand_settlement_amount':
      case 'merchant_capture_amount':
      case 'user_billing_amount':
      case 'merchant_local_amount':
      case 'local_tips_amount':
      case 'local_surcharge_fee_amount':
      case 'local_capture_amount':
      case 'surcharge_fee_amount':
      case 'merchant_discount_amount':
      case 'psp_scheme_fee':
      case 'acquirer_service_fee':
      case 'transaction_service_fee':
      case 'vat_amount':
      case 'wht_amount':
        return 0.0;
      // Exchange rate fields
      case 'rate_local_to_transaction':
      case 'rate_transaction_to_settlement':
        return 1.0; // Default to 1:1 exchange rate
      // Optional bigint fields
      case 'psp_order_number':
      case 'original_psp_order_number':
        return null;
      // Batch and trace numbers
      case 'batch_number':
        return 1;
      case 'terminal_trace_number':
        return 1;
      // Set transaction_time to current time if not provided
      case 'transaction_time':
        return DateTime.now().toIso8601String();
      default:
        return null;
    }
  }

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
      
      if (token != null && _isTokenExpired(token)) {
        _showSnackBar('Session expired. Please login again and try uploading.', isError: true);
        setState(() { _isUploading = false; });
        return;
      }
      
      final url = AppConfig.api('/api/settlement-details');
      
      for (int i = 0; i < _parsedData!.length; i++) {
        await _uploadSingleRecord(i, url.toString(), token, companyId);
        _updateProgress(i + 1);
      }

      _showUploadResultDialog();
    } catch (e) {
      _showSnackBar('Error uploading data: $e', isError: true);
    } finally {
      setState(() { _isUploading = false; });
    }
  }

  bool _isTokenExpired(String token) {
    try {
      List<String> parts = token.split('.');
      if (parts.length != 3) return true;
      
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      
      String decodedPayload = String.fromCharCodes(base64.decode(payload));
      Map<String, dynamic> payloadMap = jsonDecode(decodedPayload);
      
      int exp = payloadMap['exp'] ?? 0;
      int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      return exp < currentTime;
    } catch (e) {
      return true;
    }
  }

  Future<void> _uploadSingleRecord(int index, String apiUrl, String? token, dynamic companyId) async {
    try {
      Map<String, dynamic> settlementData = Map.from(_parsedData![index]);
      settlementData['company_id'] = companyId;
      
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(settlementData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _successCount++;
      } else {
        _errorCount++;
        try {
          final errorData = jsonDecode(response.body);
          _errorMessages.add('Row ${index + 1}: ${errorData['message'] ?? 'Unknown error'}');
        } catch (e) {
          _errorMessages.add('Row ${index + 1}: HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      _errorCount++;
      _errorMessages.add('Row ${index + 1}: $e');
    }
  }

  void _resetState() {
    setState(() {
      _isParsing = true;
      _parsedData = null;
      _errorMessages.clear();
      _fileType = 'settlement';
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

  void _showSnackBar(String message, {required bool isError}) {
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
            Text('Successful: $_successCount records'),
            Text('Failed: $_errorCount records'),
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
                  'Upload Settlement or PSP File',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Supports both Settlement Details and PSP Reconciliation files',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
      onTap: (_isParsing || _isConverting) ? null : _pickFile,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: 120),
        padding: EdgeInsets.all(8),
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
        child: (_isParsing || _isConverting)
            ? _buildLoadingIndicator(_isConverting ? 'Converting PSP file...' : 'Parsing file...')
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
          _fileType == 'psp' ? Icons.transform : Icons.description,
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
        if (_parsedData != null) ...[
          Text(
            '${_parsedData!.length} records found',
            style: TextStyle(color: Colors.green, fontSize: 12),
          ),
          if (_fileType == 'psp')
            Text(
              '(Converted from PSP format)',
              style: TextStyle(color: Colors.blue, fontSize: 10),
            ),
        ],
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
          'Click to select file',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Settlement Details or PSP Reconciliation',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        SizedBox(height: 2),
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
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _fileType == 'psp' ? Colors.blue[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _fileType == 'psp' ? 'PSP (Converted)' : 'Settlement',
                    style: TextStyle(
                      color: _fileType == 'psp' ? Colors.blue[800] : Colors.green[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
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
        onPressed: (_parsedData == null || _parsedData!.isEmpty || _isUploading || _isConverting) 
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
        title: Text('Settlement Upload'),
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