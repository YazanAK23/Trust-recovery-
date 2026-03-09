import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfPreviewScreen({
    Key? key,
    required this.pdfUrl,
    required this.title,
  }) : super(key: key);

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  String? _localFilePath;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Download the PDF file
      final response = await http.get(Uri.parse(widget.pdfUrl));
      
      if (response.statusCode == 200) {
        // Get temporary directory
        final dir = await getTemporaryDirectory();
        final fileName = 'catalog_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${dir.path}/$fileName');
        
        // Write the file
        await file.writeAsBytes(response.bodyBytes);
        
        setState(() {
          _localFilePath = file.path;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to download PDF: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error downloading PDF: $e';
        _isLoading = false;
      });
    }
  }

  void _sharePdf() {
    Share.share(
      '${AppLocalizations.of(context)!.download_pdf_catalog}\n\n${widget.title}\n\n${widget.pdfUrl}',
      subject: widget.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFD51C29),
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePdf,
            tooltip: AppLocalizations.of(context)!.share,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _localFilePath != null && _totalPages > 0
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Text(
                '${AppLocalizations.of(context)!.pages_label}: ${_currentPage + 1} / $_totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFD51C29),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD51C29)),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.download_pdf_catalog,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD51C29),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_localFilePath != null) {
      return PDFView(
        filePath: _localFilePath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        defaultPage: 0,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false,
        onRender: (pages) {
          setState(() {
            _totalPages = pages ?? 0;
          });
        },
        onError: (error) {
          setState(() {
            _errorMessage = 'Error displaying PDF: $error';
          });
        },
        onPageError: (page, error) {
          Fluttertoast.showToast(
            msg: 'Error on page $page: $error',
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: Colors.white,
            textColor: Colors.red,
            fontSize: 16.0,
          );
        },
        onViewCreated: (PDFViewController pdfViewController) {
          // You can store the controller if you need to control the PDF programmatically
        },
        onPageChanged: (int? page, int? total) {
          setState(() {
            _currentPage = page ?? 0;
            _totalPages = total ?? 0;
          });
        },
      );
    }

    return const Center(
      child: Text('No PDF to display'),
    );
  }

  @override
  void dispose() {
    // Clean up the temporary file
    if (_localFilePath != null) {
      try {
        final file = File(_localFilePath!);
        if (file.existsSync()) {
          file.delete();
        }
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    super.dispose();
  }
}
