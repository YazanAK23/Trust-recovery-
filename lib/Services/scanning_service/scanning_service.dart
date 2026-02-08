import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';

/// Service for handling barcode and OCR scanning
class ScanningService {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Scan barcode using camera
  static Future<String?> scanBarcode(BuildContext context) async {
    String? result;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _BarcodeScannerScreen(
          onBarcodeDetected: (barcode) {
            result = barcode;
          },
        ),
      ),
    );

    return result;
  }

  /// Scan text from image using OCR
  static Future<String?> scanFromImage(BuildContext context) async {
    try {
      // Show dialog to choose source
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.choose_image_source),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Color(0xffD51C29)),
                  title: Text(AppLocalizations.of(context)!.camera),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xffD51C29)),
                  title: Text(AppLocalizations.of(context)!.gallery),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return null;

      // Pick image from selected source
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image == null) return null;

      // Process image with ML Kit
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      // Extract serial number pattern (flexible format with dashes)
      final serialPattern = RegExp(r'\d+-\d+(?:-\d+)*');
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final match = serialPattern.firstMatch(line.text);
          if (match != null) {
            return match.group(0);
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error scanning image: $e');
      return null;
    }
  }

  /// Take photo and extract text
  static Future<String?> scanFromCamera(BuildContext context) async {
    try {
      // Take photo
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (image == null) return null;

      // Process image with ML Kit
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      // Extract serial number pattern (flexible format with dashes)
      final serialPattern = RegExp(r'\d+-\d+(?:-\d+)*');
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final match = serialPattern.firstMatch(line.text);
          if (match != null) {
            return match.group(0);
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      return null;
    }
  }
}

/// Barcode scanner screen
class _BarcodeScannerScreen extends StatefulWidget {
  final Function(String) onBarcodeDetected;

  const _BarcodeScannerScreen({required this.onBarcodeDetected});

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isDetected = false;
  String? _detectedValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: const Color(0xffD51C29),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isDetected) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !_isDetected) {
                  setState(() {
                    _isDetected = true;
                    _detectedValue = barcode.rawValue;
                  });
                  
                  // Show success feedback
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (mounted) {
                      widget.onBarcodeDetected(barcode.rawValue!);
                      Navigator.pop(context);
                    }
                  });
                  return;
                }
              }
            },
          ),
          // Scanning frame overlay
          Center(
            child: Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isDetected ? Colors.green : Colors.white,
                  width: _isDetected ? 4 : 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isDetected
                  ? Container(
                      color: Colors.green.withOpacity(0.3),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 60,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Barcode Detected!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _isDetected ? Colors.green : Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isDetected
                      ? 'Success! Serial: $_detectedValue'
                      : 'Position barcode within frame',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
