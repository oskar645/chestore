import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PhotoViewerScreen extends StatelessWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photoUrls,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final controller = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${initialIndex + 1}/${photoUrls.length}'),
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: photoUrls.length,
        itemBuilder: (_, i) {
          final url = photoUrls[i];
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
