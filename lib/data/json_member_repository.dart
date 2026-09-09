import '../core/storage/json_object_store.dart';
import '../domain/member.dart';
import 'member_repository.dart';
import 'sync/member_sync_document.dart';
import 'sync/pending_mutation.dart';

class JsonMemberRepository implements MemberRepository {
  const JsonMemberRepository(this._store);

  final JsonObjectStore _store;

  @override
  Future<List<Member>> loadAll() async => (await readSyncDocument()).members;

  Future<MemberSyncDocument> readSyncDocument() async {
    final json = await _store.read();
    if (json == null) return const MemberSyncDocument();
    final version = json['schemaVersion'];
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported members schema version.');
    }
    final members = (json['members']! as List<Object?>)
        .map((value) => Member.fromJson(value! as Map<String, Object?>))
        .toList();
    return MemberSyncDocument(
      members: members,
      pendingMutations: version == 1
          ? const []
          : (json['pendingMutations']! as List<Object?>)
                .map(
                  (value) =>
                      PendingMutation.fromJson(value! as Map<String, Object?>),
                )
                .toList(),
    );
  }

  @override
  Future<void> saveAll(List<Member> members) async {
    final current = await readSyncDocument();
    final nextById = {for (final value in members) value.id: value};
    var pending = [...current.pendingMutations];

    for (final member in members) {
      pending = compactMutation(
        pending,
        PendingMutation(
          id: createMutationId(
            SyncMutationKind.upsert,
            member.id,
            Object.hash(member.name, member.score),
          ),
          entityId: member.id,
          kind: SyncMutationKind.upsert,
          payload: member.toJson(),
        ),
      );
    }
    for (final member in current.members) {
      if (nextById.containsKey(member.id)) continue;
      pending = compactMutation(
        pending,
        PendingMutation(
          id: createMutationId(SyncMutationKind.delete, member.id, member.id),
          entityId: member.id,
          kind: SyncMutationKind.delete,
          payload: {'id': member.id},
        ),
      );
    }
    await writeSyncDocument(
      MemberSyncDocument(members: [...members], pendingMutations: pending),
    );
  }

  Future<void> writeSyncDocument(MemberSyncDocument document) =>
      _store.write(document.toJson());

  Future<void> acknowledgeMutation(String mutationId) async {
    final document = await readSyncDocument();
    await writeSyncDocument(
      document.copyWith(
        pendingMutations: document.pendingMutations
            .where((value) => value.id != mutationId)
            .toList(),
      ),
    );
  }

  Future<void> replaceMembersFromRemote(List<Member> members) async {
    await writeSyncDocument(MemberSyncDocument(members: [...members]));
  }
}
