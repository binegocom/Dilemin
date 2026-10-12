import 'package:flutter/material.dart';

abstract final class Palette {
  static const canvas = Color(0xFF090B16);
  static const surface = Color(0xFF17192A);
  static const border = Color(0xFF302940);
  static const rose = Color(0xFFFA4B86);
  static const mint = Color(0xFF4CE0B6);
  static const secondary = Color(0xFFB7B7CA);
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.name, this.size = 56, this.isOnline = false, super.key});

  final String name;
  final double size;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final text = name.trim();
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFCC4786), Color(0xFF563FA9)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(color: Palette.border, width: 2),
        ),
        child: Center(child: Text(text.isEmpty ? '•' : text.characters.first.toUpperCase(),
          style: TextStyle(color: Colors.white, fontSize: size * .42, fontWeight: FontWeight.w700))),
      ),
      if (isOnline) Positioned(bottom: 0, right: 0, child: Container(
        width: size * .25, height: size * .25,
        decoration: BoxDecoration(color: Palette.mint, shape: BoxShape.circle,
          border: Border.all(color: Palette.surface, width: 2)),
      )),
    ]);
  }
}
