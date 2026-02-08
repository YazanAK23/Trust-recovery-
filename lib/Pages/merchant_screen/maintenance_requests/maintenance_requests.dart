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
    "pending": "بانتظار التوصيل للصيانة",
    "in_progress": "في الصيانة",
    "done": "تم الصيانة",
    "delivered": "تم التسليم للتاجر"
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
          body: Column(
            children: [
              // Header
              Container(
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

              // Status Summary with unified background
              Container(
                color: MAIN_COLOR,
                child: !isLoading
                    ? StatusSummaryWidget(
                        scheduledCount: pendingCount,
                        inProgressCount: inProgressCount,
                        completedCount: doneCount,
                      )
                    : SizedBox.shrink(),
              ),

              // Filter Tabs
              if (!isLoading)
                FilterTabsWidget(
                  selectedTab: selectedFilter,
                  onTabSelected: onFilterChanged,
                  allCount: allMaintenanceRequests.length,
                  scheduledCount: pendingCount,
                  inProgressCount: inProgressCount,
                  completedCount: doneCount,
                  overdueCount: deliveredCount,
                ),

              // List of Maintenance Requests
              Expanded(
                child: isLoading
                    ? Center(
                        child: SpinKitCircle(
                          color: MAIN_COLOR,
                          size: 50.0,
                        ),
                      )
                    : filteredRequests.isEmpty
                        ? Center(
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
                          )
                        : RefreshIndicator(
                            onRefresh: fetchMaintenanceRequests,
                            color: MAIN_COLOR,
                            child: ListView.builder(
                              controller: scrollController,
                              physics: AlwaysScrollableScrollPhysics(),
                              itemCount: filteredRequests.length +
                                  (isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
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
                            ),
                          ),
              ),
            ],
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
            backgroundColor: MAIN_COLOR,
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 30,
            ),
            tooltip: AppLocalizations.of(context)!.new_maintenance_requests,
          ),
        ),
      ),
    );
  }
}
