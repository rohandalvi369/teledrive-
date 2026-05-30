import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/drive_file.dart';

class ImagePreviewPage extends StatefulWidget {
  final List<DriveFile> images;
  final int initialIndex;

  const ImagePreviewPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final file = widget.images[index];
          return Hero(
            tag: 'image_${file.docId}',
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: _buildImage(file),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImage(DriveFile file) {
    if (file.localPath != null && file.localPath!.isNotEmpty) {
      return Image.file(
        File(file.localPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    if (file.thumbnailBase64 != null) {
      return Image.memory(
        base64Decode(file.thumbnailBase64!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image, size: 64, color: Colors.white24),
        SizedBox(height: 12),
        Text('Unable to load image',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
      ],
    );
  }
}
