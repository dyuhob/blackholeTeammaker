import '../../domain/member.dart';
import '../sync/pending_mutation.dart';

abstract interface class MemberRemoteDataSource {
  Future<void> push(PendingMutation mutation);
  Future<List<Member>> fetchAll();
}
