import 'package:flutter/material.dart';

abstract final class NavigationIconAssets {
  static const membersOutline = 'assets/navigation/users3-outline-96x96.png';
  static const membersFilled = 'assets/navigation/users3-filled-96x96.png';
  static const teamsOutline = 'assets/navigation/bowling-outline-96x96.png';
  static const teamsFilled = 'assets/navigation/bowling-filled-96x96.png';
  static const historyOutline = 'assets/navigation/archive-outline-96x96.png';
  static const historyFilled = 'assets/navigation/archive-filled-96x96.png';

  static const memberDelete = 'assets/navigation/trash6-outline-96x96.png';
  static const buildTeams = 'assets/navigation/shuffle-outline-96x96.png';
  static const participantRemove =
      'assets/navigation/x-square-filled-96x96.png';
  static const participantAdd = 'assets/navigation/add-square-filled-96x96.png';
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
