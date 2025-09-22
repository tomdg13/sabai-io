import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
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
  bool _isLoading = false;
  String _errorMessage = '';
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _selectedTransactionType = 'All';
  String _selectedCurrency = 'All';
  DateTimeRange? _dateRange;
  
  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 15;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
    _fetchSettlements();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _fetchSettlements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

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
        } else {
          throw Exception(responseData['message'] ?? 'Failed to fetch data');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_settlements);
    
    if (_searchController.text.isNotEmpty) {
      String query = _searchController.text.toLowerCase();
      filtered = filtered.where((settlement) {
        return settlement['order_number'].toString().toLowerCase().contains(query) ||
               settlement['merchant_name'].toString().toLowerCase().contains(query) ||
               settlement['card_number'].toString().toLowerCase().contains(query) ||
               settlement['group_name'].toString().toLowerCase().contains(query);
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
    
    if (_dateRange != null) {
      filtered = filtered.where((settlement) {
        DateTime transactionTime = DateTime.parse(settlement['transaction_time']);
        return transactionTime.isAfter(_dateRange!.start.subtract(Duration(days: 1))) &&
               transactionTime.isBefore(_dateRange!.end.add(Duration(days: 1)));
      }).toList();
    }
    
    setState(() {
      _filteredSettlements = filtered;
      _currentPage = 1;
    });
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

  String _formatDateTime(String dateTimeStr) {
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd\nHH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatAmount(dynamic amount, String currency) {
    if (amount == null) return '-';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    return '${currency}\n${value.toStringAsFixed(2)}';
  }

  Widget _buildCompactFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
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
          
          // Compact filters row
          Row(
            children: [
              Expanded(
                child: Container(
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
                ),
              ),
              
              SizedBox(width: 8),
              
              Expanded(
                child: Container(
                  height: 40,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      isDense: true,
                    ),
                    items: ['All', 'USD', 'THB', 'EUR', 'GBP'].map((currency) {
                      return DropdownMenuItem(value: currency, child: Text(currency, style: TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCurrency = value!);
                      _applyFilters();
                    },
                  ),
                ),
              ),
              
              SizedBox(width: 8),
              
              Container(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    DateTimeRange? picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setState(() => _dateRange = picked);
                      _applyFilters();
                    }
                  },
                  icon: Icon(Icons.date_range, size: 16),
                  label: Text('Date', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
          
          // Active filters chips
          if (_searchController.text.isNotEmpty || _selectedTransactionType != 'All' || _selectedCurrency != 'All' || _dateRange != null)
            Container(
              margin: EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 4,
                children: [
                  if (_searchController.text.isNotEmpty)
                    Chip(
                      label: Text('Search: ${_searchController.text}', style: TextStyle(fontSize: 10)),
                      onDeleted: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (_selectedTransactionType != 'All')
                    Chip(
                      label: Text(_selectedTransactionType, style: TextStyle(fontSize: 10)),
                      onDeleted: () {
                        setState(() => _selectedTransactionType = 'All');
                        _applyFilters();
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (_selectedCurrency != 'All')
                    Chip(
                      label: Text(_selectedCurrency, style: TextStyle(fontSize: 10)),
                      onDeleted: () {
                        setState(() => _selectedCurrency = 'All');
                        _applyFilters();
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (_dateRange != null)
                    Chip(
                      label: Text('${DateFormat('MMM dd').format(_dateRange!.start)}-${DateFormat('MMM dd').format(_dateRange!.end)}', style: TextStyle(fontSize: 10)),
                      onDeleted: () {
                        setState(() => _dateRange = null);
                        _applyFilters();
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
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
                width: 1400, // Fixed width for better column sizing
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 8,
                    dataRowHeight: 56,
                    headingRowHeight: 48,
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
                    columns: [
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
                      cells: [
                        // Order Number
                        DataCell(
                          Container(
                            width: 100,
                            child: Text(
                              settlement['order_number'].toString(),
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
                                settlement['transaction_type'],
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
                                  settlement['merchant_name'],
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  settlement['store_name'],
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
                                  settlement['card_number'],
                                  style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                ),
                                Text(
                                  settlement['payment_brand'],
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
                                  settlement['psp_name'],
                                  style: TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Auth: ${settlement['authorization_code']}',
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
                                    settlement['crossborder_flag'],
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  settlement['reconciliation_flag'],
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
                                  'Terminal: ${settlement['terminal_id']}',
                                  style: TextStyle(fontSize: 9),
                                ),
                                Text(
                                  'Batch: ${settlement['batch_number']}',
                                  style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                                ),
                                Text(
                                  'Trace: ${settlement['terminal_trace_number']}',
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
                                  onPressed: () => _copyTransactionId(settlement['order_number'].toString()),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: Icon(Icons.chevron_left),
          ),
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
                child: TextButton(
                  onPressed: () => setState(() => _currentPage = page),
                  child: Text(
                    page.toString(),
                    style: TextStyle(
                      fontWeight: page == _currentPage ? FontWeight.bold : FontWeight.normal,
                      color: page == _currentPage ? ThemeConfig.getPrimaryColor(currentTheme) : Colors.grey[600],
                    ),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: Size(32, 32),
                    backgroundColor: page == _currentPage ? ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1) : null,
                  ),
                ),
              );
            },
          ),
          IconButton(
            onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
            icon: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> settlement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction Details - Order #${settlement['order_number']}'),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailSection('Transaction Information', [
                  _buildDetailRow('PSP Order Number', settlement['psp_order_number']),
                  _buildDetailRow('Transaction Time', _formatDateTime(settlement['transaction_time'])),
                  _buildDetailRow('Payment Time', _formatDateTime(settlement['payment_time'])),
                  _buildDetailRow('Transaction Type', settlement['transaction_type']),
                  _buildDetailRow('Transaction Amount', _formatAmount(settlement['transaction_amount'], settlement['transaction_currency'])),
                ]),
                
                SizedBox(height: 16),
                
                _buildDetailSection('Payment Information', [
                  _buildDetailRow('PSP Name', settlement['psp_name']),
                  _buildDetailRow('Payment Brand', settlement['payment_brand']),
                  _buildDetailRow('Card Number', settlement['card_number']),
                  _buildDetailRow('Authorization Code', settlement['authorization_code']),
                  _buildDetailRow('MCC', settlement['mcc'].toString()),
                  _buildDetailRow('Crossborder Flag', settlement['crossborder_flag']),
                ]),
                
                SizedBox(height: 16),
                
                _buildDetailSection('Settlement Information', [
                  _buildDetailRow('Merchant Settlement', _formatAmount(settlement['merchant_settlement_amount'], settlement['merchant_settlement_currency'])),
                  _buildDetailRow('Net Merchant Settlement', _formatAmount(settlement['net_merchant_settlement_amount'], settlement['merchant_settlement_currency'])),
                  _buildDetailRow('Reconciliation Flag', settlement['reconciliation_flag']),
                ]),
                
                SizedBox(height: 16),
                
                _buildDetailSection('Merchant & Terminal Details', [
                  _buildDetailRow('Group', '${settlement['group_name']} (${settlement['group_id']})'),
                  _buildDetailRow('Merchant', '${settlement['merchant_name']} (${settlement['merchant_id']})'),
                  _buildDetailRow('Store', '${settlement['store_name']} (${settlement['store_id']})'),
                  _buildDetailRow('Terminal ID', settlement['terminal_id'].toString()),
                  _buildDetailRow('Terminal Settlement Time', _formatDateTime(settlement['terminal_settlement_time'])),
                  _buildDetailRow('Batch Number', settlement['batch_number'].toString()),
                  _buildDetailRow('Terminal Trace Number', settlement['terminal_trace_number'].toString()),
                ]),
                
                if (settlement['remark'] != null) ...[
                  SizedBox(height: 16),
                  _buildDetailSection('Additional Information', [
                    _buildDetailRow('Remark', settlement['remark']),
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
            child: Text(
              value.toString(),
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  void _copyTransactionId(String orderId) {
    // In a real app, you would use Clipboard.setData
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order number $orderId copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Settlement Details'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchSettlements,
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildCompactFilters(),
            _buildCompactTable(),
          ],
        ),
      ),
    );
  }
}