import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../ui/palette.dart';

/// Authenticated, memory-only media request. No public storage URLs or bearer tokens in URLs.
class PrivateAvatar extends StatefulWidget {
  const PrivateAvatar({
    required this.api, required this.userId, required this.name,
    this.photoId, this.size = 56, this.isOnline = false, super.key,
  });

  final ApiClient api;
  final String userId;
  final String name;
  final String? photoId;
  final double size;
  final bool isOnline;

  @override
  State<PrivateAvatar> createState() => _PrivateAvatarState();
}

class _PrivateAvatarState extends State<PrivateAvatar> {
  Future<Uint8List>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrivateAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId || oldWidget.userId != widget.userId) _load();
  }

  void _load() {
    _image = widget.photoId == null ? null : widget.api.photoBytes(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return ProfileAvatar(name: widget.name, size: widget.size, isOnline: widget.isOnline);
    }
    return FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return ProfileAvatar(name: widget.name, size: widget.size, isOnline: widget.isOnline);
        }
        return Stack(clipBehavior: Clip.none, children: [
          ClipOval(child: Image.memory(snapshot.data!, width: widget.size,
            height: widget.size, fit: BoxFit.cover,
            cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (context, error, stackTrace) => ProfileAvatar(name: widget.name, size: widget.size),
          )),
          if (widget.isOnline) Positioned(right: 0, bottom: 0, child: Container(
            height: widget.size * .24, width: widget.size * .24,
            decoration: BoxDecoration(color: Palette.mint, shape: BoxShape.circle,
              border: Border.all(color: Palette.surface, width: 2)),
          )),
        ]);
      },
    );
  }
}
