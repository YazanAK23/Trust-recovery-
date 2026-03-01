import 'package:fancy_shimmer_image/fancy_shimmer_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:trust_app_updated/Server/functions/functions.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import 'package:trust_app_updated/main.dart';
import 'package:trust_app_updated/Components/maintenance_card/maintenance_card_widget.dart';
import 'package:trust_app_updated/Components/status_summary/status_summary_widget.dart';
import 'package:trust_app_updated/Components/filter_tabs/filter_tabs_widget.dart';
import 'package:trust_app_updated/Components/drawer_widget/drawer_widget.dart';
import '../../../Constants/constants.dart';
import '../../../Server/domains/domains.dart';
import '../add_maintanence_request/add_maintanence_request.dart';

class MaintenanceRequests extends StatefulWidget {
  const MaintenanceRequests({super.key});

  @override
  State<MaintenanceRequests> createState() => _MaintenanceRequestsState();
}

class _MaintenanceRequestsState extends State<MaintenanceRequests> {
  // Status translations
  final Map<String, String> statusTranslations = {
    "pending": "قيدالانتظار",
    "in_progress": "قيدالصيانة",
    "done": "مكتمل",
    "delivered": "مسلّم"
  };

  // Data variables
  List<dynamic> allMaintenanceRequests = [];
  List<dynamic> filteredRequests = [];
  
  // Status counts
  int pendingCount = 0;
  int inProgressCount = 0;
  int doneCount = 0;
  int deliveredCount = 0;
  
  // Filter state
  String selectedFilter = 'all';
  
  // Loading states
  bool isLoading = false;
  bool isLoadingMore = false;
  
  // Pagination
  int currentPage = 1;
  bool hasMorePages = true;
  
  // Controllers
  ScrollController scrollController = ScrollController();
  
  // Track locale for rebuilding on language change
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    fetchMaintenanceRequests();
    scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure data is loaded when page is fully built
      if (allMaintenanceRequests.isEmpty && !isLoading) {
        fetchMaintenanceRequests();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if locale has changed
    final newLocale = Localizations.localeOf(context);
    if (_currentLocale != null && _currentLocale != newLocale) {
      // Language changed, rebuild the UI
      setState(() {
        _currentLocale = newLocale;
      });
    } else if (_currentLocale == null) {
      _currentLocale = newLocale;
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 500 &&
        !isLoadingMore &&
        hasMorePages) {
      loadMoreRequests();
    }
  }

