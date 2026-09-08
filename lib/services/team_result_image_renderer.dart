import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import '../domain/team_result.dart';
import '../features/history/team_result_content.dart';

Future<Uint8List> captureTeamResultImage(
  BuildContext context,
  TeamResult result,
) => ScreenshotController().captureFromLongWidget(
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

String teamResultImageName(TeamResult result) {
  final safeTitle = result.title.replaceAll(RegExp(r'[^0-9A-Za-z가-힣_-]'), '_');
  return '${safeTitle}_${result.createdAt.millisecondsSinceEpoch}';
}
