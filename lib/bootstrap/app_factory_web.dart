import 'package:flutter/widgets.dart';

import '../app/team_maker_app.dart';
import '../core/storage/browser_json_object_store.dart';
import '../data/json_member_repository.dart';
import '../data/json_team_history_repository.dart';
import '../data/json_workspace_repository.dart';
import '../services/web_gallery_export_service.dart';
import '../services/pwa_install_service.dart';
import 'supabase_sync_factory.dart';

Widget createApp() {
  const memberRepository = JsonMemberRepository(
    BrowserJsonObjectStore('team_maker.members_v1'),
  );
  const historyRepository = JsonTeamHistoryRepository(
    BrowserJsonObjectStore('team_maker.team_history_v1'),
  );
  final sync = createSyncServices(
    memberRepository: memberRepository,
    historyRepository: historyRepository,
  );
  return TeamMakerApp(
    memberRepository: memberRepository,
    historyRepository: historyRepository,
    workspaceRepository: const JsonWorkspaceRepository(
      BrowserJsonObjectStore('team_maker.workspace_v1'),
    ),
    galleryExporter: const WebGalleryExportService(),
    memberSync: sync.member,
    historySync: sync.history,
    pwaInstallService: createPwaInstallService(),
  );
}
