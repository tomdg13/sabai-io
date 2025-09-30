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

class _ApprovalPageState extends State<ApprovalPage> {
  List<Map<String, dynamic>> _allStores = [];
  
  bool _isLoading = false;
  String currentTheme = ThemeConfig.defaultTheme;
  String? _currentUserPhone;
  
  // Column definitions with order
  List<Map<String, dynamic>> _columnDefinitions = [
    {'key': 'image', 'label': 'Image', 'visible': true},
    {'key': 'store_name', 'label': 'Store Name', 'visible': true},
    {'key': 'store_code', 'label': 'Store Code', 'visible': true},
    {'key': 'manager', 'label': 'Manager', 'visible': true},
    {'key': 'email', 'label': 'Email', 'visible': false},
    {'key': 'phone', 'label': 'Phone', 'visible': false},
    {'key': 'address', 'label': 'Address', 'visible': true},
    {'key': 'city', 'label': 'City', 'visible': false},
    {'key': 'state', 'label': 'State', 'visible': false},
    {'key': 'country', 'label': 'Country', 'visible': false},
    {'key': 'postal_code', 'label': 'Postal Code', 'visible': false},
    {'key': 'store_type', 'label': 'Store Type', 'visible': false},
    {'key': 'store_status', 'label': 'Store Status', 'visible': false},
    {'key': 'opening_hours', 'label': 'Opening Hours', 'visible': false},
    {'key': 'square_footage', 'label': 'Square Footage', 'visible': false},
    {'key': 'notes', 'label': 'Notes', 'visible': false},
    {'key': 'upi', 'label': 'UPI %', 'visible': true},
    {'key': 'visa', 'label': 'VISA %', 'visible': true},
    {'key': 'mc', 'label': 'MC %', 'visible': true},
    {'key': 'account', 'label': 'Account', 'visible': false},
    {'key': 'account2', 'label': 'Account 2', 'visible': false},
    {'key': 'account_name', 'label': 'Account Name', 'visible': false},
    {'key': 'cif', 'label': 'CIF', 'visible': false},
    {'key': 'mcc', 'label': 'MCC', 'visible': false},
    {'key': 'store_mode', 'label': 'Store Mode', 'visible': false},
    {'key': 'web', 'label': 'Website', 'visible': false},
    {'key': 'email1', 'label': 'Email 1', 'visible': false},
    {'key': 'email2', 'label': 'Email 2', 'visible': false},
    {'key': 'email3', 'label': 'Email 3', 'visible': false},
    {'key': 'email4', 'label': 'Email 4', 'visible': false},
    {'key': 'email5', 'label': 'Email 5', 'visible': false},
    {'key': 'group_id', 'label': 'Group ID', 'visible': false},
    {'key': 'merchant_id', 'label': 'Merchant ID', 'visible': false},
    {'key': 'group_name', 'label': 'Group Name', 'visible': false},
    {'key': 'merchant_name', 'label': 'Merchant Name', 'visible': false},
    {'key': 'approve1', 'label': 'Approver 1', 'visible': true},
    {'key': 'approve2', 'label': 'Approver 2', 'visible': true},
    {'key': 'approval_status', 'label': 'Approval Status', 'visible': true},
    {'key': 'approved_by', 'label': 'Approved By', 'visible': false},
    {'key': 'approved_at', 'label': 'Approved At', 'visible': false},
    {'key': 'rejection_reason', 'label': 'Rejection Reason', 'visible': false},
    {'key': 'created', 'label': 'Created Date', 'visible': true},
    {'key': 'updated', 'label': 'Updated Date', 'visible': false},
    {'key': 'actions', 'label': 'Actions', 'visible': true},
  ];
  
  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _loadCurrentUser();
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
  }

  Future<void> _loadStores() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

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
        setState(() => _isLoading = false);
      }
    }
  }

  void _showColumnSettings() {
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
                  Text('Manage Columns'),
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
                            final item = _columnDefinitions.removeAt(oldIndex);
                            _columnDefinitions.insert(newIndex, item);
                          });
                          setState(() {});
                        },
                        children: _columnDefinitions.map((column) {
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
                      for (var column in _columnDefinitions) {
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
                      for (var column in _columnDefinitions) {
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

  String _getStoreStatus(Map<String, dynamic> store) {
    final approve1 = store['approve1'];
    final approve2 = store['approve2'];
    final approvalStatus = store['approval_status']?.toString().toLowerCase();
    
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

  DataCell _buildCell(String columnKey, Map<String, dynamic> store, Color primaryColor) {
    final status = _getStoreStatus(store);
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
          onTap: () => _showStoreDetails(store),
        );
      
      case 'store_code':
        return DataCell(Text(store['store_code'] ?? 'N/A'));
      
      case 'manager':
        return DataCell(Text(store['store_manager'] ?? 'N/A'));
      
      case 'email':
        return DataCell(Text(store['email'] ?? '-'));
      
      case 'phone':
        return DataCell(Text(store['phone'] ?? '-'));
      
      case 'address':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 150),
            child: Text(store['address'] ?? 'N/A', overflow: TextOverflow.ellipsis),
          ),
        );
      
      case 'city':
        return DataCell(Text(store['city'] ?? '-'));
      
      case 'state':
        return DataCell(Text(store['state'] ?? '-'));
      
      case 'country':
        return DataCell(Text(store['country'] ?? '-'));
      
      case 'postal_code':
        return DataCell(Text(store['postal_code'] ?? '-'));
      
      case 'store_type':
        return DataCell(Text(store['store_type'] ?? '-'));
      
      case 'store_status':
        return DataCell(Text(store['status'] ?? '-'));
      
      case 'opening_hours':
        return DataCell(Text(store['opening_hours'] ?? '-'));
      
      case 'square_footage':
        return DataCell(Text(store['square_footage']?.toString() ?? '-'));
      
      case 'notes':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 150),
            child: Text(store['notes'] ?? '-', overflow: TextOverflow.ellipsis),
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
      
      case 'account':
        return DataCell(Text(store['account'] ?? '-'));
      
      case 'account2':
        return DataCell(Text(store['account2'] ?? '-'));
      
      case 'account_name':
        return DataCell(Text(store['account_name'] ?? '-'));
      
      case 'cif':
        return DataCell(Text(store['cif'] ?? '-'));
      
      case 'mcc':
        return DataCell(Text(store['mcc'] ?? '-'));
      
      case 'store_mode':
        return DataCell(Text(store['store_mode'] ?? '-'));
      
      case 'web':
        return DataCell(Text(store['web'] ?? '-'));
      
      case 'email1':
        return DataCell(Text(store['email1'] ?? '-'));
      
      case 'email2':
        return DataCell(Text(store['email2'] ?? '-'));
      
      case 'email3':
        return DataCell(Text(store['email3'] ?? '-'));
      
      case 'email4':
        return DataCell(Text(store['email4'] ?? '-'));
      
      case 'email5':
        return DataCell(Text(store['email5'] ?? '-'));
      
      case 'group_id':
        return DataCell(Text(store['group_id']?.toString() ?? '-'));
      
      case 'merchant_id':
        return DataCell(Text(store['merchant_id']?.toString() ?? '-'));
      
      case 'group_name':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 150),
            child: Text(store['group_name'] ?? '-', overflow: TextOverflow.ellipsis),
          ),
        );
      
      case 'merchant_name':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 150),
            child: Text(store['merchant_name'] ?? '-', overflow: TextOverflow.ellipsis),
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
      
      case 'approved_by':
        return DataCell(Text(store['approved_by'] ?? '-'));
      
      case 'approved_at':
        return DataCell(
          Text(
            store['approved_at'] != null 
                ? DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(store['approved_at'])) 
                : '-',
            style: TextStyle(fontSize: 11),
          ),
        );
      
      case 'rejection_reason':
        return DataCell(
          Container(
            constraints: BoxConstraints(maxWidth: 200),
            child: Text(store['rejection_reason'] ?? '-', overflow: TextOverflow.ellipsis),
          ),
        );
      
      case 'created':
        return DataCell(
          Text(
            store['created_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(store['created_date'])) : 'N/A',
            style: TextStyle(fontSize: 11),
          ),
        );
      
      case 'updated':
        return DataCell(
          Text(
            store['updated_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(store['updated_date'])) : 'N/A',
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

  Widget _buildStoreTable() {
    if (_isLoading && _allStores.isEmpty) {
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

    // Build columns based on order and visibility
    List<DataColumn> columns = [];
    for (var columnDef in _columnDefinitions) {
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
                for (var columnDef in _columnDefinitions) {
                  if (columnDef['visible']) {
                    cells.add(_buildCell(columnDef['key'], store, primaryColor));
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

  void _showStoreDetails(Map<String, dynamic> store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(store['store_name'] ?? 'Store Details'),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Store Code', store['store_code']),
                _buildInfoRow('Manager', store['store_manager']),
                _buildInfoRow('Phone', store['phone']),
                _buildInfoRow('Email', store['email']),
                _buildInfoRow('Address', store['address']),
                _buildInfoRow('City', store['city']),
                _buildInfoRow('State', store['state']),
                _buildInfoRow('Country', store['country']),
                _buildInfoRow('Postal Code', store['postal_code']),
                _buildInfoRow('Group', store['group_name']),
                _buildInfoRow('Merchant', store['merchant_name']),
                _buildInfoRow('Approver 1', store['approve1']),
                _buildInfoRow('Approver 2', store['approve2']),
                _buildInfoRow('Approval Status', store['approval_status']),
                if (store['rejection_reason'] != null) ...[
                  Divider(thickness: 2),
                  SizedBox(height: 8),
                  Text('Rejection Reason:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[300]!)),
                    child: Text(store['rejection_reason'], style: TextStyle(color: Colors.red[900], height: 1.5)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value.toString(), style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Store Approval', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.view_column),
            onPressed: _showColumnSettings,
            tooltip: 'Manage Columns',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStores,
            tooltip: 'Refresh',
          ),
          Padding(
            padding: EdgeInsets.only(right: 16, top: 16, bottom: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${_allStores.length} ${_allStores.length == 1 ? 'Store' : 'Stores'}',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildStoreTable(),
    );
  }
}