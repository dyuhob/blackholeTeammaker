import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../domain/team_result.dart';
import 'gallery_exporter.dart';
import 'team_result_image_renderer.dart';
import 'team_result_share.dart';

class WebGalleryExportService implements GalleryExporter {
  const WebGalleryExportService();

  @override
  String get actionLabel => '갤러리 저장';

  @override
  String get busyLabel => '준비 중…';

  @override
  String get successMessage => '이미지를 다운로드했습니다.';

  @override
  String get failureMessage => '이미지를 다운로드하지 못했습니다.';

  @override
  Future<void> save(BuildContext context, TeamResult result) async {
    final bytes = await captureTeamResultImage(context, result);
    final blob = web.Blob(
      <web.BlobPart>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final objectUrl = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = '${teamResultImageName(result)}.png'
      ..style.display = 'none';
    web.document.body!.appendChild(anchor);
    try {
      anchor.click();
    } finally {
      anchor.remove();
      web.URL.revokeObjectURL(objectUrl);
    }
  }

  @override
  Future<void> share(BuildContext context, TeamResult result) =>
      shareTeamResultImage(context, result);
}
