import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/team_result.dart';
import 'team_result_image_renderer.dart';

Future<void> shareTeamResultImage(
  BuildContext context,
  TeamResult result,
) async {
  final bytes = await captureTeamResultImage(context, result);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png')],
      fileNameOverrides: ['${teamResultImageName(result)}.png'],
      title: result.title,
      subject: result.title,
    ),
  );
}
