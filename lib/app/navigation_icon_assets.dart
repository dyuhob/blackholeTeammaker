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
  static const participantRemove = 'assets/navigation/x-outline-96x96.png';
  static const participantAdd = 'assets/navigation/add-outline-96x96.png';
  static const gallerySave = 'assets/navigation/image-down-outline-96x96.png';
  static const share = 'assets/navigation/share-outline-96x96.png';
  static const recordSave = 'assets/navigation/floppy2-outline-96x96.png';
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

class BorderedAssetIconButton extends StatelessWidget {
  const BorderedAssetIconButton({
    super.key,
    required this.assetPath,
    required this.tooltip,
    required this.onPressed,
    this.size = 36,
    this.iconSize = 20,
  });

  final String assetPath;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      iconSize: iconSize,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.white,
        disabledForegroundColor: Colors.black38,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: ImageIcon(AssetImage(assetPath)),
    ),
  );
}

class CircularAssetIconButton extends StatelessWidget {
  const CircularAssetIconButton({
    super.key,
    required this.assetPath,
    required this.tooltip,
    required this.onPressed,
    this.size = 24,
    this.iconSize = 14,
    this.backgroundColor = const Color(0xFFF3F4F6),
  });

  final String assetPath;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox.square(
      dimension: size,
      child: Material(
        color: backgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: ImageIcon(
              AssetImage(assetPath),
              size: iconSize,
              color: onPressed == null ? Colors.black38 : Colors.black,
            ),
          ),
        ),
      ),
    ),
  );
}
