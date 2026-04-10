import 'dart:convert';
import 'package:fancy_shimmer_image/fancy_shimmer_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:trust_app_updated/Components/drawer_widget/drawer_widget.dart';
import 'package:trust_app_updated/Models/catalog_model.dart';
import 'package:trust_app_updated/Pages/catalogs/pdf_preview_screen.dart';
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
  // Data
  List<CatalogModel> _allCatalogs = [];
  List<CatalogModel> _filteredCatalogs = [];
  List<String> _availableTypes = [];
  
  // State
  String _selectedType = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMorePages = false;
  final ScrollController _scrollController = ScrollController();
  
  // UI
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Locale tracking
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context);
    if (_currentLocale != null && _currentLocale != newLocale) {
      // Locale changed, reload catalogs to get proper localized type names
      _currentPage = 1;
      _hasMorePages = false;
      _loadCatalogs();
    }
    _currentLocale = newLocale;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMorePages) {
        _loadMoreCatalogs();
      }
    }
  }

  /// Load catalogs from API with robust error handling
  Future<void> _loadCatalogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });
    
    try {
      final response = await http.get(
        Uri.parse('http://app.redtrust.ps:3003/catalogs?page=1'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['response'] != null) {
          final catalogsData = data['response']['data'] as List? ?? [];
          
          // Parse pagination info
          _currentPage = data['response']['page'] ?? 1;
          _totalPages = data['response']['totalPages'] ?? 1;
          _hasMorePages = _currentPage < _totalPages;
          
          // Parse catalogs using the model with explicit type conversion
          final List<CatalogModel> parsedCatalogs = [];
          for (var json in catalogsData) {
            try {
              final catalog = CatalogModel.fromJson(json as Map<String, dynamic>);
              parsedCatalogs.add(catalog);
            } catch (e) {
              print('Error parsing catalog: $e');
            }
          }
          
          _allCatalogs = parsedCatalogs;
          
          // Extract unique catalog types dynamically from API using localized values
          final Set<String> uniqueTypes = {};
          final currentLocale = locale.toString();
          for (var catalog in _allCatalogs) {
            final localizedType = catalog.getLocalizedValue('type', currentLocale);
            if (localizedType.isNotEmpty) {
              uniqueTypes.add(localizedType);
            }
          }
          _availableTypes = uniqueTypes.toList();
          
          // Set initial filter to first available type from API
          if (_availableTypes.isNotEmpty) {
            _selectedType = _availableTypes[0];
          }
          
          _applyFilter();
        } else {
          _errorMessage = 'Invalid response format';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Failed to load catalogs: ${e.toString()}';
      print('Catalog load error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Load more catalogs for pagination
  Future<void> _loadMoreCatalogs() async {
    if (_isLoadingMore || !_hasMorePages) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final nextPage = _currentPage + 1;
      final response = await http.get(
        Uri.parse('http://app.redtrust.ps:3003/catalogs?page=$nextPage'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['response'] != null) {
          final catalogsData = data['response']['data'] as List? ?? [];
          
          // Update pagination info
          _currentPage = data['response']['page'] ?? nextPage;
          _totalPages = data['response']['totalPages'] ?? _totalPages;
          _hasMorePages = _currentPage < _totalPages;
          
          // Parse new catalogs
          final List<CatalogModel> parsedCatalogs = [];
          for (var json in catalogsData) {
            try {
              final catalog = CatalogModel.fromJson(json as Map<String, dynamic>);
              parsedCatalogs.add(catalog);
            } catch (e) {
              print('Error parsing catalog: $e');
            }
          }
          
          // Add to existing catalogs
          _allCatalogs.addAll(parsedCatalogs);
          
          // Update available types from API using localized values
          final Set<String> uniqueTypes = {};
          final currentLocale = locale.toString();
          for (var catalog in _allCatalogs) {
            final localizedType = catalog.getLocalizedValue('type', currentLocale);
            if (localizedType.isNotEmpty) {
              uniqueTypes.add(localizedType);
            }
          }
          _availableTypes = uniqueTypes.toList();
          
          _applyFilter();
        }
      }
    } catch (e) {
      print('Error loading more catalogs: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// Apply filter based on selected type from control panel
  void _applyFilter() {
    final currentLocale = locale.toString();
    _filteredCatalogs = _allCatalogs
        .where((catalog) {
          final localizedType = catalog.getLocalizedValue('type', currentLocale);
          return localizedType.toLowerCase() == _selectedType.toLowerCase();
        })
        .toList();
    
    if (mounted) {
      setState(() {});
    }
  }

  /// Get localized value for a catalog field
  String _getLocalizedValue(CatalogModel catalog, String columnName) {
    final currentLocale = locale.toString();
    return catalog.getLocalizedValue(columnName, currentLocale);
  }

  /// Get the type SVG URL for a catalog type
  String _getTypeSvgUrl(String type) {
    // Find a catalog with this localized type and return its typeSvg URL
    try {
      final currentLocale = locale.toString();
      final catalog = _allCatalogs.firstWhere(
        (c) => c.getLocalizedValue('type', currentLocale).toLowerCase() == type.toLowerCase(),
      );
      return catalog.typeSvgUrl;
    } catch (e) {
      return '';
    }
  }

  /// Get localized label for catalog type from API translations
  String _getTypeLabel(String type) {
    // The type is already localized, just return it
    return type.isEmpty ? type : 
      '${type[0].toUpperCase()}${type.substring(1)}';
  }

  /// Build type icon widget from API using dynamic SVG/image URL
  Widget _buildTypeIcon(String type, Color color, double size) {
    final svgUrl = _getTypeSvgUrl(type);
    final fullSvgUrl = svgUrl.isNotEmpty 
        ? (svgUrl.startsWith('http') ? svgUrl : URLIMAGE + svgUrl)
        : '';
    
    if (fullSvgUrl.isNotEmpty) {
      return _buildIconImage(fullSvgUrl, size, color);
    }
    
    // Fallback icon if no SVG from API
    return Icon(Icons.category, size: size, color: color);
  }

  /// Build icon from image URL (supports SVG and regular images)
  Widget _buildIconImage(String imageUrl, double size, Color color) {
    if (imageUrl.toLowerCase().endsWith('.svg')) {
      // SVG image
      return SvgPicture.network(
        imageUrl,
        width: size,
        height: size,
        color: color,
        placeholderBuilder: (context) => Icon(
          Icons.category,
          size: size,
          color: color,
        ),
      );
    } else {
      // Regular image (PNG, JPG, etc.)
      return Image.network(
        imageUrl,
        width: size,
        height: size,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.category,
          size: size,
          color: color,
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          );
        },
      );
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFEF4444)),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_allCatalogs.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      color: const Color(0xFFEF4444),
      onRefresh: _loadCatalogs,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Fixed Red Header Area
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFEF4444),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // AppBar
                    _buildAppBar(),
                    
                    // Header Content
                    if (_filteredCatalogs.isNotEmpty) _buildHeaderContent(),
                  ],
                ),
              ),
            ),
          ),
          
          // Filter Tabs (only if there are multiple types)
          if (_availableTypes.length > 1)
            SliverToBoxAdapter(
              child: _buildFilterTabs(),
            ),
          
          // Catalog List
          if (_filteredCatalogs.isEmpty)
            SliverFillRemaining(
              child: _buildNoResultsView(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < _filteredCatalogs.length) {
                      return _buildCatalogCard(_filteredCatalogs[index]);
                    } else {
                      // Loading indicator at bottom
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          color: Colors.white,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  childCount: _filteredCatalogs.length + (_isLoadingMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
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
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCatalogs,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.no_catalogs_available,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    final firstCatalog = _filteredCatalogs.first;
    final pageTitle = _getLocalizedValue(firstCatalog, 'page_title');
    final pageDescription = _getLocalizedValue(firstCatalog, 'page_description');
    final totalProducts = firstCatalog.totalProducts;
    final pageSvgUrl = firstCatalog.pageSvgUrl;
    final fullPageSvgUrl = pageSvgUrl.isNotEmpty 
        ? (pageSvgUrl.startsWith('http') ? pageSvgUrl : URLIMAGE + pageSvgUrl)
        : '';

    return Container(
      color: const Color(0xFFEF4444),
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFE57373).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dynamic Icon from API
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: fullPageSvgUrl.isNotEmpty
                    ? Center(
                        child: _buildIconImage(fullPageSvgUrl, 32, Colors.white),
                      )
                    : const Icon(
                        Icons.category,
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
              if (pageDescription.isNotEmpty)
                Text(
                  pageDescription,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
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
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _availableTypes.map((type) {
          final isSelected = _selectedType == type;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = type;
                  _applyFilter();
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEF4444) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEF4444) : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTypeIcon(type, isSelected ? Colors.white : Colors.grey[700]!, 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _getTypeLabel(type),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCatalogCard(CatalogModel catalog) {
    final catalogTitle = _getLocalizedValue(catalog, 'catalog_title');
    final catalogDescription = _getLocalizedValue(catalog, 'catalog_description');
    final edition = _getLocalizedValue(catalog, 'edition');
    final coverImageUrl = catalog.coverImageUrl;
    final pdfUrl = catalog.pdfFileUrl;
    
    // Build full URLs
    final fullCoverImageUrl = coverImageUrl.isNotEmpty 
        ? (coverImageUrl.startsWith('http') 
            ? coverImageUrl 
            : URLIMAGE + coverImageUrl)
        : '';
    
    final fullPdfUrl = pdfUrl.isNotEmpty 
        ? (pdfUrl.startsWith('http') 
            ? pdfUrl 
            : URLIMAGE + pdfUrl)
        : '';

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
                // Cover Image or Placeholder
                if (fullCoverImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: FancyShimmerImage(
                      imageUrl: fullCoverImageUrl,
                      width: double.infinity,
                      height: 180,
                      boxFit: BoxFit.cover,
                      errorWidget: Center(
                        child: Icon(
                          Icons.kitchen,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Icon(
                      Icons.kitchen,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                  ),
                
                // Edition badge
                if (edition.isNotEmpty)
                  PositionedDirectional(
                    top: 12,
                    end: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        edition,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                if (catalogDescription.isNotEmpty)
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
                      catalog.totalProducts.toString(),
                      AppLocalizations.of(context)!.products_label,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      '${catalog.pages}+',
                      AppLocalizations.of(context)!.pages_label,
                    ),
                    const SizedBox(width: 24),
                    _buildStat(
                      catalog.size,
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
                        onPressed: fullPdfUrl.isNotEmpty
                            ? () {
                                // Share the PDF URL
                                final title = _getLocalizedValue(
                                  catalog,
                                  'title',
                                );
                                final box = context.findRenderObject() as RenderBox?;
                                Share.share(
                                  '${AppLocalizations.of(context)!.download_pdf_catalog}\n\n$title\n\n$fullPdfUrl',
                                  subject: title,
                                  sharePositionOrigin: box != null
                                      ? Rect.fromLTWH(
                                          0,
                                          0,
                                          box.size.width,
                                          box.size.height,
                                        )
                                      : null,
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
                        onPressed: fullPdfUrl.isNotEmpty
                            ? () {
                                // Preview functionality - open PDF in-app
                                final title = _getLocalizedValue(
                                  catalog,
                                  'title',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PdfPreviewScreen(
                                      pdfUrl: fullPdfUrl,
                                      title: title,
                                    ),
                                  ),
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
                    onPressed: fullPdfUrl.isNotEmpty
                        ? () {
                            downloadAndOpenFile(
                              context,
                              fullPdfUrl,
                              'catalog_${catalog.id}.pdf',
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
