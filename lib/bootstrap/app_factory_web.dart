import 'package:flutter/widgets.dart';

import '../app/team_maker_app.dart';
import '../core/storage/browser_json_object_store.dart';
import '../data/json_member_repository.dart';
import '../data/json_team_history_repository.dart';
import '../data/json_workspace_repository.dart';
import '../services/web_gallery_export_service.dart';

Widget createApp() => TeamMakerApp(
  memberRepository: const JsonMemberRepository(
    BrowserJsonObjectStore('team_maker.members_v1'),
  ),
  historyRepository: const JsonTeamHistoryRepository(
    BrowserJsonObjectStore('team_maker.team_history_v1'),
  ),
  workspaceRepository: const JsonWorkspaceRepository(
    BrowserJsonObjectStore('team_maker.workspace_v1'),
  ),
  galleryExporter: const WebGalleryExportService(),
);
