import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../domain/team_result.dart';
import 'gallery_exporter.dart';
import 'team_result_image_renderer.dart';
import 'team_result_share.dart';

class GalleryExportService implements GalleryExporter {
  const GalleryExportService();

  @override
  String get actionLabel => '갤러리 저장';

  @override
  String get busyLabel => '이미지 생성 중…';

  @override
  String get successMessage => '갤러리에 저장했습니다.';

  @override
  String get failureMessage => '갤러리에 저장하지 못했습니다.';

  @override
  Future<void> save(BuildContext context, TeamResult result) async {
    final bytes = await captureTeamResultImage(context, result);
    await Gal.putImageBytes(
      bytes,
      album: '팀짜기',
      name: teamResultImageName(result),
    );
  }

  @override
  Future<void> share(BuildContext context, TeamResult result) =>
      shareTeamResultImage(context, result);
}
