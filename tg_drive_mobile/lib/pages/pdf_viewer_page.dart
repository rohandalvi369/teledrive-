import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfViewerPage extends StatefulWidget {
  final String path;
  final String fileName;

  const PdfViewerPage({
    super.key,
    required this.path,
    required this.fileName,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$_currentPage / $_totalPages',
          style: const TextStyle(fontSize: 14),
        ),
        bottom: _ready
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _totalPages > 0 ? (_currentPage + 1) / _totalPages : 0,
                ),
              )
            : null,
      ),
      body: PDFView(
        filePath: widget.path,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        onRender: (pages) {
          if (mounted) setState(() => _totalPages = pages ?? 0);
        },
        onViewCreated: (ctrl) {
          setState(() => _ready = true);
        },
        onPageChanged: (page, total) {
          if (mounted) setState(() {
            _currentPage = page ?? 0;
            _totalPages = total ?? 0;
          });
        },
      ),
    );
  }
}
