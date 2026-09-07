import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';

import '../domain/team_result.dart';
import '../features/history/team_result_content.dart';

abstract interface class GalleryExporter {
  Future<void> save(BuildContext context, TeamResult result);
}

class GalleryExportService implements GalleryExporter {
  const GalleryExportService();

  @override
  Future<void> save(BuildContext context, TeamResult result) async {
    final bytes = await ScreenshotController().captureFromLongWidget(
      InheritedTheme.captureAll(
        context,
        Material(
          color: Colors.white,
          child: TeamResultExportWidget(result: result),
        ),
      ),
      context: context,
      constraints: const BoxConstraints(maxWidth: 720),
      pixelRatio: 2,
      delay: const Duration(milliseconds: 50),
    );
    final safeTitle = result.title.replaceAll(
      RegExp(r'[^0-9A-Za-z가-힣_-]'),
      '_',
    );
    await Gal.putImageBytes(
      bytes,
      album: '팀짜기',
      name: '${safeTitle}_${result.createdAt.millisecondsSinceEpoch}',
    );
  }
}
