import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:trust_app_updated/Components/drawer_widget/drawer_widget.dart';
import 'package:trust_app_updated/Server/domains/domains.dart';
import 'package:trust_app_updated/Server/functions/functions.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import 'package:trust_app_updated/main.dart';

class CatalogsScreen extends StatefulWidget {
  const CatalogsScreen({Key? key}) : super(key: key);

  @override
  State<CatalogsScreen> createState() => _CatalogsScreenState();
}

class _CatalogsScreenState extends State<CatalogsScreen> {
  List<dynamic> _allCatalogs = [];
  List<dynamic> _filteredCatalogs = [];
  String _selectedType = 'summer';
  bool _isLoading = true;
  final List<String> _catalogTypes = ['summer', 'standard', 'winter'];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('http://app.redtrust.ps:3003/catalogs'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _allCatalogs = data['response']['data'] ?? [];
            _applyFilter();
          });
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error loading catalogs');
      print('Catalog load error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    _filteredCatalogs = _allCatalogs
        .where((catalog) => catalog['type']?.toLowerCase() == _selectedType)
        .toList();
  }

  String _getLocalizedValue(dynamic catalog, String columnName, String defaultValue) {
    final isArabic = locale.toString() == 'ar';
    
    if (isArabic && catalog['translations'] != null) {
      final translations = catalog['translations'] as List;
      final translation = translations.firstWhere(
        (t) => t['column_name'] == columnName && t['locale'] == 'ar',
        orElse: () => null,
      );
      if (translation != null && translation['value'] != null) {
        return translation['value'];
      }
    }
    
    return defaultValue;
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'summer':
        return Icons.wb_sunny;
      case 'winter':
        return Icons.ac_unit;
      case 'standard':
        return Icons.star;
      default:
        return Icons.description;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'summer':
        return AppLocalizations.of(context)!.summer;
      case 'winter':
        return AppLocalizations.of(context)!.winter;
      case 'standard':
        return AppLocalizations.of(context)!.standard;
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      drawer: DrawerWell(Refresh: () {
        setState(() {});
      }),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD51C29)))
          : Column(
              children: [
                // Fixed Red Header Area
                Container(
                  width: double.infinity,
                  color: const Color(0xFFD51C29),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        // AppBar
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.product_catalogs,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                icon: SvgPicture.asset(
                                  'assets/images/Menu.svg',
                                  color: Colors.white,
                                  width: 24,
                                  height: 24,
                                ),
                                onPressed: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        // Header Content
                        if (_filteredCatalogs.isNotEmpty) _buildHeaderContent(),
                      ],
                    ),
                  ),
                ),
                
                // Filter Tabs
                _buildFilterTabs(),
                
                // Scrollable Catalog List
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFD51C29),
                    onRefresh: _loadCatalogs,
                    child: _filteredCatalogs.isEmpty
                        ? Center(
                            child: Text(
                              AppLocalizations.of(context)!.no_catalogs_available,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredCatalogs.length,
                            itemBuilder: (context, index) {
                              return _buildCatalogCard(_filteredCatalogs[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderContent() {
    final firstCatalog = _filteredCatalogs.first;
    final pageTitle = _getLocalizedValue(
      firstCatalog,
      'page_title',
      firstCatalog['pageTitle'] ?? '',
    );
    final pageDescription = _getLocalizedValue(
      firstCatalog,
      'page_description',
      firstCatalog['pageDescription'] ?? '',
    );
    final totalProducts = firstCatalog['totalProducts'] ?? 0;
    final type = firstCatalog['type'] ?? '';

    return Container(
      color: const Color(0xFFD51C29),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(type),
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            pageTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Description
          Text(
            pageDescription,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Total Products
          Text(
            '${AppLocalizations.of(context)!.total_products}: $totalProducts',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _catalogTypes.length,
        itemBuilder: (context, index) {
          final type = _catalogTypes[index];
          final isSelected = _selectedType == type;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedType = type;
                _applyFilter();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD51C29) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFFD51C29) : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getTypeIcon(type),
                    size: 16,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _getTypeLabel(type),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCatalogCard(dynamic catalog) {
    final catalogTitle = _getLocalizedValue(
      catalog,
      'catalog_title',
      catalog['catalogTitle'] ?? '',
    );
    final catalogDescription = _getLocalizedValue(
      catalog,
      'catalog_description',
      catalog['catalogDescription'] ?? '',
    );
    final edition = _getLocalizedValue(
      catalog,
      'edition',
      catalog['edition'] ?? '',
    );
    final totalProducts = catalog['totalProducts'] ?? 0;
    final pages = catalog['pages'] ?? '0';
    final size = catalog['size'] ?? '0MB';
    final pdfFile = catalog['pdfFile'] ?? '[]';

    // Parse PDF file
    String pdfUrl = '';
    try {
      final pdfData = jsonDecode(pdfFile);
      if (pdfData is List && pdfData.isNotEmpty) {
        pdfUrl = URLIMAGE + pdfData[0];
      }
    } catch (e) {
      if (pdfFile.isNotEmpty && pdfFile != '[]') {
        pdfUrl = URLIMAGE + pdfFile;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Stack(
              children: [
                // Placeholder image with icon
                Center(
                  child: Icon(
                    Icons.kitchen,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                ),
                // Edition badge
                if (edition.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        edition,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Content
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFD51C29),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  catalogTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Description
                Text(
                  catalogDescription,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Stats
                Row(
                  children: [
                    _buildStat(
                      totalProducts.toString(),
                      AppLocalizations.of(context)!.products_label,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      '$pages+',
                      AppLocalizations.of(context)!.pages_label,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      size,
                      AppLocalizations.of(context)!.size_label,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Share and Preview Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pdfUrl.isNotEmpty
                            ? () {
                                // Share the PDF URL
                                Fluttertoast.showToast(
                                  msg: 'Share: $pdfUrl',
                                  toastLength: Toast.LENGTH_SHORT,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(
                          AppLocalizations.of(context)!.share,
                        ),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(Colors.white),
                          foregroundColor: MaterialStateProperty.all(const Color(0xFFD51C29)),
                          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          elevation: MaterialStateProperty.all(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pdfUrl.isNotEmpty
                            ? () {
                                // Preview functionality - open PDF
                                downloadAndOpenFile(
                                  context,
                                  pdfUrl,
                                  'catalog_${catalog['id']}.pdf',
                                );
                              }
                            : null,
                        icon: const Icon(Icons.visibility, size: 18),
                        label: Text(
                          AppLocalizations.of(context)!.preview,
                        ),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(Colors.white),
                          foregroundColor: MaterialStateProperty.all(const Color(0xFFD51C29)),
                          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          elevation: MaterialStateProperty.all(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Download Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: pdfUrl.isNotEmpty
                        ? () {
                            downloadAndOpenFile(
                              context,
                              pdfUrl,
                              'catalog_${catalog['id']}.pdf',
                            );
                          }
                        : null,
                    icon: const Icon(Icons.download, size: 20),
                    label: Text(
                      AppLocalizations.of(context)!.download_pdf_catalog,
                    ),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.white),
                      foregroundColor: MaterialStateProperty.all(const Color(0xFFD51C29)),
                      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      elevation: MaterialStateProperty.all(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
