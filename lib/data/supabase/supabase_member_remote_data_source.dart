import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/member.dart';
import '../sync/pending_mutation.dart';
import 'member_remote_data_source.dart';
import 'member_row_codec.dart';

class SupabaseMemberRemoteDataSource implements MemberRemoteDataSource {
  const SupabaseMemberRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<void> push(PendingMutation mutation) async {
    switch (mutation.kind) {
      case SyncMutationKind.upsert:
        final member = Member.fromJson(mutation.payload);
        await _client
            .from('user')
            .upsert(memberToRemoteRow(member), onConflict: 'id');
      case SyncMutationKind.delete:
        await _client.rpc(
          'delete_member',
          params: {'p_member_id': mutation.entityId},
        );
    }
  }

  @override
  Future<List<Member>> fetchAll() async {
    final response = await _client
        .from('user')
        .select('id,name,average,deleted_at')
        .isFilter('deleted_at', null);
    return response
        .map((row) => memberFromRemoteRow(Map<String, Object?>.from(row)))
        .toList();
  }
}
