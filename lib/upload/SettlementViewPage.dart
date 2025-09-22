
            import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SettlementViewPage extends StatefulWidget {
  const SettlementViewPage({Key? key}) : super(key: key);

  @override
  State<SettlementViewPage> createState() => _SettlementViewPageState();
}

class _SettlementViewPageState extends State<SettlementViewPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _settlements = [];
  List<Map<String, dynamic>> _filteredSettlements = [];
  Set<String> _selectedItems = {};
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _errorMessage = '';
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _selectedTransactionType = 'All';
  String _selectedCurrency = 'All';
  String _selectedStatus = 'All';
  DateTimeRange? _dateRange;
  
  // Animation
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 15;
  // ignore: unused_field
  int _totalCount = 0;
  
  // Summary data
  Map<String, double> _summaryData = {};
  
  // Auto-refresh
  Timer? _refreshTimer;
  bool _autoRefresh = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
    _fetchSettlements();
    _loadAutoRefreshPreference();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    _fadeController.forward();
    _slideController.forward();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _loadAutoRefreshPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoRefresh = prefs.getBool('settlement_auto_refresh') ?? false;
    });
    if (_autoRefresh) {
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (mounted) _fetchSettlements(isRefresh: true);
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  void _toggleAutoRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoRefresh = !_autoRefresh;
    });
    await prefs.setBool('settlement_auto_refresh', _autoRefresh);
    
    if (_autoRefresh) {
      _startAutoRefresh();
      _showSnackBar('Auto-refresh enabled (every 5 minutes)', Colors.green);
    } else {
      _stopAutoRefresh();
      _showSnackBar('Auto-refresh disabled', Colors.orange);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchSettlements({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final url = AppConfig.api('/api/settlement-details');

      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            _settlements = List<Map<String, dynamic>>.from(responseData['data']);
            _totalCount = responseData['count'] ?? _settlements.length;
            _filteredSettlements = List.from(_settlements);
          });
          _calculateSummaryData();
          _applyFilters();
        } else {
          throw Exception(responseData['message'] ?? 'Failed to fetch data');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!isRefresh) {
        setState(() {
          _errorMessage = e.toString();
        });
      } else {
        _showSnackBar('Refresh failed: ${e.toString()}', Colors.red);
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _calculateSummaryData() {
    double totalAmount = 0;
    double totalSettlement = 0;
    int purchaseCount = 0;
    int refundCount = 0;
    
    for (var settlement in _filteredSettlements) {
      double amount = double.tryParse(settlement['transaction_amount']?.toString() ?? '0') ?? 0;
      double settlementAmount = double.tryParse(settlement['merchant_settlement_amount']?.toString() ?? '0') ?? 0;
      
      totalAmount += amount;
      totalSettlement += settlementAmount;
      
      if (settlement['transaction_type'] == 'PURCHASE') {
        purchaseCount++;
      } else if (settlement['transaction_type'] == 'REFUND') {
        refundCount++;
      }
    }
    
    setState(() {
      _summaryData = {
        'totalAmount': totalAmount,
        'totalSettlement': totalSettlement,
        'purchaseCount': purchaseCount.toDouble(),
        'refundCount': refundCount.toDouble(),
        'totalCount': _filteredSettlements.length.toDouble(),
      };
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_settlements);
    
    if (_searchController.text.isNotEmpty) {
      String query = _searchController.text.toLowerCase();
      filtered = filtered.where((settlement) {
        return settlement['order_number']?.toString().toLowerCase().contains(query) == true ||
               settlement['merchant_name']?.toString().toLowerCase().contains(query) == true ||
               settlement['card_number']?.toString().toLowerCase().contains(query) == true ||
               settlement['group_name']?.toString().toLowerCase().contains(query) == true;
      }).toList();
    }
    
    if (_selectedTransactionType != 'All') {
      filtered = filtered.where((settlement) {
        return settlement['transaction_type'] == _selectedTransactionType;
      }).toList();
    }
    
    if (_selectedCurrency != 'All') {
      filtered = filtered.where((settlement) {
        return settlement['transaction_currency'] == _selectedCurrency;
      }).toList();
    }

    if (_selectedStatus != 'All') {
      filtered = filtered.where((settlement) {
        return settlement['reconciliation_flag'] == _selectedStatus;
      }).toList();
    }
    
    if (_dateRange != null) {
      filtered = filtered.where((settlement) {
        try {
          DateTime transactionTime = DateTime.parse(settlement['transaction_time']);
          return transactionTime.isAfter(_dateRange!.start.subtract(Duration(days: 1))) &&
                 transactionTime.isBefore(_dateRange!.end.add(Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }
    
    setState(() {
      _filteredSettlements = filtered;
      _currentPage = 1;
      _selectedItems.clear();
    });
    _calculateSummaryData();
  }

  // Bulk operations
  void _selectAll() {
    setState(() {
      if (_selectedItems.length == _getPaginatedData().length) {
        _selectedItems.clear();
      } else {
        _selectedItems = _getPaginatedData().map((item) => item['id'].toString()).toSet();
      }
    });
  }

  void _bulkExport() async {
    if (_selectedItems.isEmpty) {
      _showSnackBar('Please select items to export', Colors.orange);
      return;
    }
    
    List<Map<String, dynamic>> selectedData = _filteredSettlements
        .where((item) => _selectedItems.contains(item['id'].toString()))
        .toList();
    
    await _exportToCSV(selectedData, 'selected_settlements');
  }

  // Export functionality - simplified without external dependencies
  Future<void> _exportToCSV(List<Map<String, dynamic>> data, String filename) async {
    try {
      // Create CSV content manually
      List<String> csvLines = [];
      
      // Headers
      csvLines.add([
        'Order Number',
        'Transaction Time',
        'Transaction Type',
        'Transaction Amount',
        'Currency',
        'Merchant Name',
        'Store Name',
        'Card Number',
        'PSP Name',
        'Authorization Code',
        'Settlement Amount',
        'Net Settlement',
        'Status',
        'Terminal ID',
        'Batch Number'
      ].map((e) => '"$e"').join(','));

      // Data rows
      for (var settlement in data) {
        csvLines.add([
          settlement['order_number']?.toString() ?? '',
          settlement['transaction_time']?.toString() ?? '',
          settlement['transaction_type']?.toString() ?? '',
          settlement['transaction_amount']?.toString() ?? '',
          settlement['transaction_currency']?.toString() ?? '',
          settlement['merchant_name']?.toString() ?? '',
          settlement['store_name']?.toString() ?? '',
          settlement['card_number']?.toString() ?? '',
          settlement['psp_name']?.toString() ?? '',
          settlement['authorization_code']?.toString() ?? '',
          settlement['merchant_settlement_amount']?.toString() ?? '',
          settlement['net_merchant_settlement_amount']?.toString() ?? '',
          settlement['reconciliation_flag']?.toString() ?? '',
          settlement['terminal_id']?.toString() ?? '',
          settlement['batch_number']?.toString() ?? ''
        ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','));
      }

      String csvContent = csvLines.join('\n');
      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String finalFilename = '${filename}_$timestamp.csv';
      
      // Show export dialog with CSV content
      _showExportDialog(csvContent, finalFilename);
      
      _showSnackBar('Export completed successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Export failed: $e', Colors.red);
    }
  }

  void _showExportDialog(String csvContent, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_download, color: ThemeConfig.getPrimaryColor(currentTheme)),
            SizedBox(width: 8),
            Text('Export Settlement Data'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File: $filename',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
              Text(
                'CSV Data Preview:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.maxFinite,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csvContent.length > 1000 
                          ? '${csvContent.substring(0, 1000)}...\n\n[Content truncated for preview]'
                          : csvContent,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Copy the data and save it as a .csv file to import into spreadsheet applications.',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              Navigator.of(context).pop();
              _showSnackBar('CSV data copied to clipboard', Colors.green);
            },
            icon: Icon(Icons.copy, size: 16),
            label: Text('Copy to Clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getPaginatedData() {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > _filteredSettlements.length) {
      endIndex = _filteredSettlements.length;
    }
    return _filteredSettlements.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredSettlements.length / _itemsPerPage).ceil();

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '-';
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd\nHH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatAmount(dynamic amount, String? currency) {
    if (amount == null) return '-';
    currency = currency ?? 'USD';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    return '${currency}\n${value.toStringAsFixed(2)}';
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 800;
          
          if (isWide) {
            return Row(
              children: [
                Expanded(child: _buildSummaryCard('Total Transactions', _summaryData['totalCount']?.toInt().toString() ?? '0', Icons.receipt_long, Colors.blue)),
                SizedBox(width: 12),
                Expanded(child: _buildSummaryCard('Total Amount', 'USD ${(_summaryData['totalAmount'] ?? 0).toStringAsFixed(2)}', Icons.attach_money, Colors.green)),
                SizedBox(width: 12),
                Expanded(child: _buildSummaryCard('Purchases', _summaryData['purchaseCount']?.toInt().toString() ?? '0', Icons.shopping_cart, Colors.orange)),
                SizedBox(width: 12),
                Expanded(child: _buildSummaryCard('Refunds', _summaryData['refundCount']?.toInt().toString() ?? '0', Icons.refresh, Colors.red)),
              ],
            );
          } else {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Total Transactions', _summaryData['totalCount']?.toInt().toString() ?? '0', Icons.receipt_long, Colors.blue)),
                    SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Total Amount', 'USD ${(_summaryData['totalAmount'] ?? 0).toStringAsFixed(2)}', Icons.attach_money, Colors.green)),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Purchases', _summaryData['purchaseCount']?.toInt().toString() ?? '0', Icons.shopping_cart, Colors.orange)),
                    SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Refunds', _summaryData['refundCount']?.toInt().toString() ?? '0', Icons.refresh, Colors.red)),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by order, merchant, card...',
              prefixIcon: Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (value) => _applyFilters(),
          ),
          
          SizedBox(height: 12),
          
          // Responsive filters layout
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 700;
              
              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: _buildTypeFilter()),
                    SizedBox(width: 8),
                    Expanded(child: _buildCurrencyFilter()),
                    SizedBox(width: 8),
                    Expanded(child: _buildStatusFilter()),
                    SizedBox(width: 8),
                    _buildDateFilter(),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTypeFilter()),
                        SizedBox(width: 8),
                        Expanded(child: _buildCurrencyFilter()),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildStatusFilter()),
                        SizedBox(width: 8),
                        Expanded(child: _buildDateFilter()),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          
          // Active filters chips
          if (_searchController.text.isNotEmpty || _selectedTransactionType != 'All' || _selectedCurrency != 'All' || _selectedStatus != 'All' || _dateRange != null)
            Container(
              margin: EdgeInsets.only(top: 12),
              width: double.infinity,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (_searchController.text.isNotEmpty)
                    _buildFilterChip(
                      'Search: ${_searchController.text}',
                      () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    ),
                  if (_selectedTransactionType != 'All')
                    _buildFilterChip(
                      _selectedTransactionType,
                      () {
                        setState(() => _selectedTransactionType = 'All');
                        _applyFilters();
                      },
                    ),
                  if (_selectedCurrency != 'All')
                    _buildFilterChip(
                      _selectedCurrency,
                      () {
                        setState(() => _selectedCurrency = 'All');
                        _applyFilters();
                      },
                    ),
                  if (_selectedStatus != 'All')
                    _buildFilterChip(
                      _selectedStatus,
                      () {
                        setState(() => _selectedStatus = 'All');
                        _applyFilters();
                      },
                    ),
                  if (_dateRange != null)
                    _buildFilterChip(
                      '${DateFormat('MMM dd').format(_dateRange!.start)}-${DateFormat('MMM dd').format(_dateRange!.end)}',
                      () {
                        setState(() => _dateRange = null);
                        _applyFilters();
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      height: 40,
      child: DropdownButtonFormField<String>(
        value: _selectedTransactionType,
        decoration: InputDecoration(
          labelText: 'Type',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          isDense: true,
        ),
        items: ['All', 'PURCHASE', 'REFUND', 'REVERSAL'].map((type) {
          return DropdownMenuItem(value: type, child: Text(type, style: TextStyle(fontSize: 12)));
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedTransactionType = value!);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildCurrencyFilter() {
    return Container(
      height: 40,
      child: DropdownButtonFormField<String>(
        value: _selectedCurrency,
        decoration: InputDecoration(
          labelText: 'Currency',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          isDense: true,
        ),
        items: ['All', 'USD', 'THB', 'EUR', 'GBP', 'LAK'].map((currency) {
          return DropdownMenuItem(value: currency, child: Text(currency, style: TextStyle(fontSize: 12)));
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedCurrency = value!);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 40,
      child: DropdownButtonFormField<String>(
        value: _selectedStatus,
        decoration: InputDecoration(
          labelText: 'Status',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          isDense: true,
        ),
        items: ['All', 'Matched', 'Unmatched', 'Pending'].map((status) {
          return DropdownMenuItem(value: status, child: Text(status, style: TextStyle(fontSize: 12)));
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedStatus = value!);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: () async {
          DateTimeRange? picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(Duration(days: 365)),
            initialDateRange: _dateRange,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setState(() => _dateRange = picked);
            _applyFilters();
          }
        },
        icon: Icon(Icons.date_range, size: 16),
        label: Text(_dateRange != null ? 'Selected' : 'Date', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: _dateRange != null 
              ? ThemeConfig.getPrimaryColor(currentTheme) 
              : null,
          foregroundColor: _dateRange != null 
              ? Colors.white 
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: ThemeConfig.getPrimaryColor(currentTheme),
        ),
      ),
      deleteIcon: Icon(
        Icons.close,
        size: 16,
        color: ThemeConfig.getPrimaryColor(currentTheme),
      ),
      onDeleted: onDeleted,
      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
      side: BorderSide(
        color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
        width: 1,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Bulk selection
          if (_selectedItems.isNotEmpty) ...[
            Chip(
              label: Text('${_selectedItems.length} selected'),
              deleteIcon: Icon(Icons.clear, size: 18),
              onDeleted: () => setState(() => _selectedItems.clear()),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _bulkExport,
              icon: Icon(Icons.file_download, size: 16),
              label: Text('Export Selected'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(width: 8),
          ],
          
          // Select all button
          TextButton.icon(
            onPressed: _selectAll,
            icon: Icon(_selectedItems.length == _getPaginatedData().length ? Icons.deselect : Icons.select_all, size: 16),
            label: Text(_selectedItems.length == _getPaginatedData().length ? 'Deselect All' : 'Select All'),
          ),
          
          Spacer(),
          
          // Export all button
          OutlinedButton.icon(
            onPressed: () => _exportToCSV(_filteredSettlements, 'all_settlements'),
            icon: Icon(Icons.download, size: 16),
            label: Text('Export All'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTable() {
    if (_isLoading) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: ThemeConfig.getPrimaryColor(currentTheme)),
              SizedBox(height: 16),
              Text('Loading settlements...'),
            ],
          ),
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Error loading settlements:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(_errorMessage, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchSettlements,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_filteredSettlements.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No settlements found', style: TextStyle(fontSize: 18)),
              Text('Try adjusting your search or filters'),
            ],
          ),
        ),
      );
    }
    
    List<Map<String, dynamic>> paginatedData = _getPaginatedData();
    
    return Expanded(
      child: Column(
        children: [
          // Action bar
          _buildActionBar(),
          
          // Results info
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Showing ${(_currentPage - 1) * _itemsPerPage + 1}-${(_currentPage - 1) * _itemsPerPage + paginatedData.length} of ${_filteredSettlements.length} transactions',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Spacer(),
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          
          // Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: 1500, // Increased width for selection column
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 8,
                    dataRowHeight: 56,
                    headingRowHeight: 48,
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
                    columns: [
                      // Selection column
                      DataColumn(
                        label: Container(
                          width: 30,
                          child: Checkbox(
                            value: _selectedItems.length == paginatedData.length && paginatedData.isNotEmpty,
                            tristate: true,
                            onChanged: (_) => _selectAll(),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 100,
                          child: Text('Order #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 80,
                          child: Text('Date/Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 70,
                          child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 80,
                          child: Text('Billing Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Container(
                          width: 80,
                          child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Container(
                          width: 150,
                          child: Text('Merchant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 120,
                          child: Text('Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 100,
                          child: Text('PSP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 90,
                          child: Text('Settlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Container(
                          width: 80,
                          child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 100,
                          child: Text('Terminal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      DataColumn(
                        label: Container(
                          width: 70,
                          child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                    rows: paginatedData.map((settlement) => DataRow(
                      selected: _selectedItems.contains(settlement['id'].toString()),
                      onSelectChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedItems.add(settlement['id'].toString());
                          } else {
                            _selectedItems.remove(settlement['id'].toString());
                          }
                        });
                      },
                      cells: [
                        // Selection checkbox
                        DataCell(
                          Container(
                            width: 30,
                            child: Checkbox(
                              value: _selectedItems.contains(settlement['id'].toString()),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedItems.add(settlement['id'].toString());
                                  } else {
                                    _selectedItems.remove(settlement['id'].toString());
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        
                        // Order Number
                        DataCell(
                          Container(
                            width: 100,
                            child: Text(
                              settlement['order_number']?.toString() ?? '',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        
                        // Date/Time
                        DataCell(
                          Container(
                            width: 80,
                            child: Text(
                              _formatDateTime(settlement['transaction_time']),
                              style: TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        
                        // Transaction Type
                        DataCell(
                          Container(
                            width: 70,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: settlement['transaction_type'] == 'PURCHASE' 
                                    ? Colors.green[100] 
                                    : settlement['transaction_type'] == 'REFUND' 
                                        ? Colors.orange[100] 
                                        : Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                settlement['transaction_type'] ?? '',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: settlement['transaction_type'] == 'PURCHASE' 
                                      ? Colors.green[800] 
                                      : settlement['transaction_type'] == 'REFUND' 
                                          ? Colors.orange[800] 
                                          : Colors.blue[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),

                        // Transaction Amount
                        DataCell(
                          Container(
                            width: 80,
                            child: Text(
                              _formatAmount(settlement['user_billing_amount'], settlement['user_billing_currency']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: ThemeConfig.getPrimaryColor(currentTheme),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        
                        // Transaction Amount
                        DataCell(
                          Container(
                            width: 80,
                            child: Text(
                              _formatAmount(settlement['transaction_amount'], settlement['transaction_currency']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: ThemeConfig.getPrimaryColor(currentTheme),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        
                        

                        // Merchant Info
                        DataCell(
                          Container(
                            width: 150,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  settlement['merchant_name'] ?? '',
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  settlement['store_name'] ?? '',
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Card Number
                        DataCell(
                          Container(
                            width: 120,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  settlement['card_number'] ?? '',
                                  style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                ),
                                Text(
                                  settlement['payment_brand'] ?? '',
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // PSP Info
                        DataCell(
                          Container(
                            width: 100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  settlement['psp_name'] ?? '',
                                  style: TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Auth: ${settlement['authorization_code'] ?? ''}',
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Settlement Amount
                        DataCell(
                          Container(
                            width: 90,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatAmount(settlement['merchant_settlement_amount'], settlement['merchant_settlement_currency']),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  'Net: ${_formatAmount(settlement['net_merchant_settlement_amount'], settlement['merchant_settlement_currency'])}',
                                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Status
                        DataCell(
                          Container(
                            width: 80,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: settlement['crossborder_flag'] == 'Domestic' ? Colors.blue[100] : Colors.orange[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    settlement['crossborder_flag'] ?? '',
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  settlement['reconciliation_flag'] ?? '',
                                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Terminal Info
                        DataCell(
                          Container(
                            width: 100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Terminal: ${settlement['terminal_id'] ?? ''}',
                                  style: TextStyle(fontSize: 9),
                                ),
                                Text(
                                  'Batch: ${settlement['batch_number'] ?? ''}',
                                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                                ),
                                Text(
                                  'Trace: ${settlement['terminal_trace_number'] ?? ''}',
                                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Actions
                        DataCell(
                          Container(
                            width: 70,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.visibility, size: 16),
                                  onPressed: () => _showTransactionDetails(settlement),
                                  tooltip: 'View Details',
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                                ),
                                IconButton(
                                  icon: Icon(Icons.copy, size: 16),
                                  onPressed: () => _copyTransactionId(settlement['order_number']?.toString() ?? ''),
                                  tooltip: 'Copy Order',
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
          
          // Pagination controls
          if (_totalPages > 1) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // First page button
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage = 1) : null,
            icon: Icon(Icons.first_page),
            tooltip: 'First Page',
            style: IconButton.styleFrom(
              backgroundColor: _currentPage > 1 ? null : Colors.grey[100],
            ),
          ),
          
          // Previous page button
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: Icon(Icons.chevron_left),
            tooltip: 'Previous Page',
            style: IconButton.styleFrom(
              backgroundColor: _currentPage > 1 ? null : Colors.grey[100],
            ),
          ),
          
          SizedBox(width: 8),
          
          // Page numbers
          ...List.generate(
            _totalPages > 7 ? 7 : _totalPages,
            (index) {
              int page;
              if (_totalPages <= 7) {
                page = index + 1;
              } else if (_currentPage <= 4) {
                page = index + 1;
              } else if (_currentPage >= _totalPages - 3) {
                page = _totalPages - 6 + index;
              } else {
                page = _currentPage - 3 + index;
              }
              
              if (page < 1 || page > _totalPages) return SizedBox.shrink();
              
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => setState(() => _currentPage = page),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: page == _currentPage 
                          ? ThemeConfig.getPrimaryColor(currentTheme) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: page == _currentPage 
                            ? ThemeConfig.getPrimaryColor(currentTheme) 
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      page.toString(),
                      style: TextStyle(
                        fontWeight: page == _currentPage ? FontWeight.bold : FontWeight.normal,
                        color: page == _currentPage 
                            ? Colors.white 
                            : Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          SizedBox(width: 8),
          
          // Next page button
          IconButton(
            onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
            icon: Icon(Icons.chevron_right),
            tooltip: 'Next Page',
            style: IconButton.styleFrom(
              backgroundColor: _currentPage < _totalPages ? null : Colors.grey[100],
            ),
          ),
          
          // Last page button
          IconButton(
            onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage = _totalPages) : null,
            icon: Icon(Icons.last_page),
            tooltip: 'Last Page',
            style: IconButton.styleFrom(
              backgroundColor: _currentPage < _totalPages ? null : Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> settlement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction Details - Order #${settlement['order_number'] ?? ''}'),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailSection('Transaction Information', [
                  _buildDetailRow('PSP Order Number', settlement['psp_order_number']?.toString() ?? '-'),
                  _buildDetailRow('Transaction Time', _formatDateTime(settlement['transaction_time'])),
                  _buildDetailRow('Payment Time', _formatDateTime(settlement['payment_time'])),
                  _buildDetailRow('Transaction Type', settlement['transaction_type']?.toString() ?? '-'),
                  _buildDetailRow('Transaction Amount', _formatAmount(settlement['transaction_amount'], settlement['transaction_currency'])),
                  _buildDetailRow('Billing Amount', _formatAmount(settlement['user_billing_amount'], settlement['user_billing_currency'])),
                ]),
                
                SizedBox(height: 16),
                
                _buildDetailSection('Payment Information', [
                  _buildDetailRow('PSP Name', settlement['psp_name']?.toString() ?? '-'),
                  _buildDetailRow('Payment Brand', settlement['payment_brand']?.toString() ?? '-'),
                  _buildDetailRow('Card Number', settlement['card_number']?.toString() ?? '-'),
                  _buildDetailRow('Authorization Code', settlement['authorization_code']?.toString() ?? '-'),
                  _buildDetailRow('MCC', settlement['mcc']?.toString() ?? '-'),
                  _buildDetailRow('Crossborder Flag', settlement['crossborder_flag']?.toString() ?? '-'),
                ]),
                
                SizedBox(height: 16),
                
                _buildDetailSection('Settlement Information', [
                  _buildDetailRow('Merchant Settlement', _formatAmount(settlement['merchant_settlement_amount'], settlement['merchant_settlement_currency'])),
                  _buildDetailRow('Net Merchant Settlement', _formatAmount(settlement['net_merchant_settlement_amount'], settlement['merchant_settlement_currency'])),
                  _buildDetailRow('Reconciliation Flag', settlement['reconciliation_flag']?.toString() ?? '-'),
                ]),
                
                SizedBox(height: 16),
                
                _buildDetailSection('Merchant & Terminal Details', [
                  _buildDetailRow('Group', '${settlement['group_name'] ?? ''} (${settlement['group_id'] ?? ''})'),
                  _buildDetailRow('Merchant', '${settlement['merchant_name'] ?? ''} (${settlement['merchant_id'] ?? ''})'),
                  _buildDetailRow('Store', '${settlement['store_name'] ?? ''} (${settlement['store_id'] ?? ''})'),
                  _buildDetailRow('Terminal ID', settlement['terminal_id']?.toString() ?? '-'),
                  _buildDetailRow('Terminal Settlement Time', _formatDateTime(settlement['terminal_settlement_time'])),
                  _buildDetailRow('Batch Number', settlement['batch_number']?.toString() ?? '-'),
                  _buildDetailRow('Terminal Trace Number', settlement['terminal_trace_number']?.toString() ?? '-'),
                ]),
                
                if (settlement['remark'] != null && settlement['remark'].toString().isNotEmpty) ...[
                  SizedBox(height: 16),
                  _buildDetailSection('Additional Information', [
                    _buildDetailRow('Remark', settlement['remark']?.toString() ?? ''),
                  ]),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _exportToCSV([settlement], 'transaction_${settlement['order_number']}');
            },
            icon: Icon(Icons.download, size: 16),
            label: Text('Export This'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
        ),
        SizedBox(height: 8),
        ...details,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label + ':',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  void _copyTransactionId(String orderId) async {
    if (orderId.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: orderId));
    _showSnackBar('Order number $orderId copied to clipboard', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Text('Settlement Details'),
            if (_isRefreshing) ...[
              SizedBox(width: 12),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleAutoRefresh,
            icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
            tooltip: _autoRefresh ? 'Disable Auto-refresh' : 'Enable Auto-refresh',
          ),
          IconButton(
            onPressed: () => _fetchSettlements(isRefresh: true),
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export_all':
                  _exportToCSV(_filteredSettlements, 'all_settlements');
                  break;
                case 'clear_filters':
                  setState(() {
                    _searchController.clear();
                    _selectedTransactionType = 'All';
                    _selectedCurrency = 'All';
                    _selectedStatus = 'All';
                    _dateRange = null;
                  });
                  _applyFilters();
                  break;
                case 'settings':
                  _showSettingsDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export All Data'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_filters',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear All Filters'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildSummaryCards(),
              _buildCompactFilters(),
              _buildCompactTable(),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.view_list),
              title: Text('Items per page'),
              subtitle: Text('$_itemsPerPage items'),
              trailing: DropdownButton<int>(
                value: _itemsPerPage,
                items: [10, 15, 20, 25, 50].map((count) {
                  return DropdownMenuItem(
                    value: count,
                    child: Text(count.toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _itemsPerPage = value!;
                    _currentPage = 1;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ),
            SwitchListTile(
              secondary: Icon(Icons.refresh),
              title: Text('Auto-refresh'),
              subtitle: Text('Refresh data every 5 minutes'),
              value: _autoRefresh,
              onChanged: (value) {
                Navigator.of(context).pop();
                _toggleAutoRefresh();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}