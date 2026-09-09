import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/bootstrap/supabase_sync_factory.dart';
import 'package:team_maker/core/storage/json_object_store.dart';
import 'package:team_maker/data/json_member_repository.dart';
import 'package:team_maker/data/json_team_history_repository.dart';

void main() {
  test('missing build configuration keeps the app local only', () {
    final services = createSyncServices(
      memberRepository: JsonMemberRepository(MemoryStore()),
      historyRepository: JsonTeamHistoryRepository(MemoryStore()),
      url: '',
      publishableKey: '',
    );

    expect(services.member, isNull);
    expect(services.history, isNull);
  });
}

class MemoryStore implements JsonObjectStore {
  @override
  Future<Map<String, Object?>?> read() async => null;

  @override
  Future<void> write(Map<String, Object?> value) async {}
}
