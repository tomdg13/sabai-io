import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({Key? key}) : super(key: key);

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allStores = [];
  List<Map<String, dynamic>> _allTerminals = [];
  
  bool _isLoadingStores = false;
  bool _isLoadingTerminals = false;
  String currentTheme = ThemeConfig.defaultTheme;
  String? _currentUserPhone;
  
  late TabController _tabController;
  
  // Store columns
  List<Map<String, dynamic>> _storeColumns = [
    {'key': 'image', 'label': 'Image', 'visible': true},
    {'key': 'store_name', 'label': 'Store Name', 'visible': true},
    {'key': 'store_code', 'label': 'Store Code', 'visible': true},
    {'key': 'manager', 'label': 'Manager', 'visible': true},
    {'key': 'address', 'label': 'Address', 'visible': true},
    {'key': 'upi', 'label': 'UPI %', 'visible': true},
    {'key': 'visa', 'label': 'VISA %', 'visible': true},
    {'key': 'mc', 'label': 'MC %', 'visible': true},
    {'key': 'approve1', 'label': 'Approver 1', 'visible': true},
    {'key': 'approve2', 'label': 'Approver 2', 'visible': true},
    {'key': 'approval_status', 'label': 'Status', 'visible': true},
    {'key': 'created', 'label': 'Created', 'visible': true},
    {'key': 'actions', 'label': 'Actions', 'visible': true},
  ];

  // Terminal columns
  List<Map<String, dynamic>> _terminalColumns = [
    {'key': 'image', 'label': 'Image', 'visible': true},
    {'key': 'terminal_name', 'label': 'Terminal Name', 'visible': true},
    {'key': 'terminal_code', 'label': 'Terminal Code', 'visible': true},
    {'key': 'store_name', 'label': 'Store', 'visible': true},
    {'key': 'serial_number', 'label': 'Serial #', 'visible': true},
    {'key': 'sim_number', 'label': 'SIM #', 'visible': true},
    {'key': 'expire_date', 'label': 'Expire Date', 'visible': true},
    {'key': 'phone', 'label': 'Phone', 'visible': false},
    {'key': 'approve1', 'label': 'Approver 1', 'visible': true},
    {'key': 'approve2', 'label': 'Approver 2', 'visible': true},
    {'key': 'approval_status', 'label': 'Status', 'visible': true},
    {'key': 'created', 'label': 'Created', 'visible': true},
    {'key': 'actions', 'label': 'Actions', 'visible': true},
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadCurrentTheme();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserPhone = prefs.getString('phone');
    print('Current user phone: $_currentUserPhone');
    await _loadStores();
    await _loadTerminals();
  }

  Future<void> _loadStores() async {
    if (_isLoadingStores) return;
    
    setState(() => _isLoadingStores = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      final url = AppConfig.api('/api/iostore?company_id=$companyId');
      
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final List<dynamic> storesJson = responseData['data'];
          
          setState(() {
            _allStores = storesJson.map((json) => json as Map<String, dynamic>).toList();
            print('Total stores loaded: ${_allStores.length}');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading stores: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStores = false);
      }
    }
  }

  Future<void> _loadTerminals() async {
    if (_isLoadingTerminals) return;
    
    setState(() => _isLoadingTerminals = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      final url = AppConfig.api('/api/ioterminal?company_id=$companyId');
      
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final List<dynamic> terminalsJson = responseData['data'];
          
          setState(() {
            _allTerminals = terminalsJson.map((json) => json as Map<String, dynamic>).toList();
            print('Total terminals loaded: ${_allTerminals.length}');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading terminals: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTerminals = false);
      }
    }
  }

  void _showColumnSettings() {
    final isStoreTab = _tabController.index == 0;
    final columns = isStoreTab ? _storeColumns : _terminalColumns;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.view_column, color: ThemeConfig.getPrimaryColor(currentTheme)),
                  SizedBox(width: 8),
                  Text('Manage ${isStoreTab ? "Store" : "Terminal"} Columns'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Drag to reorder columns',
                              style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: ReorderableListView(
                        onReorder: (oldIndex, newIndex) {
                          setDialogState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = columns.removeAt(oldIndex);
                            columns.insert(newIndex, item);
                          });
                          setState(() {});
                        },
                        children: columns.map((column) {
                          return CheckboxListTile(
                            key: ValueKey(column['key']),
                            dense: true,
                            title: Row(
                              children: [
                                Icon(Icons.drag_handle, size: 16, color: Colors.grey),
                                SizedBox(width: 8),
                                Expanded(child: Text(column['label'], style: TextStyle(fontSize: 13))),
                              ],
                            ),
                            value: column['visible'],
                            onChanged: (value) {
                              setDialogState(() {
                                column['visible'] = value ?? true;
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      for (var column in columns) {
                        column['visible'] = true;
                      }
                    });
                    setState(() {});
                  },
                  child: Text('Show All'),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      for (var column in columns) {
                        column['visible'] = false;
                      }
                    });
                    setState(() {});
                  },
                  child: Text('Hide All'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // STORE APPROVAL METHODS
  Future<void> _approveStore(Map<String, dynamic> store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Approval'),
        content: Text('Are you sure you want to approve "${store['store_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final storeId = store['store_id'];
      
      final url = AppConfig.api('/api/iostore/$storeId/approval');
      
      final currentApprove1 = store['approve1']?.toString();
      final currentApprove2 = store['approve2']?.toString();
      
      bool isFirstApproval = (currentApprove1 == null || currentApprove1.isEmpty);
      bool isSecondApproval = (currentApprove1 != null && currentApprove1.isNotEmpty) && 
                              (currentApprove2 == null || currentApprove2.isEmpty);
      
      if (currentApprove1 == _currentUserPhone || currentApprove2 == _currentUserPhone) {
        _showSnackBar(message: 'You have already approved this store', isError: true);
        return;
      }
      
      Map<String, dynamic> requestBody = {
        'approved_by': _currentUserPhone ?? 'unknown',
        'approved_at': DateTime.now().toIso8601String(),
      };
      
      if (isFirstApproval) {
        requestBody['approval_status'] = 'pending';
        requestBody['approve1'] = _currentUserPhone;
      } else if (isSecondApproval) {
        requestBody['approval_status'] = 'approved';
        requestBody['approve1'] = currentApprove1;
        requestBody['approve2'] = _currentUserPhone;
      } else {
        _showSnackBar(message: 'Store already fully approved', isError: true);
        return;
      }
      
      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['status'] == 'success') {
        if (isSecondApproval) {
          _showSnackBar(message: 'Store fully approved! (2/2 approvals)', isError: false);
        } else {
          _showSnackBar(message: 'Store approved! Waiting for second approver (1/2)', isError: false);
        }
        await _loadStores();
      } else {
        _showSnackBar(
          message: responseData['message'] ?? 'Failed to approve store',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error approving store: $e', isError: true);
      }
    }
  }

  Future<void> _rejectStore(Map<String, dynamic> store) async {
    final TextEditingController reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Store'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Store: ${store['store_name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Code: ${store['store_code']}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text('Rejection Reason *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Please provide a detailed reason for rejection...',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '* This reason will be visible to the store and other approvers',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please provide a rejection reason'), backgroundColor: Colors.red),
                );
                return;
              }
              if (reasonController.text.trim().length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Rejection reason must be at least 10 characters'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Reject Store', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final storeId = store['store_id'];
      
      final url = AppConfig.api('/api/iostore/$storeId/approval');
      
      final currentApprove1 = store['approve1']?.toString();
      final currentApprove2 = store['approve2']?.toString();
      
      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'approval_status': 'rejected',
          'approved_by': _currentUserPhone ?? 'unknown',
          'approved_at': DateTime.now().toIso8601String(),
          'rejection_reason': reasonController.text.trim(),
          'approve1': currentApprove1,
          'approve2': currentApprove2,
        }),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['status'] == 'success') {
        _showSnackBar(message: 'Store rejected successfully', isError: false);
        await _loadStores();
      } else {
        _showSnackBar(message: responseData['message'] ?? 'Failed to reject store', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error rejecting store: $e', isError: true);
      }
    }
  }

  // TERMINAL APPROVAL METHODS
  Future<void> _approveTerminal(Map<String, dynamic> terminal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Approval'),
        content: Text('Are you sure you want to approve "${terminal['terminal_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final terminalId = terminal['terminal_id'];
      
      final url = AppConfig.api('/api/ioterminal/$terminalId/approve');
      
      final currentApprove1 = terminal['approve1']?.toString();
      final currentApprove2 = terminal['approve2']?.toString();
      
      bool isFirstApproval = (currentApprove1 == null || currentApprove1.isEmpty);
      bool isSecondApproval = (currentApprove1 != null && currentApprove1.isNotEmpty) && 
                              (currentApprove2 == null || currentApprove2.isEmpty);
      
      if (currentApprove1 == _currentUserPhone || currentApprove2 == _currentUserPhone) {
        _showSnackBar(message: 'You have already approved this terminal', isError: true);
        return;
      }
      
      Map<String, dynamic> requestBody = {
        'approved_by': _currentUserPhone ?? 'unknown',
        'approved_at': DateTime.now().toIso8601String(),
      };
      
      if (isFirstApproval) {
        requestBody['approval_status'] = 'pending';
        requestBody['approve1'] = _currentUserPhone;
      } else if (isSecondApproval) {
        requestBody['approval_status'] = 'approved';
        requestBody['approve1'] = currentApprove1;
        requestBody['approve2'] = _currentUserPhone;
      } else {
        _showSnackBar(message: 'Terminal already fully approved', isError: true);
        return;
      }
      
      final response = await http.patch(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['status'] == 'success') {
        if (isSecondApproval) {
          _showSnackBar(message: 'Terminal fully approved! (2/2 approvals)', isError: false);
        } else {
          _showSnackBar(message: 'Terminal approved! Waiting for second approver (1/2)', isError: false);
        }
        await _loadTerminals();
      } else {
        _showSnackBar(
          message: responseData['message'] ?? 'Failed to approve terminal',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error approving terminal: $e', isError: true);
      }
    }
  }

  Future<void> _rejectTerminal(Map<String, dynamic> terminal) async {
    final TextEditingController reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Terminal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Terminal: ${terminal['terminal_name']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Code: ${terminal['terminal_code']}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text('Rejection Reason *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Please provide a detailed reason for rejection...',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '* This reason will be visible to the terminal and other approvers',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please provide a rejection reason'), backgroundColor: Colors.red),
                );
                return;
              }
              if (reasonController.text.trim().length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Rejection reason must be at least 10 characters'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Reject Terminal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final terminalId = terminal['terminal_id'];
      
      final url = AppConfig.api('/api/ioterminal/$terminalId/approve');
      
      final currentApprove1 = terminal['approve1']?.toString();
      final currentApprove2 = terminal['approve2']?.toString();
      
      final response = await http.patch(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'approval_status': 'rejected',
          'approved_by': _currentUserPhone ?? 'unknown',
          'approved_at': DateTime.now().toIso8601String(),
          'rejection_reason': reasonController.text.trim(),
          'approve1': currentApprove1,
          'approve2': currentApprove2,
        }),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['status'] == 'success') {
        _showSnackBar(message: 'Terminal rejected successfully', isError: false);
        await _loadTerminals();
      } else {
        _showSnackBar(message: responseData['message'] ?? 'Failed to reject terminal', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error rejecting terminal: $e', isError: true);
      }
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _getStatus(Map<String, dynamic> item) {
    final approve1 = item['approve1'];
    final approve2 = item['approve2'];
    final approvalStatus = item['approval_status']?.toString().toLowerCase();
    
    if (approvalStatus == 'rejected') {
      return 'REJECTED';
    }
    
    if (approvalStatus == 'approved' && 
        approve1 != null && approve1.toString().isNotEmpty &&
        approve2 != null && approve2.toString().isNotEmpty) {
      return 'APPROVED';
    }
    
    if (approve1 != null && approve1.toString().isNotEmpty &&
        (approve2 == null || approve2.toString().isEmpty)) {
      return 'WAITING FOR 2ND APPROVAL';
    }
    
    return 'PENDING';
  }

  DataCell _buildStoreCell(String columnKey, Map<String, dynamic> store, Color primaryColor) {
    final status = _getStatus(store);
    final approve1 = store['approve1']?.toString();
    final approve2 = store['approve2']?.toString();
    final userAlreadyApproved = (approve1 == _currentUserPhone || approve2 == _currentUserPhone);
    final canApprove = !userAlreadyApproved && status != 'APPROVED' && status != 'REJECTED';
    
    Color statusColor = Colors.orange;
    switch (status) {
      case 'APPROVED':
        statusColor = Colors.green;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        break;
      case 'WAITING FOR 2ND APPROVAL':
        statusColor = Colors.blue;
        break;
    }

    switch (columnKey) {
      case 'image':
        return DataCell(
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: primaryColor.withOpacity(0.1)),
            child: store['image_url'] != null && store['image_url'].toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      store['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.store, color: primaryColor, size: 24),
                    ),
                  )
                : Icon(Icons.store, color: primaryColor, size: 24),
          ),
        );
      
      case 'store_name':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 150),
            child: Text(store['store_name'] ?? 'N/A', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      
      case 'store_code':
        return DataCell(Text(store['store_code'] ?? 'N/A'));
      
      case 'manager':
        return DataCell(Text(store['store_manager'] ?? 'N/A'));
      
      case 'address':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 150),
            child: Text(store['address'] ?? 'N/A', overflow: TextOverflow.ellipsis),
          ),
        );
      
      case 'upi':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
            child: Text(store['upi_percentage']?.toString() ?? '-', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w600)),
          ),
        );
      
      case 'visa':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(4)),
            child: Text(store['visa_percentage']?.toString() ?? '-', style: TextStyle(color: Colors.indigo[800], fontWeight: FontWeight.w600)),
          ),
        );
      
      case 'mc':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
            child: Text(store['master_percentage']?.toString() ?? '-', style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w600)),
          ),
        );
      
      case 'approve1':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (approve1 == null || approve1.isEmpty) ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (approve1 == null || approve1.isEmpty) ? Colors.orange[300]! : Colors.green[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (approve1 != null && approve1.isNotEmpty) Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                if (approve1 != null && approve1.isNotEmpty) SizedBox(width: 4),
                Text(
                  approve1 ?? 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    color: (approve1 == null || approve1.isEmpty) ? Colors.orange[800] : Colors.green[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      
      case 'approve2':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (approve2 == null || approve2.isEmpty) ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (approve2 == null || approve2.isEmpty) ? Colors.orange[300]! : Colors.green[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (approve2 != null && approve2.isNotEmpty) Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                if (approve2 != null && approve2.isNotEmpty) SizedBox(width: 4),
                Text(
                  approve2 ?? 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    color: (approve2 == null || approve2.isEmpty) ? Colors.orange[800] : Colors.green[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      
      case 'approval_status':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        );
      
      case 'created':
        return DataCell(
          Text(
            store['created_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(store['created_date'])) : 'N/A',
            style: TextStyle(fontSize: 11),
          ),
        );
      
      case 'actions':
        return DataCell(
          canApprove
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _approveStore(store),
                      icon: Icon(Icons.check_circle, size: 16),
                      label: Text('Approve', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size(90, 36),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _rejectStore(store),
                      icon: Icon(Icons.cancel, size: 16),
                      label: Text('Reject', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size(90, 36),
                      ),
                    ),
                  ],
                )
              : Container(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    userAlreadyApproved ? '✓ Done' : '-',
                    style: TextStyle(color: userAlreadyApproved ? Colors.green : Colors.grey, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
        );
      
      default:
        return DataCell(Text('-'));
    }
  }

  DataCell _buildTerminalCell(String columnKey, Map<String, dynamic> terminal, Color primaryColor) {
    final status = _getStatus(terminal);
    final approve1 = terminal['approve1']?.toString();
    final approve2 = terminal['approve2']?.toString();
    final userAlreadyApproved = (approve1 == _currentUserPhone || approve2 == _currentUserPhone);
    final canApprove = !userAlreadyApproved && status != 'APPROVED' && status != 'REJECTED';
    
    Color statusColor = Colors.orange;
    switch (status) {
      case 'APPROVED':
        statusColor = Colors.green;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        break;
      case 'WAITING FOR 2ND APPROVAL':
        statusColor = Colors.blue;
        break;
    }

    switch (columnKey) {
      case 'image':
        return DataCell(
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: primaryColor.withOpacity(0.1)),
            child: terminal['image_url'] != null && terminal['image_url'].toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      terminal['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.phone_android, color: primaryColor, size: 24),
                    ),
                  )
                : Icon(Icons.phone_android, color: primaryColor, size: 24),
          ),
        );
      
      case 'terminal_name':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 150),
            child: Text(terminal['terminal_name'] ?? 'N/A', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      
      case 'terminal_code':
        return DataCell(Text(terminal['terminal_code'] ?? 'N/A'));
      
      case 'store_name':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 120),
            child: Text(terminal['store_name'] ?? '-', overflow: TextOverflow.ellipsis),
          ),
        );
      
      case 'serial_number':
        return DataCell(Text(terminal['serial_number'] ?? '-'));
      
      case 'sim_number':
        return DataCell(Text(terminal['sim_number'] ?? '-'));
      
      case 'expire_date':
        return DataCell(
          terminal['expire_date'] != null
              ? Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(terminal['expire_date'])),
                  style: TextStyle(fontSize: 11),
                )
              : Text('-'),
        );
      
      case 'phone':
        return DataCell(Text(terminal['phone'] ?? '-'));
      
      case 'approve1':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (approve1 == null || approve1.isEmpty) ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (approve1 == null || approve1.isEmpty) ? Colors.orange[300]! : Colors.green[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (approve1 != null && approve1.isNotEmpty) Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                if (approve1 != null && approve1.isNotEmpty) SizedBox(width: 4),
                Text(
                  approve1 ?? 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    color: (approve1 == null || approve1.isEmpty) ? Colors.orange[800] : Colors.green[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      
      case 'approve2':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (approve2 == null || approve2.isEmpty) ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (approve2 == null || approve2.isEmpty) ? Colors.orange[300]! : Colors.green[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (approve2 != null && approve2.isNotEmpty) Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                if (approve2 != null && approve2.isNotEmpty) SizedBox(width: 4),
                Text(
                  approve2 ?? 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    color: (approve2 == null || approve2.isEmpty) ? Colors.orange[800] : Colors.green[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      
      case 'approval_status':
        return DataCell(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        );
      
      case 'created':
        return DataCell(
          Text(
            terminal['created_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(terminal['created_date'])) : 'N/A',
            style: TextStyle(fontSize: 11),
          ),
        );
      
      case 'actions':
        return DataCell(
          canApprove
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _approveTerminal(terminal),
                      icon: Icon(Icons.check_circle, size: 16),
                      label: Text('Approve', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size(90, 36),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _rejectTerminal(terminal),
                      icon: Icon(Icons.cancel, size: 16),
                      label: Text('Reject', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size(90, 36),
                      ),
                    ),
                  ],
                )
              : Container(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    userAlreadyApproved ? '✓ Done' : '-',
                    style: TextStyle(color: userAlreadyApproved ? Colors.green : Colors.grey, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
        );
      
      default:
        return DataCell(Text('-'));
    }
  }

  Widget _buildStoreTable() {
    if (_isLoadingStores && _allStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.getPrimaryColor(currentTheme))),
            SizedBox(height: 16),
            Text('Loading stores...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_allStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('No stores found', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);

    List<DataColumn> columns = [];
    for (var columnDef in _storeColumns) {
      if (columnDef['visible']) {
        columns.add(DataColumn(label: Text(columnDef['label'])));
      }
    }

    return RefreshIndicator(
      onRefresh: _loadStores,
      color: primaryColor,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(primaryColor.withOpacity(0.1)),
              headingRowHeight: 56,
              dataRowHeight: 80,
              border: TableBorder.all(color: Colors.grey[300]!, width: 1),
              columnSpacing: 16,
              horizontalMargin: 12,
              headingTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
              dataTextStyle: TextStyle(fontSize: 12, color: Colors.black87),
              columns: columns,
              rows: _allStores.map((store) {
                List<DataCell> cells = [];
                for (var columnDef in _storeColumns) {
                  if (columnDef['visible']) {
                    cells.add(_buildStoreCell(columnDef['key'], store, primaryColor));
                  }
                }
                return DataRow(cells: cells);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalTable() {
    if (_isLoadingTerminals && _allTerminals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.getPrimaryColor(currentTheme))),
            SizedBox(height: 16),
            Text('Loading terminals...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_allTerminals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('No terminals found', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);

    List<DataColumn> columns = [];
    for (var columnDef in _terminalColumns) {
      if (columnDef['visible']) {
        columns.add(DataColumn(label: Text(columnDef['label'])));
      }
    }

    return RefreshIndicator(
      onRefresh: _loadTerminals,
      color: primaryColor,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(primaryColor.withOpacity(0.1)),
              headingRowHeight: 56,
              dataRowHeight: 80,
              border: TableBorder.all(color: Colors.grey[300]!, width: 1),
              columnSpacing: 16,
              horizontalMargin: 12,
              headingTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
              dataTextStyle: TextStyle(fontSize: 12, color: Colors.black87),
              columns: columns,
              rows: _allTerminals.map((terminal) {
                List<DataCell> cells = [];
                for (var columnDef in _terminalColumns) {
                  if (columnDef['visible']) {
                    cells.add(_buildTerminalCell(columnDef['key'], terminal, primaryColor));
                  }
                }
                return DataRow(cells: cells);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final isStoreTab = _tabController.index == 0;
    final itemCount = isStoreTab ? _allStores.length : _allTerminals.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Approval Management', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(
              icon: Icon(Icons.store),
              text: 'Stores',
            ),
            Tab(
              icon: Icon(Icons.phone_android),
              text: 'Terminals',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.view_column),
            onPressed: _showColumnSettings,
            tooltip: 'Manage Columns',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadStores();
              } else {
                _loadTerminals();
              }
            },
            tooltip: 'Refresh',
          ),
          Padding(
            padding: EdgeInsets.only(right: 16, top: 16, bottom: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '$itemCount ${itemCount == 1 ? (isStoreTab ? 'Store' : 'Terminal') : (isStoreTab ? 'Stores' : 'Terminals')}',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoreTable(),
          _buildTerminalTable(),
        ],
      ),
    );
  }
}