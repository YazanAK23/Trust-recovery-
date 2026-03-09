import 'dart:convert';

class CatalogModel {
  final int id;
  final String pageTitle;
  final String pageDescription;
  final int totalProducts;
  final String type;
  final String pageSvg;
  final String typeSvg;
  final String coverImage;
  final String pdfFile;
  final String edition;
  final String catalogTitle;
  final String catalogDescription;
  final String pages;
  final String size;
  final List<CatalogTranslation> translations;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CatalogModel({
    required this.id,
    required this.pageTitle,
    required this.pageDescription,
    required this.totalProducts,
    required this.type,
    required this.pageSvg,
    required this.typeSvg,
    required this.coverImage,
    required this.pdfFile,
    required this.edition,
    required this.catalogTitle,
    required this.catalogDescription,
    required this.pages,
    required this.size,
    required this.translations,
    this.createdAt,
    this.updatedAt,
  });

  /// Parse URL from JSON string or list
  String _parseUrlFromJson(String jsonString) {
    try {
      if (jsonString.isEmpty || jsonString == '[]') return '';
      
      // Try to parse as JSON
      final parsed = jsonDecode(jsonString);
      
      if (parsed is List && parsed.isNotEmpty) {
        final firstItem = parsed[0];
        if (firstItem is Map && firstItem.containsKey('download_link')) {
          return firstItem['download_link'].toString();
        } else if (firstItem is String) {
          return firstItem;
        }
      } else if (parsed is String) {
        return parsed;
      }
    } catch (e) {
      // If parsing fails, return the raw string (might be a direct URL)
      if (jsonString != '[]') {
        return jsonString;
      }
    }
    return '';
  }

  /// Parse page SVG icon URL
  String get pageSvgUrl => _parseUrlFromJson(pageSvg);

  /// Parse type SVG icon URL
  String get typeSvgUrl => _parseUrlFromJson(typeSvg);

  /// Parse cover image URL from JSON string or list
  String get coverImageUrl => _parseUrlFromJson(coverImage);

  /// Parse PDF file URL from JSON string or list
  String get pdfFileUrl => _parseUrlFromJson(pdfFile);

  /// Get localized value for a specific field
  String getLocalizedValue(String columnName, String locale) {
    // Check if locale contains 'ar' (handles 'ar', 'ar_SA', etc.)
    final isArabic = locale.toLowerCase().contains('ar');
    
    if (isArabic && translations.isNotEmpty) {
      try {
        // Find translation for the specific column in Arabic
        final translation = translations.firstWhere(
          (t) => t.columnName == columnName && t.locale == 'ar',
        );
        
        // Return translation if it's not empty
        if (translation.value.isNotEmpty) {
          return translation.value;
        }
      } catch (e) {
        // Translation not found, will use default below
      }
    }
    
    // Return default English value based on column name
    return _getDefaultValue(columnName);
  }
  
  String _getDefaultValue(String columnName) {
    switch (columnName) {
      case 'page_title':
        return pageTitle;
      case 'page_description':
        return pageDescription;
      case 'catalog_title':
        return catalogTitle;
      case 'catalog_description':
        return catalogDescription;
      case 'edition':
        return edition;
      case 'type':
        return type;
      default:
        return '';
    }
  }

  factory CatalogModel.fromJson(Map<String, dynamic> json) {
    return CatalogModel(
      id: json['id'] ?? 0,
      pageTitle: json['pageTitle']?.toString() ?? '',
      pageDescription: json['pageDescription']?.toString() ?? '',
      totalProducts: json['totalProducts'] ?? 0,
      type: json['type']?.toString() ?? '',
      pageSvg: json['pageSvg']?.toString() ?? '[]',
      typeSvg: json['typeSvg']?.toString() ?? '[]',
      coverImage: json['coverImage']?.toString() ?? '[]',
      pdfFile: json['pdfFile']?.toString() ?? '[]',
      edition: json['edition']?.toString() ?? '',
      catalogTitle: json['catalogTitle']?.toString() ?? '',
      catalogDescription: json['catalogDescription']?.toString() ?? '',
      pages: json['pages']?.toString() ?? '0',
      size: json['size']?.toString() ?? '0MB',
      translations: (json['translations'] as List?)
          ?.map((t) => CatalogTranslation.fromJson(t))
          .toList() ?? [],
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageTitle': pageTitle,
      'pageDescription': pageDescription,
      'pageSvg': pageSvg,
      'typeSvg': typeSvg,
      'totalProducts': totalProducts,
      'type': type,
      'coverImage': coverImage,
      'pdfFile': pdfFile,
      'edition': edition,
      'catalogTitle': catalogTitle,
      'catalogDescription': catalogDescription,
      'pages': pages,
      'size': size,
      'translations': translations.map((t) => t.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  CatalogModel copyWith({
    int? id,
    String? pageTitle,
    String? pageDescription,
    int? totalProducts,
    String? type,
    String? pageSvg,
    String? typeSvg,
    String? coverImage,
    String? pdfFile,
    String? edition,
    String? catalogTitle,
    String? catalogDescription,
    String? pages,
    String? size,
    List<CatalogTranslation>? translations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CatalogModel(
      id: id ?? this.id,
      pageTitle: pageTitle ?? this.pageTitle,
      pageDescription: pageDescription ?? this.pageDescription,
      totalProducts: totalProducts ?? this.totalProducts,
      type: type ?? this.type,
      pageSvg: pageSvg ?? this.pageSvg,
      typeSvg: typeSvg ?? this.typeSvg,
      coverImage: coverImage ?? this.coverImage,
      pdfFile: pdfFile ?? this.pdfFile,
      edition: edition ?? this.edition,
      catalogTitle: catalogTitle ?? this.catalogTitle,
      catalogDescription: catalogDescription ?? this.catalogDescription,
      pages: pages ?? this.pages,
      size: size ?? this.size,
      translations: translations ?? this.translations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CatalogTranslation {
  final int id;
  final String tableName;
  final String columnName;
  final int foreignKey;
  final String locale;
  final String value;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CatalogTranslation({
    required this.id,
    required this.tableName,
    required this.columnName,
    required this.foreignKey,
    required this.locale,
    required this.value,
    this.createdAt,
    this.updatedAt,
  });

  factory CatalogTranslation.fromJson(Map<String, dynamic> json) {
    return CatalogTranslation(
      id: json['id'] ?? 0,
      tableName: json['table_name']?.toString() ?? '',
      columnName: json['column_name']?.toString() ?? '',
      foreignKey: json['foreign_key'] ?? 0,
      locale: json['locale']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_name': tableName,
      'column_name': columnName,
      'foreign_key': foreignKey,
      'locale': locale,
      'value': value,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
