import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class InventoryDashboard extends StatefulWidget {
  final String? currentTheme;
  final int? companyId;
  final int? userId;
  final int? branchId;
  
  const InventoryDashboard({
    Key? key, 
    this.currentTheme,
    this.companyId,
    this.userId,
    this.branchId
  }) : super(key: key);

  @override
  State<InventoryDashboard> createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboard>
    with TickerProviderStateMixin {
  String? accessToken;
  int? companyId;
  int? userId;
  int? branchId;
  
  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> lowStockItems = [];
  List<Map<String, dynamic>> expiringItems = [];
  Map<String, dynamic> valueReport = {};
  
  // Loading states
  bool isLoading = true;
  bool isRefreshing = false;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // Tab controller
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: 4, vsync: this);
    
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    
    // Get company_id from widget or SharedPreferences
    companyId = widget.companyId ?? prefs.getInt('company_id');
    userId = widget.userId ?? prefs.getInt('user_id');
    branchId = widget.branchId ?? prefs.getInt('branch_id');
    
    if (accessToken != null && companyId != null) {
      _loadDashboardData();
    } else {
      _showErrorSnackBar('Authentication token or company ID not found. Please login again.');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Future.wait([
        _fetchInventoryItems(),
        _fetchLowStockItems(),
        _fetchExpiringItems(),
        _fetchValueReport(),
      ]);
      
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      _showErrorSnackBar('Failed to load dashboard data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Build query parameters including company_id
  String _buildQueryParams(Map<String, dynamic> params) {
    params['company_id'] = companyId.toString();
    
    final queryString = params.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value.toString())}')
        .join('&');
    
    return queryString.isNotEmpty ? '?$queryString' : '';
  }

  Future<void> _fetchInventoryItems() async {
    if (accessToken == null || companyId == null) return;
    
    final queryParams = _buildQueryParams({
      'limit': 50,
      'status': 'ACTIVE',
    });
    
    final response = await http.get(
      AppConfig.api('/api/inventory$queryParams'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(data['data'] ?? data['items'] ?? []);
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    } else {
      _handleHttpError(response, 'fetch inventory items');
    }
  }

  Future<void> _fetchLowStockItems() async {
    if (accessToken == null || companyId == null) return;
    
    final queryParams = _buildQueryParams({});
    
    final response = await http.get(
      AppConfig.api('/api/inventory/reports/low-stock$queryParams'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        lowStockItems = List<Map<String, dynamic>>.from(data['data'] ?? data['items'] ?? []);
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    } else {
      _handleHttpError(response, 'fetch low stock items');
    }
  }

  Future<void> _fetchExpiringItems() async {
    if (accessToken == null || companyId == null) return;
    
    final queryParams = _buildQueryParams({
      'days': 30,
    });
    
    final response = await http.get(
      AppConfig.api('/api/inventory/reports/expiring$queryParams'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        expiringItems = List<Map<String, dynamic>>.from(data['data'] ?? data['items'] ?? []);
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    } else {
      _handleHttpError(response, 'fetch expiring items');
    }
  }

  Future<void> _fetchValueReport() async {
    if (accessToken == null || companyId == null) return;
    
    final queryParams = _buildQueryParams({});
    
    final response = await http.get(
      AppConfig.api('/api/inventory/reports/value$queryParams'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        valueReport = data['data'] ?? data ?? {};
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    } else {
      _handleHttpError(response, 'fetch value report');
    }
  }

  // Fetch inventory by specific filters
  Future<void> _fetchInventoryByFilters({
    String? status,
    String? txntype,
    bool? lowStock,
    int? limit,
    int? offset,
  }) async {
    if (accessToken == null || companyId == null) return;
    
    final queryParams = _buildQueryParams({
      if (status != null) 'status': status,
      if (txntype != null) 'txntype': txntype,
      if (lowStock != null) 'low_stock': lowStock.toString(),
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
      if (userId != null) 'user_id': userId,
      if (branchId != null) 'branch_id': branchId,
    });
    
    final response = await http.get(
      AppConfig.api('/api/inventory$queryParams'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(data['data'] ?? data['items'] ?? []);
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    } else {
      _handleHttpError(response, 'fetch filtered inventory');
    }
  }

  // Fetch inventory by company (explicit endpoint)
  // ignore: unused_element
  Future<void> _fetchInventoryByCompany() async {
    if (accessToken == null || companyId == null) return;
    
    final response = await http.get(
      AppConfig.api('/api/inventory/company/$companyId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(data['data'] ?? data['items'] ?? []);
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    } else {
      _handleHttpError(response, 'fetch company inventory');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isRefreshing = true;
    });
    await _loadDashboardData();
    setState(() {
      isRefreshing = false;
    });
  }

  // ignore: unused_element
  Future<void> _updateStockQuantity(int inventoryId, int newQuantity) async {
    if (accessToken == null || companyId == null) return;
    
    try {
      final updateData = {
        'stock_quantity': newQuantity,
        'company_id': companyId,
        'txntype': 'ADJUSTMENT',
      };
      
      // Add user and branch context if available
      if (userId != null) updateData['user_id'] = userId;
      if (branchId != null) updateData['branch_id'] = branchId;
      
      final response = await http.put(
        AppConfig.api('/api/inventory/$inventoryId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Stock quantity updated successfully');
        _refreshData();
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        _handleHttpError(response, 'update stock quantity');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating stock: $e');
    }
  }

  // New method: Stock movement (better than direct update)
  Future<void> _adjustStock(int inventoryId, int quantity, bool isStockIn, String reason) async {
    if (accessToken == null || companyId == null) return;
    
    try {
      final movementData = {
        if (isStockIn) 'stock_in_quantity': quantity else 'stock_out_quantity': quantity,
        'reason': reason,
        'company_id': companyId,
        'txntype': isStockIn ? 'STOCK_IN' : 'STOCK_OUT',
      };
      
      // Add user and branch context if available
      if (userId != null) movementData['user_id'] = userId;
      if (branchId != null) movementData['branch_id'] = branchId;
      
      final response = await http.put(
        AppConfig.api('/api/inventory/$inventoryId/stock-movement'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(movementData),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Stock ${isStockIn ? 'added' : 'removed'} successfully');
        _refreshData();
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        _handleHttpError(response, 'adjust stock');
      }
    } catch (e) {
      _showErrorSnackBar('Error adjusting stock: $e');
    }
  }

  // New method: Reserve stock
  Future<void> _reserveStock(int inventoryId, int quantity, String reason) async {
    if (accessToken == null || companyId == null) return;
    
    try {
      final reservationData = {
        'quantity': quantity,
        'reason': reason,
        'company_id': companyId,
        'txntype': 'RESERVATION',
      };
      
      if (userId != null) reservationData['reserved_by_user_id'] = userId;
      if (branchId != null) reservationData['reserved_for_branch_id'] = branchId;
      
      final response = await http.put(
        AppConfig.api('/api/inventory/$inventoryId/reserve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(reservationData),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Stock reserved successfully');
        _refreshData();
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        _handleHttpError(response, 'reserve stock');
      }
    } catch (e) {
      _showErrorSnackBar('Error reserving stock: $e');
    }
  }

  // New method: Search by barcode
  Future<Map<String, dynamic>?> _searchByBarcode(String barcode) async {
    if (accessToken == null || companyId == null) return null;
    
    try {
      final response = await http.get(
        AppConfig.api('/api/inventory/barcode/$barcode'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? data;
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('Item with barcode $barcode not found');
      } else {
        _handleHttpError(response, 'search by barcode');
      }
    } catch (e) {
      _showErrorSnackBar('Error searching by barcode: $e');
    }
    return null;
  }

  void _handleAuthError() {
    _showErrorSnackBar('Session expired. Please login again.');
    // Navigate to login page or handle authentication
    // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _handleHttpError(http.Response response, String operation) {
    try {
      final errorData = json.decode(response.body);
      final message = errorData['message'] ?? errorData['error'] ?? 'Unknown error';
      _showErrorSnackBar('Failed to $operation: $message (${response.statusCode})');
    } catch (e) {
      _showErrorSnackBar('Failed to $operation: HTTP ${response.statusCode}');
    }
  }

  double _calculateAverageValue() {
    if (inventoryItems.isEmpty) return 0.0;
    
    double totalValue = 0.0;
    if (valueReport['total_value'] != null) {
      if (valueReport['total_value'] is String) {
        totalValue = double.tryParse(valueReport['total_value']) ?? 0.0;
      } else if (valueReport['total_value'] is num) {
        totalValue = valueReport['total_value'].toDouble();
      }
    }
    
    return totalValue / inventoryItems.length;
  }

  void _showStockUpdateDialog(Map<String, dynamic> item) {
    final TextEditingController quantityController = TextEditingController(
      text: item['stock_quantity'].toString(),
    );
    final TextEditingController reasonController = TextEditingController();
    bool isStockIn = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Update Stock - Product ${item['product_id']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Add Stock'),
                      value: true,
                      groupValue: isStockIn,
                      onChanged: (value) => setState(() => isStockIn = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Remove Stock'),
                      value: false,
                      groupValue: isStockIn,
                      onChanged: (value) => setState(() => isStockIn = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text);
                final reason = reasonController.text.trim();
                if (quantity != null && quantity > 0 && reason.isNotEmpty) {
                  Navigator.pop(context);
                  _adjustStock(item['inventory_id'], quantity, isStockIn, reason);
                } else {
                  _showErrorSnackBar('Please enter valid quantity and reason');
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBarcodeSearchDialog() {
    final TextEditingController barcodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search by Barcode'),
        content: TextField(
          controller: barcodeController,
          decoration: const InputDecoration(
            labelText: 'Barcode',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final barcode = barcodeController.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                final item = await _searchByBarcode(barcode);
                if (item != null) {
                  setState(() {
                    inventoryItems = [item];
                  });
                  _tabController.animateTo(1); // Switch to inventory tab
                }
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Custom Header (replacing AppBar)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                  decoration: BoxDecoration(
                    color: ThemeConfig.getPrimaryColor(widget.currentTheme ?? 'default'),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'IoInventory Dashboard',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (companyId != null)
                                Text(
                                  'Company ID: $companyId',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                                onPressed: _showBarcodeSearchDialog,
                                tooltip: 'Search by Barcode',
                              ),
                              IconButton(
                                icon: isRefreshing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.refresh, color: Colors.white),
                                onPressed: isRefreshing ? null : _refreshData,
                                tooltip: 'Refresh',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Tab Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          labelStyle: const TextStyle(fontSize: 12),
                          unselectedLabelStyle: const TextStyle(fontSize: 12),
                          tabs: const [
                            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
                            Tab(text: 'Inventory', icon: Icon(Icons.inventory, size: 20)),
                            Tab(text: 'Alerts', icon: Icon(Icons.warning, size: 20)),
                            Tab(text: 'Reports', icon: Icon(Icons.analytics, size: 20)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildInventoryTab(),
                      _buildAlertsTab(),
                      _buildReportsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company Info Card
              if (companyId != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.business, size: 32, color: Colors.blue),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company ID: $companyId',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (userId != null) Text('User ID: $userId'),
                            if (branchId != null) Text('Branch ID: $branchId'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Items',
                      inventoryItems.length.toString(),
                      Icons.inventory_2,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Low Stock',
                      lowStockItems.length.toString(),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Expiring Soon',
                      expiringItems.length.toString(),
                      Icons.schedule,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Value',
                      '${_formatCurrency(valueReport['total_value'])} LAK',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Quick Actions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _fetchInventoryByFilters(status: 'ACTIVE'),
                            icon: const Icon(Icons.filter_list),
                            label: const Text('Active Items'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _fetchInventoryByFilters(lowStock: true),
                            icon: const Icon(Icons.warning),
                            label: const Text('Low Stock'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _fetchInventoryByFilters(status: 'RESERVED'),
                            icon: const Icon(Icons.lock),
                            label: const Text('Reserved'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showBarcodeSearchDialog,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan Barcode'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Recent Activity
              const Text(
                'Recent Inventory Items',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRecentItemsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: inventoryItems.isEmpty
          ? const Center(
              child: Text(
                'No inventory items found for this company',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: inventoryItems.length,
              itemBuilder: (context, index) {
                final item = inventoryItems[index];
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _slideController,
                    curve: Interval(
                      index * 0.1,
                      (index * 0.1) + 0.3,
                      curve: Curves.easeOut,
                    ),
                  )),
                  child: _buildInventoryCard(item),
                );
              },
            ),
    );
  }

  Widget _buildAlertsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lowStockItems.isNotEmpty) ...[
              const Text(
                'Low Stock Items',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              ...lowStockItems.map((item) => _buildAlertCard(
                    item,
                    'Low Stock',
                    Colors.orange,
                    Icons.warning,
                  )),
              const SizedBox(height: 24),
            ],
            
            if (expiringItems.isNotEmpty) ...[
              const Text(
                'Expiring Items (Next 30 days)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              ...expiringItems.map((item) => _buildAlertCard(
                    item,
                    'Expiring Soon',
                    Colors.red,
                    Icons.schedule,
                  )),
            ],
            
            if (lowStockItems.isEmpty && expiringItems.isEmpty)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.green,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No alerts at the moment',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company-specific report header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.analytics, size: 32, color: Colors.blue),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Company Inventory Report',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (companyId != null)
                          Text('Company ID: $companyId', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Inventory Value Report',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildReportRow('Total Items', inventoryItems.length.toString()),
                    _buildReportRow('Total Value', '${_formatCurrency(valueReport['total_value'])} LAK'),
                    _buildReportRow('Average Item Value', '${_formatCurrency(_calculateAverageValue())} LAK'),
                    _buildReportRow('Low Stock Items', lowStockItems.length.toString()),
                    _buildReportRow('Expiring Items', expiringItems.length.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Transaction Type Filters
            const Text(
              'Filter by Transaction Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _fetchInventoryByFilters(txntype: 'PURCHASE'),
                  child: const Text('Purchase'),
                ),
                ElevatedButton(
                  onPressed: () => _fetchInventoryByFilters(txntype: 'SALE'),
                  child: const Text('Sale'),
                ),
                ElevatedButton(
                  onPressed: () => _fetchInventoryByFilters(txntype: 'ADJUSTMENT'),
                  child: const Text('Adjustment'),
                ),
                ElevatedButton(
                  onPressed: () => _fetchInventoryByFilters(txntype: 'STOCK_IN'),
                  child: const Text('Stock In'),
                ),
                ElevatedButton(
                  onPressed: () => _fetchInventoryByFilters(txntype: 'STOCK_OUT'),
                  child: const Text('Stock Out'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItemsList() {
    final recentItems = inventoryItems.take(5).toList();
    
    if (recentItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No inventory items found for this company',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return Card(
      child: Column(
        children: recentItems.map((item) => ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(item['status']),
            child: Text(
              item['inventory_id'].toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          title: Text(
            'Product ${item['product_id']}',
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Stock: ${item['stock_quantity']} | Location: ${item['location_id']}',
            overflow: TextOverflow.ellipsis,
          ),
          trailing: SizedBox(
            width: 80,
            child: Text(
              '${_formatCurrency(item['unit_price_lak'])} LAK',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Product ${item['product_id']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(item['status']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item['status'] ?? 'UNKNOWN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Company and context info
            if (item['company_id'] != null)
              Text(
                'Company: ${item['company_id']} | Barcode: ${item['barcode'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stock: ${item['stock_quantity']}'),
                      Text('Reserved: ${item['reserved_quantity'] ?? 0}'),
                      Text('Min Stock: ${item['minimum_stock'] ?? 'N/A'}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location: ${item['location_id'] ?? 'N/A'}'),
                      Text('Store: ${item['store_id'] ?? 'N/A'}'),
                      Text('Batch: ${item['batch_number'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ],
            ),
            if (item['expire_date'] != null) ...[
              const SizedBox(height: 4),
              Text('Expires: ${item['expire_date']}'),
            ],
            const SizedBox(height: 8),
            
            // Price information (both currencies if available)
            if (item['unit_price_lak'] != null || item['unit_price_thb'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item['unit_price_lak'] != null)
                    Text('Unit Price: ${_formatCurrency(item['unit_price_lak'])} LAK'),
                  if (item['unit_price_thb'] != null)
                    Text('Unit Price: ${_formatCurrency(item['unit_price_thb'])} THB'),
                  if (item['cost_price_lak'] != null)
                    Text('Cost Price: ${_formatCurrency(item['cost_price_lak'])} LAK'),
                ],
              ),
            const SizedBox(height: 8),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _reserveStock(
                    item['inventory_id'], 
                    1, 
                    'Manual reservation from dashboard'
                  ),
                  icon: const Icon(Icons.lock, size: 16),
                  label: const Text('Reserve'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showStockUpdateDialog(item),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> item, String alertType, Color color, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('Product ${item['product_id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${item['stock_quantity']}'),
            if (item['company_id'] != null)
              Text('Company: ${item['company_id']}'),
            if (alertType == 'Low Stock' && item['minimum_stock'] != null)
              Text('Minimum Required: ${item['minimum_stock']}'),
            if (alertType == 'Expiring Soon' && item['expire_date'] != null)
              Text('Expires: ${item['expire_date']}'),
          ],
        ),
        trailing: SizedBox(
          width: 70,
          child: ElevatedButton(
            onPressed: () => _showStockUpdateDialog(item),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('Action'),
          ),
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'INACTIVE':
        return Colors.grey;
      case 'EXPIRED':
        return Colors.red;
      case 'RESERVED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(dynamic value) {
    double numValue;
    
    if (value == null) {
      numValue = 0.0;
    } else if (value is String) {
      numValue = double.tryParse(value) ?? 0.0;
    } else if (value is num) {
      numValue = value.toDouble();
    } else {
      numValue = 0.0;
    }
    
    return numValue.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}