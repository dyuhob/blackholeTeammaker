import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/json_member_repository.dart';
import '../data/json_team_history_repository.dart';
import '../data/supabase/supabase_history_remote_data_source.dart';
import '../data/supabase/supabase_member_remote_data_source.dart';
import '../data/sync/history_sync.dart';
import '../data/sync/history_sync_coordinator.dart';
import '../data/sync/member_sync.dart';
import '../data/sync/member_sync_coordinator.dart';

class SyncServices {
  const SyncServices({this.member, this.history});

  final MemberSync? member;
  final HistorySync? history;
}

SyncServices createSyncServices({
  required JsonMemberRepository memberRepository,
  required JsonTeamHistoryRepository historyRepository,
  String url = const String.fromEnvironment('SUPABASE_URL'),
  String publishableKey = const String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  ),
}) {
  final uri = Uri.tryParse(url);
  if (url.isEmpty ||
      publishableKey.isEmpty ||
      uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return const SyncServices();
  }
  try {
    final client = SupabaseClient(url, publishableKey);
    return SyncServices(
      member: MemberSyncCoordinator(
        local: memberRepository,
        remote: SupabaseMemberRemoteDataSource(client),
      ),
      history: HistorySyncCoordinator(
        local: historyRepository,
        remote: SupabaseHistoryRemoteDataSource(client),
      ),
    );
  } on Object {
    return const SyncServices();
  }
}
