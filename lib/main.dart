import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/team_maker_app.dart';
import 'core/storage/atomic_json_file.dart';
import 'data/json_member_repository.dart';
import 'data/json_team_history_repository.dart';
import 'services/gallery_export_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    TeamMakerApp(
      memberRepository: JsonMemberRepository(
        AtomicJsonFile(
          directoryProvider: getApplicationSupportDirectory,
          fileName: 'members_v1.json',
        ),
      ),
      historyRepository: JsonTeamHistoryRepository(
        AtomicJsonFile(
          directoryProvider: getApplicationSupportDirectory,
          fileName: 'team_history_v1.json',
        ),
      ),
      galleryExporter: const GalleryExportService(),
    ),
  );
}
