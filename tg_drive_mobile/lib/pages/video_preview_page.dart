import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewPage extends StatefulWidget {
  final String path;
  final String fileName;

  const VideoPreviewPage({
    super.key,
    required this.path,
    required this.fileName,
  });

  @override
  State<VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<VideoPreviewPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(File(widget.path));
    await _controller!.initialize();
    if (mounted) {
      setState(() => _initialized = true);
      _controller!.play();
      _isPlaying = true;
    }
    _controller!.addListener(_onPlayerStateChanged);
  }

  void _onPlayerStateChanged() {
    if (!mounted) return;
    final playing = _controller!.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() => _isPlaying = playing);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.fileName, style: const TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: _initialized && _controller != null
            ? GestureDetector(
                onTap: () {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                    if (!_isPlaying)
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Loading video...', style: TextStyle(color: Colors.white54)),
                ],
              ),
      ),
    );
  }
}
