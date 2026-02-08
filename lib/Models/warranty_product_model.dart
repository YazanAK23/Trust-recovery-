/// Model class for warranty products
class WarrantyProductModel {
  final String serialNumber;
  final String? productName;
  final String? productImage;
  final int? productId;
  bool isValidated;
  bool isActive;
  String? errorMessage;

  WarrantyProductModel({
    required this.serialNumber,
    this.productName,
    this.productImage,
    this.productId,
    this.isValidated = false,
    this.isActive = false,
    this.errorMessage,
  });

  /// Validates the serial number format (must have at least 2 parts separated by dashes)
  static bool isValidSerialFormat(String serial) {
    if (serial.isEmpty) return false;
    final parts = serial.split('-');
    if (parts.length < 2) return false;
    // Each part should contain at least one digit
    for (var part in parts) {
      if (part.isEmpty || !RegExp(r'\d').hasMatch(part)) {
        return false;
      }
    }
    return true;
  }

  /// Gets the first two parts of the serial number
  String get firstTwoParts {
    final parts = serialNumber.split('-');
    if (parts.length >= 2) {
      return '${parts[0]}-${parts[1]}';
    }
    return serialNumber;
  }

  /// Copy with method for immutability
  WarrantyProductModel copyWith({
    String? serialNumber,
    String? productName,
    String? productImage,
    int? productId,
    bool? isValidated,
    bool? isActive,
    String? errorMessage,
  }) {
    return WarrantyProductModel(
      serialNumber: serialNumber ?? this.serialNumber,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      productId: productId ?? this.productId,
      isValidated: isValidated ?? this.isValidated,
      isActive: isActive ?? this.isActive,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convert to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'serialNumber': serialNumber,
      'productId': productId,
      'productName': productName,
    };
  }
}
