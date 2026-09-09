import '../../domain/member.dart';
import 'sync_outcome.dart';

abstract interface class MemberSync {
  Future<SyncOutcome<List<Member>>> synchronize(List<Member> visible);
  Future<void> acceptRemote(List<Member> snapshot);
}
