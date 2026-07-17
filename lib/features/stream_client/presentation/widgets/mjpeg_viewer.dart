import 'dart:typed_data';

import 'package:flutter/material.dart';

class MjpegViewerWidget extends StatefulWidget {
  final Stream<Uint8List> frameStream;

  const MjpegViewerWidget({
    super.key,
    required this.frameStream,
  });

  @override
  State<MjpegViewerWidget> createState() => _MjpegViewerWidgetState();
}

class _MjpegViewerWidgetState extends State<MjpegViewerWidget> {
  Uint8List? _latestFrame;

  @override
  void initState() {
    super.initState();
    widget.frameStream.listen(
      (frame) {
        if (mounted) {
          setState(() {
            _latestFrame = frame;
          });
        }
      },
      onError: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_latestFrame == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 16),
              Text(
                'Esperando stream...',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: Image.memory(
          _latestFrame!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
