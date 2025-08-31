import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/company_config.dart';

class ExpirePage extends StatefulWidget {
  final String? currentTheme;
  final int? companyId;
  final int? userId;
  final int? branchId;
  
  const ExpirePage({
    Key? key, 
    this.currentTheme,
    this.companyId,
    this.userId,
    this.branchId
  }) : super(key: key);

  @override
  State<ExpirePage> createState() => _ExpirePageState();
}

class _ExpirePageState extends State<ExpirePage>
    with TickerProviderStateMixin {
  String? accessToken;
  int? companyId;
  int? userId;
  int? branchId;
  
  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> expiringItems = [];
  List<Map<String, dynamic>> expiredItems = [];
  Map<String, dynamic> valueReport = {};
  
  // Loading states
  bool isLoading = true;
  bool isRefreshing = false;
  
  // Filter state
  String? selectedFilter; // null means show all
  
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

  // Helper method to safely parse string to int
  int? _parseStringToInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> _initializeAuth() async {
    print('🔐 [ExpirePage] Initializing authentication...');
    
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    
    // Debug: Print all stored keys in SharedPreferences
    print('🔍 [DEBUG] All SharedPreferences keys: ${prefs.getKeys()}');
    
    // Try different possible key variations - handle all as strings first, then parse to int
    companyId = widget.companyId ?? 
        CompanyConfig.getCompanyId();
    
    userId = widget.userId ?? 
        _parseStringToInt(prefs.getString('user_id')) ??
        _parseStringToInt(prefs.getString('userId')) ??
        _parseStringToInt(prefs.getString('user'));
        
    branchId = widget.branchId ?? 
        _parseStringToInt(prefs.getString('branch_id')) ??
        _parseStringToInt(prefs.getString('branchId')) ??
        _parseStringToInt(prefs.getString('branch'));
    
    // Debug: Print what we found for each key variation (only string versions to avoid type errors)
    print('🔍 [DEBUG] SharedPreferences values:');
    print('   - companyId (string): ${prefs.getString('companyId')}');
    print('   - company (string): ${prefs.getString('company')}');
    print('   - user_id (string): ${prefs.getString('user_id')}');
    print('   - userId (string): ${prefs.getString('userId')}');
    print('   - user (string): ${prefs.getString('user')}');
    print('   - branch_id (string): ${prefs.getString('branch_id')}');
    print('   - branchId (string): ${prefs.getString('branchId')}');
    print('   - branch (string): ${prefs.getString('branch')}');
    print('🏢 [CompanyConfig] Default Company ID: ${CompanyConfig.getCompanyId()}');
    
    print('🔐 [ExpirePage] Auth Details:');
    print('   - Access Token: ${accessToken != null ? "✅ Present" : "❌ Missing"}');
    print('   - Company ID: $companyId');
    print('   - User ID: $userId');
    print('   - Branch ID: $branchId');
    
    if (accessToken != null && companyId != null) {
      print('✅ [ExpirePage] Auth successful, loading dashboard data...');
      _loadDashboardData();
    } else {
      print('❌ [ExpirePage] Auth failed - missing token or company ID');
      
      // If we have an access token but no company_id, let's try to proceed anyway
      // Some APIs might not require company_id in the URL
      if (accessToken != null && companyId == null) {
        print('⚠️ [ExpirePage] Attempting to continue without company_id...');
        // You might want to try a different API endpoint or ask user for company_id
        _showErrorSnackBar('Company ID not found. Please check your login data.');
      } else {
        _showErrorSnackBar('Authentication token or company ID not found. Please login again.');
      }
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
    print('📊 [ExpirePage] Starting dashboard data load...');
    
    setState(() {
      isLoading = true;
    });

    try {
      print('📊 [ExpirePage] Fetching expiring items...');
      await _fetchExpiringItems();
      
      print('✅ [ExpirePage] Dashboard data loaded successfully');
      print('📊 [ExpirePage] Total expiring items: ${expiringItems.length}');
      
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      print('❌ [ExpirePage] Failed to load dashboard data: $e');
      _showErrorSnackBar('Failed to load dashboard data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
      print('📊 [ExpirePage] Dashboard loading completed (isLoading = false)');
    }
  }

  // Build query parameters including company_id
  // ignore: unused_element
  String _buildQueryParams(Map<String, dynamic> params) {
    params['company_id'] = companyId.toString();
    
    final queryString = params.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value.toString())}')
        .join('&');
    
    return queryString.isNotEmpty ? '?$queryString' : '';
  }

  // Fetch expiring items from your API
  Future<void> _fetchExpiringItems() async {
    if (accessToken == null || companyId == null) {
      print('❌ [API] Cannot fetch expiring items - missing auth or company ID');
      return;
    }
    
    final apiUrl = '/api/inventory/company/$companyId/expire';
    print('🌐 [API] Making request to: $apiUrl');
    print('🌐 [API] Company ID: $companyId');
    print('🌐 [API] Using Bearer token: ${accessToken?.substring(0, 20)}...');
    
    try {
      final response = await http.get(
        AppConfig.api(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('🌐 [API] Response Status Code: ${response.statusCode}');
      print('🌐 [API] Response Headers: ${response.headers}');
      print('🌐 [API] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 [API] Parsed response data: $data');
        
        if (data['status'] == 'success') {
          final items = List<Map<String, dynamic>>.from(data['data'] ?? []);
          setState(() {
            expiringItems = items;
          });
          
          print('✅ [API] Successfully loaded ${items.length} expiring items');
          print('📦 [API] Items data:');
          for (int i = 0; i < items.length; i++) {
            final item = items[i];
            print('   ${i + 1}. ${item['product_name']} - ${item['location']} - Qty: ${item['amount']} - Expire: ${item['expire_date']}');
          }
        } else {
          print('❌ [API] API returned non-success status: ${data['status']}');
          _showErrorSnackBar('Failed to fetch expiring items: ${data['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 401) {
        print('🔐 [API] Authentication error (401) - token may be expired');
        _handleAuthError();
      } else {
        print('❌ [API] HTTP error: ${response.statusCode} - ${response.reasonPhrase}');
        _handleHttpError(response, 'fetch expiring items');
      }
    } catch (e) {
      print('💥 [API] Exception occurred during API call: $e');
      rethrow;
    }
  }

  void _handleAuthError() {
    print('🔐 [Auth] Authentication error detected - session may be expired');
    _showErrorSnackBar('Session expired. Please login again.');
    // Navigate to login page if needed
    // Navigator.pushReplacementNamed(context, '/login');
  }

  void _handleHttpError(http.Response response, String operation) {
    final errorMessage = 'Failed to $operation: ${response.statusCode} - ${response.reasonPhrase}';
    print('❌ [HTTP] Error during $operation: ${response.statusCode} - ${response.reasonPhrase}');
    print('❌ [HTTP] Response body: ${response.body}');
    _showErrorSnackBar(errorMessage);
  }

  void _showErrorSnackBar(String message) {
    print('⚠️ [UI] Showing error message: $message');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    print('🔄 [UI] User initiated refresh');
    setState(() {
      isRefreshing = true;
    });
    
    await _loadDashboardData();
    
    setState(() {
      isRefreshing = false;
    });
    print('🔄 [UI] Refresh completed');
  }

  // Enhanced _getExpirationStatus method
  String _getExpirationStatus(String? expireDate) {
    // Check for null, empty, or common "no expiry" indicators
    if (expireDate == null || 
        expireDate.isEmpty || 
        expireDate.toLowerCase() == 'null' ||
        expireDate.toLowerCase() == 'n/a' ||
        expireDate.toLowerCase() == 'none' ||
        expireDate == '0000-00' ||
        expireDate == '0000-0') {
      return 'No Expiry';
    }
    
    try {
      final parts = expireDate.split('-');
      if (parts.length != 2) return 'No Expiry';
      
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      
      // Additional check for zero or invalid dates
      if (year == 0 || month == 0 || month > 12) {
        return 'No Expiry';
      }
      
      final expiry = DateTime(year, month);
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      
      final difference = expiry.difference(currentMonth).inDays;
      
      if (difference < 0) {
        return 'Expired';
      } else if (difference < 90) { // Less than 3 months
        return 'Expiring Soon';
      } else {
        return 'Good';
      }
    } catch (e) {
      return 'No Expiry'; // Changed from 'Invalid Date' to 'No Expiry'
    }
  }

  // Enhanced color method with better "No Expiry" styling
  Color _getExpirationColor(String status) {
    switch (status.toLowerCase()) {
      case 'good':
        return Colors.green;
      case 'expiring soon':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      case 'no expiry':
        return Colors.blue.shade600; // More prominent blue
      default:
        return Colors.grey;
    }
  }

  // Enhanced icon method
  IconData _getExpirationIcon(String status) {
    switch (status.toLowerCase()) {
      case 'good':
        return Icons.check_circle;
      case 'expiring soon':
        return Icons.warning;
      case 'expired':
        return Icons.error;
      case 'no expiry':
        return Icons.all_inclusive; // or Icons.infinity or Icons.timer_off
      default:
        return Icons.inventory;
    }
  }

  // Enhanced summary cards with always visible filtering layout
  Widget _buildExpirySummaryCards() {
    final totalItems = expiringItems.length;
    final goodCount = expiringItems.where((item) => 
        _getExpirationStatus(item['expire_date']?.toString()) == 'Good').length;
    final expiringSoonCount = expiringItems.where((item) => 
        _getExpirationStatus(item['expire_date']?.toString()) == 'Expiring Soon').length;
    final expiredCount = expiringItems.where((item) => 
        _getExpirationStatus(item['expire_date']?.toString()) == 'Expired').length;
    final noExpiryCount = expiringItems.where((item) => 
        _getExpirationStatus(item['expire_date']?.toString()) == 'No Expiry').length;

    print('📊 [UI] Building summary cards:');
    print('   - Total: $totalItems, Good: $goodCount, Expiring Soon: $expiringSoonCount, Expired: $expiredCount, No Expiry: $noExpiryCount');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _buildAlwaysVisibleFilterableCard(
        totalItems,
        goodCount,
        expiringSoonCount,
        expiredCount,
        noExpiryCount,
      ),
    );
  }

  // Always visible filterable summary card - shows total + clickable detail cards with status display
  Widget _buildAlwaysVisibleFilterableCard(int total, int good, int expiring, int expired, int noExpiry) {
    return FadeTransition(
      opacity: _fadeController,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Main summary row (always visible)
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 32,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory Summary',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$total Total Items',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        // Show selected status
                        if (selectedFilter != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getExpirationColor(selectedFilter!).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _getExpirationColor(selectedFilter!),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getExpirationIcon(selectedFilter!),
                                  size: 14,
                                  color: _getExpirationColor(selectedFilter!),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${selectedFilter!} Status',
                                  style: TextStyle(
                                    color: _getExpirationColor(selectedFilter!),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Show clear button when filtered
                  if (selectedFilter != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.clear,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // Always visible clickable detail cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterableSummaryCard(
                      'Good',
                      good.toString(),
                      Icons.check_circle,
                      Colors.green,
                      'Good',
                    ),
                    const SizedBox(width: 12),
                    _buildFilterableSummaryCard(
                      'Expiring',
                      expiring.toString(),
                      Icons.warning,
                      Colors.orange,
                      'Expiring Soon',
                    ),
                    const SizedBox(width: 12),
                    _buildFilterableSummaryCard(
                      'Expired',
                      expired.toString(),
                      Icons.error,
                      Colors.red,
                      'Expired',
                    ),
                    const SizedBox(width: 12),
                    _buildFilterableSummaryCard(
                      'No Expiry',
                      noExpiry.toString(),
                      Icons.all_inclusive,
                      Colors.blue.shade600,
                      'No Expiry',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Filterable summary card - click to filter the list
  Widget _buildFilterableSummaryCard(String title, String count, IconData icon, Color color, String? filterStatus) {
    final isSelected = selectedFilter == filterStatus;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle filter: if already selected, show all; otherwise apply filter
          selectedFilter = isSelected ? null : filterStatus;
        });
        print('🔍 [Filter] Applied filter: ${selectedFilter ?? "All"}');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: isSelected ? 6 : 2,
          color: isSelected ? color.withOpacity(0.1) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon, 
                  size: 20, 
                  color: isSelected ? color : color,
                ),
                const SizedBox(height: 4),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? color : Colors.grey,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced trailing widget for list items with better "No Expiry" button
  Widget _buildExpirationStatusButton(String status) {
    final color = _getExpirationColor(status);
    final isNoExpiry = status.toLowerCase() == 'no expiry';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color,
          width: isNoExpiry ? 2 : 1, // Thicker border for "No Expiry"
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getExpirationIcon(status),
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isNoExpiry ? FontWeight.bold : FontWeight.w600, // Bold for "No Expiry"
            ),
          ),
        ],
      ),
    );
  }

  // Updated list item builder with filtering functionality
  Widget _buildExpiryItemsList() {
    // Filter items based on selected filter
    List<Map<String, dynamic>> filteredItems = expiringItems.where((item) {
      if (selectedFilter == null) return true; // Show all items
      final itemStatus = _getExpirationStatus(item['expire_date']?.toString());
      return itemStatus == selectedFilter;
    }).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedFilter == null ? Icons.inventory_2 : _getExpirationIcon(selectedFilter!),
              size: 64, 
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              selectedFilter == null 
                ? 'No expiry items found'
                : 'No ${selectedFilter!.toLowerCase()} items found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (selectedFilter != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedFilter = null;
                  });
                },
                child: const Text('Show All Items'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter indicator
        if (selectedFilter != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getExpirationColor(selectedFilter!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getExpirationColor(selectedFilter!),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getExpirationIcon(selectedFilter!),
                  size: 16,
                  color: _getExpirationColor(selectedFilter!),
                ),
                const SizedBox(width: 8),
                Text(
                  'Showing ${selectedFilter!} Items (${filteredItems.length})',
                  style: TextStyle(
                    color: _getExpirationColor(selectedFilter!),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedFilter = null;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: _getExpirationColor(selectedFilter!),
                  ),
                ),
              ],
            ),
          ),
        // Filtered list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              final expirationStatus = _getExpirationStatus(item['expire_date']?.toString());
              
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _slideController,
                  curve: Interval(
                    index * 0.1,
                    1.0,
                    curve: Curves.easeOut,
                  ),
                )),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _getExpirationColor(expirationStatus).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getExpirationColor(expirationStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        _getExpirationIcon(expirationStatus),
                        color: _getExpirationColor(expirationStatus),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      item['product_name'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item['location'] ?? 'Unknown Location',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Qty: ${item['amount'] ?? 0}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        if (expirationStatus.toLowerCase() != 'no expiry' && 
                            item['expire_date'] != null && 
                            item['expire_date'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Expires: ${item['expire_date']}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ] else if (expirationStatus.toLowerCase() == 'no expiry') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.all_inclusive, size: 16, color: Colors.blue.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'Never expires',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: _buildExpirationStatusButton(expirationStatus),
                    onTap: () {
                      _showItemDetails(item);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
    final expirationStatus = _getExpirationStatus(item['expire_date']?.toString());
    
    print('🔍 [UI] Showing item details for: ${item['product_name']}');
    print('🔍 [UI] Item data: $item');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getExpirationColor(expirationStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          _getExpirationIcon(expirationStatus),
                          color: _getExpirationColor(expirationStatus),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['product_name'] ?? 'Unknown Product',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getExpirationColor(expirationStatus).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                expirationStatus,
                                style: TextStyle(
                                  color: _getExpirationColor(expirationStatus),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('Location', item['location'] ?? 'Unknown', Icons.location_on),
                  const SizedBox(height: 16),
                  _buildDetailRow('Quantity', item['amount']?.toString() ?? '0', Icons.inventory),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Expire Date', 
                    expirationStatus.toLowerCase() == 'no expiry' 
                        ? 'Never expires'
                        : (item['expire_date']?.toString().isNotEmpty == true 
                            ? item['expire_date'].toString() 
                            : 'No expiry date'), 
                    expirationStatus.toLowerCase() == 'no expiry' 
                        ? Icons.all_inclusive 
                        : Icons.schedule
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Add action for managing this item
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getExpirationColor(expirationStatus),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        expirationStatus.toLowerCase() == 'no expiry' 
                            ? 'Manage Item'
                            : 'Manage Expiry',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expiry Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading expiry data...'),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildExpirySummaryCards(),
                  Expanded(
                    child: _buildExpiryItemsList(),
                  ),
                ],
              ),
      ),
    );
  }
}