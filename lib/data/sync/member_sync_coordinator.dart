import '../../domain/member.dart';
import '../json_member_repository.dart';
import '../supabase/member_remote_data_source.dart';
import 'member_sync.dart';
import 'sync_outcome.dart';

class MemberSyncCoordinator implements MemberSync {
  MemberSyncCoordinator({required this.local, required this.remote});

  final JsonMemberRepository local;
  final MemberRemoteDataSource remote;
  Future<SyncOutcome<List<Member>>>? _inFlight;

  @override
  Future<SyncOutcome<List<Member>>> synchronize(List<Member> visible) {
    final previous = _inFlight;
    final snapshot = [...visible];
    final future = previous == null
        ? _run(snapshot)
        : previous.then((_) => _run(snapshot));
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<SyncOutcome<List<Member>>> _run(List<Member> visible) async {
    try {
      final document = await local.readSyncDocument();
      for (final mutation in document.pendingMutations) {
        await remote.push(mutation);
        await local.acknowledgeMutation(mutation.id);
      }
      final snapshot = await remote.fetchAll();
      if (_membersEqualIgnoringOrder(visible, snapshot)) {
        return const SyncOutcome.unchanged();
      }
      return SyncOutcome.remoteChanged(snapshot);
    } on Object catch (error) {
      return SyncOutcome.offline(error);
    }
  }

  @override
  Future<void> acceptRemote(List<Member> snapshot) =>
      local.replaceMembersFromRemote(snapshot);
}

bool _membersEqualIgnoringOrder(List<Member> left, List<Member> right) {
  if (left.length != right.length) return false;
  final leftById = {for (final value in left) value.id: value};
  final rightById = {for (final value in right) value.id: value};
  if (leftById.length != rightById.length) return false;
  for (final entry in leftById.entries) {
    if (rightById[entry.key] != entry.value) return false;
  }
  return true;
}
