import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

// Import your config files
// import 'config/app_config.dart';
// import 'config/theme_config.dart';

class InventoryDashboard extends StatefulWidget {
  final String? currentTheme;
  
  const InventoryDashboard({Key? key, this.currentTheme}) : super(key: key);

  @override
  State<InventoryDashboard> createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboard>
    with TickerProviderStateMixin {
  String? accessToken;
  
  // Dashboard data
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
    
    if (accessToken != null) {
      _loadDashboardData();
    } else {
      _showErrorSnackBar('Authentication token not found. Please login again.');
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

  Future<void> _fetchInventoryItems() async {
    if (accessToken == null) return;
    
    final response = await http.get(
      AppConfig.api('/api/inventory?limit=50'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(data['data'] ?? []);
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    }
  }

  Future<void> _fetchLowStockItems() async {
    if (accessToken == null) return;
    
    final response = await http.get(
      AppConfig.api('/api/inventory/reports/low-stock'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        lowStockItems = List<Map<String, dynamic>>.from(data['data'] ?? []);
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    }
  }

  Future<void> _fetchExpiringItems() async {
    if (accessToken == null) return;
    
    final response = await http.get(
      AppConfig.api('/api/inventory/reports/expiring?days=30'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        expiringItems = List<Map<String, dynamic>>.from(data['data'] ?? []);
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
    }
  }

  Future<void> _fetchValueReport() async {
    if (accessToken == null) return;
    
    final response = await http.get(
      AppConfig.api('/api/inventory/reports/value'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        valueReport = data['data'] ?? {};
      });
    } else if (response.statusCode == 401) {
      _handleAuthError();
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

  Future<void> _updateStockQuantity(int inventoryId, int newQuantity) async {
    if (accessToken == null) return;
    
    try {
      final response = await http.put(
        AppConfig.api('/api/inventory/$inventoryId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({'stock_quantity': newQuantity}),
      );

      if (response.statusCode == 200) {
        _showSuccessSnackBar('Stock quantity updated successfully');
        _refreshData();
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        _showErrorSnackBar('Failed to update stock quantity');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating stock: $e');
    }
  }

  void _handleAuthError() {
    _showErrorSnackBar('Session expired. Please login again.');
    // Navigate to login page or handle authentication
    // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
    final TextEditingController controller = TextEditingController(
      text: item['stock_quantity'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock - ${item['product_name'] ?? 'Product ${item['product_id']}'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stock Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(controller.text);
              if (newQuantity != null) {
                Navigator.pop(context);
                _updateStockQuantity(item['inventory_id'], newQuantity);
              }
            },
            child: const Text('Update'),
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
                          const Text(
                            'IoInventory Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
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
                'No inventory items found',
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
    
    return Card(
      child: Column(
        children: recentItems.map((item) => ListTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(item['status']),
            child: Text(
              item['product_id'].toString(),
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
                Text(
                  'Product ${item['product_id']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stock: ${item['stock_quantity']}'),
                      Text('Available: ${item['available_quantity']}'),
                      Text('Min Stock: ${item['minimum_stock']}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location: ${item['location_id']}'),
                      Text('Batch: ${item['batch_number'] ?? 'N/A'}'),
                      Text('Expires: ${item['expire_date'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Unit Price: ${_formatCurrency(item['unit_price_lak'])} LAK',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ElevatedButton.icon(
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
            if (alertType == 'Low Stock')
              Text('Minimum Required: ${item['minimum_stock']}'),
            if (alertType == 'Expiring Soon')
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