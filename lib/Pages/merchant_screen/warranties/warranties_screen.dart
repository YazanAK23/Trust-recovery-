import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:trust_app_updated/Components/warranty_card/warranty_card.dart';
import 'package:trust_app_updated/Pages/merchant_screen/warranty_activation/warranty_activation_screen.dart';
import 'package:trust_app_updated/Server/domains/domains.dart';
import 'package:trust_app_updated/Server/functions/functions.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import 'package:trust_app_updated/main.dart';

/// Warranties Screen - Clean and Modern Design
class WarrantiesScreen extends StatefulWidget {
  const WarrantiesScreen({Key? key}) : super(key: key);

  @override
  State<WarrantiesScreen> createState() => _WarrantiesScreenState();
}

class _WarrantiesScreenState extends State<WarrantiesScreen> {
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // State
  List<dynamic> _allWarranties = [];
  List<dynamic> _filteredWarranties = [];
  String _selectedFilter = 'all';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadWarranties();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load warranties from API
  Future<void> _loadWarranties({bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() => _isLoading = true);
    }

    try {
      final warranties = await getWarrantiesByMerchantID(
        isLoadMore ? _currentPage : 1,
      );

      if (warranties != null && warranties.isNotEmpty) {
        setState(() {
          if (isLoadMore) {
            _allWarranties.addAll(warranties);
          } else {
            _allWarranties = warranties;
            _currentPage = 1;
          }
          _applyFilters();
        });
      } else {
        if (isLoadMore) {
          setState(() => _hasNextPage = false);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error loading warranties');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  /// Scroll listener for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasNextPage) {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
      _loadWarranties(isLoadMore: true);
    }
  }

  /// Apply search and filter
  void _applyFilters() async {
    // If search query is not empty, use API search
    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      await _searchWarranties(searchQuery);
      return;
    }

    // No search query - just apply filter
    List<dynamic> filtered = _allWarranties;

    // Apply filter by status
    if (_selectedFilter != 'all') {
      filtered = filtered.where((warranty) {
        final status = _getWarrantyStatus(warranty);
        return status.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    }

    setState(() => _filteredWarranties = filtered);
  }

  /// Get warranty status based on dates
  String _getWarrantyStatus(dynamic warranty) {
    // You can implement logic to calculate status based on warranty dates
    // For now, using warrantieStatus field if available
    if (warranty['warrantieStatus'] == false) return 'expired';
    
    // Add logic to check if expiring soon (e.g., within 3 months)
    // For demonstration, returning 'active'
    return 'active';
  }

  /// Get product name based on locale
  String _getProductName(dynamic warranty) {
    if (warranty['product'] == null) return '-';

    if (locale.toString() == 'ar') {
      final translations = warranty['product']['translations'];
      if (translations != null && translations is List && translations.isNotEmpty) {
        return translations[0]['value'] ?? warranty['product']['name'] ?? '-';
      }
    }

    return warranty['product']['name'] ?? '-';
  }

  /// Get product image URL
  String _getProductImage(dynamic warranty) {
    if (warranty['product'] == null || warranty['product']['image'] == null) {
      return '';
    }

    try {
      final imageField = warranty['product']['image'];
      // If it's already a string (path)
      if (imageField is String) {
        // Try to parse as JSON array first
        try {
          final imageData = jsonDecode(imageField);
          if (imageData is List && imageData.isNotEmpty) {
            return URLIMAGE + imageData[0];
          }
        } catch (e) {
          // If not JSON, treat as direct path
          return URLIMAGE + imageField;
        }
      }
      // If it's already a List
      else if (imageField is List && imageField.isNotEmpty) {
        return URLIMAGE + imageField[0];
      }
    } catch (e) {
      print('Error parsing product image: $e');
    }

    return '';
  }

  /// Get product image path (for WarrantyCard component)
  String _getProductImagePath(dynamic warranty) {
    if (warranty['product'] == null || warranty['product']['image'] == null) {
      return '';
    }

    try {
      final imageField = warranty['product']['image'];
      // If it's already a string (path)
      if (imageField is String) {
        // Try to parse as JSON array first
        try {
          final imageData = jsonDecode(imageField);
          if (imageData is List && imageData.isNotEmpty) {
            return imageData[0].toString();
          }
        } catch (e) {
          // If not JSON, treat as direct path
          return imageField;
        }
      }
      // If it's already a List
      else if (imageField is List && imageField.isNotEmpty) {
        return imageField[0].toString();
      }
    } catch (e) {
      print('Error parsing product image path: $e');
    }

    return '';
  }

  /// Search warranties by serial number or phone
  Future<void> _searchWarranties(String query) async {
    final searchQuery = query.trim();
    
    // Always do local search first for immediate results
    List<dynamic> filtered = _allWarranties;
    
    // Apply status filter if selected
    if (_selectedFilter != 'all') {
      filtered = filtered.where((warranty) {
        final status = _getWarrantyStatus(warranty);
        return status.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    }
    
    // Apply search filter
    final searchLower = searchQuery.toLowerCase();
    filtered = filtered.where((warranty) {
      final productName = _getProductName(warranty).toLowerCase();
      final serialNumber =
          (warranty['productSerialNumber'] ?? '').toString().toLowerCase();
      final customerName =
          (warranty['customerName'] ?? '').toString().toLowerCase();
      final customerPhone =
          (warranty['customerPhone'] ?? '').toString().toLowerCase();

      return productName.contains(searchLower) ||
          serialNumber.contains(searchLower) ||
          customerName.contains(searchLower) ||
          customerPhone.contains(searchLower);
    }).toList();
    
    setState(() => _filteredWarranties = filtered);
    
    // Try API search in background for more comprehensive results
    if (searchQuery.length >= 3) {
      try {
        final response = await http.get(
          Uri.parse('http://app.redtrust.ps:3003/warranties/search/$searchQuery'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            List<dynamic> searchResults = data['response']['data'] ?? [];
            
            // Apply status filter if selected
            if (_selectedFilter != 'all') {
              searchResults = searchResults.where((warranty) {
                final status = _getWarrantyStatus(warranty);
                return status.toLowerCase() == _selectedFilter.toLowerCase();
              }).toList();
            }
            
            setState(() => _filteredWarranties = searchResults);
          }
        }
      } catch (e) {
        print('Search API error: $e');
        // Keep the local search results
      }
    }
  }

  /// Get filter counts
  Map<String, int> _getFilterCounts() {
    int all = _allWarranties.length;
    int active = _allWarranties.where((w) => _getWarrantyStatus(w) == 'active').length;
    int expiringSoon = _allWarranties.where((w) => _getWarrantyStatus(w) == 'expiring-soon').length;
    int expired = _allWarranties.where((w) => _getWarrantyStatus(w) == 'expired').length;

    return {
      'all': all,
      'active': active,
      'expiring-soon': expiringSoon,
      'expired': expired,
    };
  }

  /// Handle delete warranty
  void _handleDelete(int warrantyId) async {
    // Find the warranty to check activation date
    final warranty = _allWarranties.firstWhere(
      (w) => w['id'] == warrantyId,
      orElse: () => null,
    );

    if (warranty != null) {
      final createdAt = DateTime.parse(warranty['createdAt']);
      final daysSinceActivation = DateTime.now().difference(createdAt).inDays;

      if (daysSinceActivation > 14) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.cannot_delete_old_warranty,
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }
    }

    _showDeleteDialog(warrantyId, warranty);
  }

  /// Show delete confirmation dialog
  void _showDeleteDialog(int warrantyId, dynamic warranty) {
    final productName = _getProductName(warranty);
    final serialNumber = warranty['productSerialNumber'] ?? '-';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Delete icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: const Color(0xffD51C29),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                AppLocalizations.of(context)!.delete_warranty_question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Product info
              Text(
                productName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Serial: $serialNumber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F5),
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.cancel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteWarranty(warrantyId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffD51C29),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.delete,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Delete warranty API call
  Future<void> _deleteWarranty(int warrantyId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://app.redtrust.ps:3003/warranties/$warrantyId'),
      );

      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.warranty_deleted_successfully,
        );
        _loadWarranties();
      } else {
        Fluttertoast.showToast(msg: 'Failed to delete warranty');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error deleting warranty: $e');
    }
  }

  /// Handle edit warranty
  void _handleEdit(dynamic warranty) {
    _showEditDialog(warranty);
  }

  /// Show edit warranty dialog
  void _showEditDialog(dynamic warranty) {
    final customerNameController = TextEditingController(
      text: warranty['customerName'] ?? '',
    );
    final phoneController = TextEditingController(
      text: warranty['customerPhone'] ?? '',
    );
    
    DateTime selectedDate = warranty['createdAt'] != null
        ? DateTime.parse(warranty['createdAt'])
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.edit_warranty,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  
                  // Product info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Product image
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Builder(
                              builder: (context) {
                                final imageUrl = _getProductImage(warranty);
                                print('Edit Dialog Image URL: $imageUrl');
                                
                                if (imageUrl.isEmpty) {
                                  return Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey[400],
                                    size: 24,
                                  );
                                }
                                
                                return Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Image load error: $error');
                                    return Icon(
                                      Icons.image_outlined,
                                      color: Colors.grey[400],
                                      size: 24,
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getProductName(warranty),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                warranty['productSerialNumber'] ?? '-',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Customer Name field
                  Text(
                    AppLocalizations.of(context)!.customer_name_required,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customerNameController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.enter_customer_full_name,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Phone Number field
                  Text(
                    AppLocalizations.of(context)!.phone_number_required,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.enter_phone_number,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Purchase Date field
                  Text(
                    AppLocalizations.of(context)!.purchase_date_required,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F5F5),
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.cancel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (customerNameController.text.isEmpty ||
                                phoneController.text.isEmpty) {
                              Fluttertoast.showToast(
                                msg: AppLocalizations.of(context)!
                                    .please_fill_required_fields,
                              );
                              return;
                            }

                            Navigator.pop(context);
                            await _updateWarranty(
                              warrantyId: warranty['id'],
                              customerName: customerNameController.text,
                              customerPhone: phoneController.text,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffD51C29),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.save_changes,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// Update warranty API call
  Future<void> _updateWarranty({
    required int warrantyId,
    required String customerName,
    required String customerPhone,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('http://app.redtrust.ps:3003/warranties/edit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': warrantyId,
          'customerName': customerName,
          'customerPhone': customerPhone,
        }),
      );

      if (response.statusCode == 200) {
        Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.warranty_updated_successfully,
        );
        _loadWarranties();
      } else {
        Fluttertoast.showToast(msg: 'Failed to update warranty');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error updating warranty: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterCounts = _getFilterCounts();
    final isRTL = locale.toString() == 'ar';

    return Container(
      color: const Color(0xffD51C29),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Column(
            children: [
              // Header
              _buildHeader(isRTL),

              // Search bar
              _buildSearchBar(),

              // Filter chips
              _buildFilterChips(filterCounts),

              // Warranties list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredWarranties.isEmpty
                        ? _buildEmptyState()
                        : _buildWarrantiesList(),
              ),

              // Loading more indicator
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isRTL) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xffD51C29),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back button
          Positioned(
            left: isRTL ? null : 0,
            right: isRTL ? 0 : null,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),

          // Title
          Center(
            child: Text(
              AppLocalizations.of(context)!.warranties,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
          ),

          // Add button
          Positioned(
            left: isRTL ? 0 : null,
            right: isRTL ? null : 0,
            child: IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WarrantyActivationScreen(),
                  ),
                );
                _loadWarranties();
              },
              icon: const Icon(
                Icons.add,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _applyFilters(),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.search_by_serial_product_customer,
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[400],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(Map<String, int> counts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(
            label: AppLocalizations.of(context)!.all,
            count: counts['all']!,
            value: 'all',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: AppLocalizations.of(context)!.active,
            count: counts['active']!,
            value: 'active',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: AppLocalizations.of(context)!.expiring_soon,
            count: counts['expiring-soon']!,
            value: 'expiring-soon',
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: AppLocalizations.of(context)!.expired,
            count: counts['expired']!,
            value: 'expired',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required String value,
  }) {
    final isSelected = _selectedFilter == value;

    return InkWell(
      onTap: () {
        setState(() => _selectedFilter = value);
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xffD51C29) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xffD51C29)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWarrantiesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      itemCount: _filteredWarranties.length,
      itemBuilder: (context, index) {
        final warranty = _filteredWarranties[index];
        final product = warranty['product'];

        return WarrantyCard(
          productName: _getProductName(warranty),
          productSerialNumber: warranty['productSerialNumber'] ?? '-',
          productImage: _getProductImagePath(warranty),
          customerName: warranty['customerName'] ?? '-',
          customerPhone: warranty['customerPhone'] ?? '-',
          purchaseDate: warranty['createdAt'] != null
              ? warranty['createdAt'].toString().substring(0, 10)
              : '-',
          warrantyYears: product?['warranty_period'] ?? 2,
          status: _getWarrantyStatus(warranty),
          onEdit: () => _handleEdit(warranty),
          onDelete: () => _handleDelete(warranty['id']),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No warranties found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