  Future<void> fetchMaintenanceRequests() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      currentPage = 1;
      hasMorePages = true;
      allMaintenanceRequests.clear();
      filteredRequests.clear();
    });

    try {
      var response = await getMaintenanceRequestsByMerchantID(currentPage);
      
      if (response != null && response["data"] != null) {
        if (!mounted) return;
        setState(() {
          allMaintenanceRequests = List.from(response["data"]);
          
          // Update status counts
          pendingCount = response["statusCounts"]["pending"] ?? 0;
          inProgressCount = response["statusCounts"]["in_progress"] ?? 0;
          doneCount = response["statusCounts"]["done"] ?? 0;
          deliveredCount = response["statusCounts"]["delivered"] ?? 0;
          
          // Apply filter
          applyFilter();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching maintenance requests: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> loadMoreRequests() async {
    if (!mounted || !hasMorePages) return;
    
    setState(() {
      isLoadingMore = true;
    });

    try {
      currentPage++;
      var response = await getMaintenanceRequestsByMerchantID(currentPage);
      
      if (response != null && response["data"] != null && response["data"].isNotEmpty) {
        if (!mounted) return;
        setState(() {
          allMaintenanceRequests.addAll(response["data"]);
          applyFilter();
        });
      } else {
        hasMorePages = false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading more requests: $e');
      }
      currentPage--; // Revert page increment on error
    } finally {
      if (mounted) {
        setState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  void applyFilter() {
    if (selectedFilter == 'all') {
      filteredRequests = List.from(allMaintenanceRequests);
    } else {
      filteredRequests = allMaintenanceRequests
          .where((request) => request['status'] == selectedFilter)
          .toList();
    }
  }

  void onFilterChanged(String filter) {
    setState(() {
      selectedFilter = filter;
      applyFilter();
      // Scroll to top when filter changes
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _extractImageUrl(dynamic imageField) {
    if (imageField == null) return '';
    
    String imageStr = imageField.toString();
    
    // If it's a JSON array string
    if (imageStr.contains('[') && imageStr.contains(']')) {
      imageStr = imageStr.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
      List<String> images = imageStr.split(',');
      if (images.isNotEmpty) {
        String firstImage = images[0].trim();
        // Build full URL if it's a relative path
        if (!firstImage.startsWith('http')) {
          return '$URLIMAGE$firstImage';
        }
        return firstImage;
      }
    }
    
    return imageStr;
  }

  String _getProductName(dynamic request) {
    try {
      if (request['product'] != null) {
        // Try to get translated name first
        if (request['product']['translations'] != null) {
          final translations = request['product']['translations'] as List;
          final arTranslation = translations.firstWhere(
            (t) => t['locale'] == 'ar' && t['columnName'] == 'name',
            orElse: () => null,
          );
          if (arTranslation != null && arTranslation['value'] != null) {
            return arTranslation['value'].toString();
          }
        }
        // Fallback to default name
        return request['product']['name']?.toString() ?? 'Unknown Product';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting product name: $e');
      }
    }
    return 'Unknown Product';
  }

  void _handleViewReport(dynamic request) {
    // TODO: Navigate to detailed report screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.report_details),
        content: Text('${AppLocalizations.of(context)!.full_report_for} ${request['productSerialNumber']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }

  void _handleEdit(dynamic request) {
    final isRTL = locale.toString() == 'ar';
    final customerNameController = TextEditingController(text: request['customerName'] ?? '');
    final customerPhoneController = TextEditingController(text: request['customerPhone'] ?? '');
    final notesController = TextEditingController(text: request['notes'] ?? '');
    final malfunctionController = TextEditingController(text: request['maintenanceCategoryNotes'] ?? '');
    bool isSubmitting = false;

    // Extract product info
    final product = request['product'];
    String productImage = '';
    if (product != null && product['image'] != null) {
      productImage = _extractImageUrl(product['image']);
    }
    final productName = _getProductName(request);
    final productSerial = request['productSerialNumber'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            child: Dialog(
              backgroundColor: Colors.grey[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: 650),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Header with close button
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${AppLocalizations.of(context)!.edit} ${AppLocalizations.of(context)!.maintenance_requests}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                          icon: Icon(Icons.close, color: Colors.grey[600], size: 22),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  
                  // Form Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          // Product Card
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                // Product Image
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: productImage.isNotEmpty
                                        ? FancyShimmerImage(
                                            imageUrl: productImage,
                                            boxFit: BoxFit.contain,
                                            errorWidget: Icon(Icons.image, size: 30, color: Colors.grey),
                                          )
                                        : Icon(Icons.image, size: 30, color: Colors.grey),
                                  ),
                                ),
                                SizedBox(width: 12),
                                // Product Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
                                      ),
                                      SizedBox(height: 4),
                                      Align(
                                        alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Text(
                                          productSerial,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                          textDirection: TextDirection.ltr,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          
                          // Customer Name
                          _buildSimpleField(
                            context,
                            AppLocalizations.of(context)!.customer_name,
                            customerNameController,
                            isRTL,
                          ),
                          SizedBox(height: 16),
                          
                          // Customer Phone
                          _buildSimpleField(
                            context,
                            AppLocalizations.of(context)!.customer_phone,
                            customerPhoneController,
                            isRTL,
                            keyboardType: TextInputType.phone,
                          ),
                          SizedBox(height: 16),
                          
                          // Malfunction Description
                          _buildSimpleField(
                            context,
                            AppLocalizations.of(context)!.malfunction_description,
                            malfunctionController,
                            isRTL,
                            maxLines: 3,
                            isRequired: false,
                            fontSize: 11,
                          ),
                          SizedBox(height: 16),
                          
                          // Notes
                          _buildSimpleField(
                            context,
                            AppLocalizations.of(context)!.notes,
                            notesController,
                            isRTL,
                            maxLines: 3,
                            isRequired: false,
                            fontSize: 11,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Action Buttons
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(
                      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                      children: [
                        // Cancel Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFF5F5F5),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.cancel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Save Changes Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () async {
                              // Validate
                              if (customerNameController.text.trim().isEmpty ||
                                  customerPhoneController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(context)!.please_fill_required_fields,
                                      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);

                              try {
                                await editMaintanenceRequest(
                                  request['id'],
                                  customerPhoneController.text.trim(),
                                  customerNameController.text.trim(),
                                  notesController.text.trim(),
                                  malfunctionController.text.trim(),
                                  context,
                                );

                                Navigator.pop(dialogContext);
                                await fetchMaintenanceRequests();
                              } catch (e) {
                                if (kDebugMode) {
                                  print('Error updating maintenance request: $e');
                                }
                                setDialogState(() => isSubmitting = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFf04444),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isSubmitting
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    AppLocalizations.of(context)!.save_changes,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimpleField(
    BuildContext context,
    String label,
    TextEditingController controller,
    bool isRTL, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isRequired = true,
    double fontSize = 15,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              isRequired ? '$label *' : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: isRTL ? TextAlign.right : TextAlign.left,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textDirection: keyboardType == TextInputType.phone ? TextDirection.ltr : null,
          textAlign: keyboardType == TextInputType.phone ? (isRTL ? TextAlign.right : TextAlign.left) : (isRTL ? TextAlign.right : TextAlign.left),
          style: TextStyle(fontSize: fontSize),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = locale.toString() == 'ar';
    
    return Container(
      color: MAIN_COLOR,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Color(0xFFF5F5F5),
          drawer: DrawerWell(
            Refresh: () async {
              await fetchMaintenanceRequests();
            },
          ),
          body: isLoading
              ? Center(
                  child: SpinKitCircle(
                    color: MAIN_COLOR,
                    size: 50.0,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchMaintenanceRequests,
                  color: MAIN_COLOR,
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: MAIN_COLOR,
                          ),
                          child: Builder(
                            builder: (BuildContext context) {
                              return Row(
                                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                children: [
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(Icons.arrow_back, color: Colors.white),
                                  ),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)!.maintenance_requests,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                    ),
                                  ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        Scaffold.of(context).openDrawer();
                                      },
                                      icon: SvgPicture.asset(
                                        'assets/images/Menu.svg',
                                        width: 25,
                                        height: 25,
                                        fit: BoxFit.contain,
                                        colorFilter: ColorFilter.mode(
                                          Colors.white,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      // Status Summary
                      SliverToBoxAdapter(
                        child: Container(
                          color: MAIN_COLOR,
                          child: StatusSummaryWidget(
                            scheduledCount: pendingCount,
                            inProgressCount: inProgressCount,
                            completedCount: doneCount,
                          ),
                        ),
                      ),

                      // Filter Tabs
                      SliverToBoxAdapter(
                        child: FilterTabsWidget(
                          selectedTab: selectedFilter,
                          onTabSelected: onFilterChanged,
                          allCount: allMaintenanceRequests.length,
                          scheduledCount: pendingCount,
                          inProgressCount: inProgressCount,
                          completedCount: doneCount,
                          overdueCount: deliveredCount,
                        ),
                      ),

                      // List of Maintenance Requests
                      filteredRequests.isEmpty
                          ? SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      AppLocalizations.of(context)!.empty_maintencaes,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index < filteredRequests.length) {
                                    final request = filteredRequests[index];
                                    final product = request['product'];
                                    
                                    String productImage = '';
                                    if (product != null && product['image'] != null) {
                                      productImage = _extractImageUrl(product['image']);
                                    }

                                    return MaintenanceCardWidget(
                                      productImage: productImage,
                                      productName: _getProductName(request),
                                      productSerialNumber:
                                          request['productSerialNumber'] ?? '',
                                      status: request['status'] ?? '',
                                      scheduledDate:
                                          request['createdAt'] ?? '',
                                      customerName:
                                          request['customerName'] ?? '',
                                      customerPhone:
                                          request['customerPhone'] ?? '',
                                      maintenanceCategoryNotes:
                                          request['maintenanceCategoryNotes'] ?? '',
                                      notes: request['notes'] ?? '',
                                      onViewReport: () =>
                                          _handleViewReport(request),
                                      onEdit: () =>
                                          _handleEdit(request),
                                    );
                                  } else {
                                    return Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: SpinKitCircle(
                                          color: MAIN_COLOR,
                                          size: 30.0,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                childCount: filteredRequests.length + (isLoadingMore ? 1 : 0),
                              ),
                            ),
                    ],
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddMaintanenceRequest(prodSerialNumber: ''),
                ),
              );
              // Refresh the list when returning from add page
              if (mounted) {
                await fetchMaintenanceRequests();
              }
            },
            // mini: true,
            backgroundColor: Color(0xFFEF4444),
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 20,
            ),
            tooltip: AppLocalizations.of(context)!.new_maintenance_requests,
          ),
        ),
      ),
    );
  }
}
