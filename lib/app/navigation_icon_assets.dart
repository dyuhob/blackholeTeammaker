import 'package:flutter/material.dart';

abstract final class NavigationIconAssets {
  // PNG, WebP, JPEG 파일을 assets/navigation 아래에 넣은 뒤 경로를 지정하세요.
  // null이면 현재 Material 아이콘이 사용됩니다.
  static const String? membersOutline = null;
  static const String? membersFilled = null;
  static const String? teamsOutline = null;
  static const String? teamsFilled = null;
  static const String? historyOutline = null;
  static const String? historyFilled = null;
}

class NavigationTabIcon extends StatelessWidget {
  const NavigationTabIcon({
    super.key,
    required this.assetPath,
    required this.fallback,
  });

  final String? assetPath;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path == null || path.isEmpty) return Icon(fallback);
    return ImageIcon(AssetImage(path), size: 24);
  }
}
