import 'member.dart';
import 'participant.dart';

class WorkspaceState {
  const WorkspaceState({
    required this.selectedTabIndex,
    required this.draftMembers,
    required this.pendingMemberName,
    required this.pendingMemberScore,
    required this.participants,
    required this.teamSizeInput,
    required this.title,
  });

  final int selectedTabIndex;
  final List<Member> draftMembers;
  final String pendingMemberName;
  final String pendingMemberScore;
  final List<Participant> participants;
  final String teamSizeInput;
  final String title;

  Map<String, Object> toJson() => {
    'selectedTabIndex': selectedTabIndex,
    'draftMembers': draftMembers.map((member) => member.toJson()).toList(),
    'pendingMemberName': pendingMemberName,
    'pendingMemberScore': pendingMemberScore,
    'participants': participants
        .map((participant) => participant.toJson())
        .toList(),
    'teamSizeInput': teamSizeInput,
    'title': title,
  };

  factory WorkspaceState.fromJson(Map<String, Object?> json) => WorkspaceState(
    selectedTabIndex: json['selectedTabIndex']! as int,
    draftMembers: (json['draftMembers']! as List<Object?>)
        .map((value) => Member.fromJson(value! as Map<String, Object?>))
        .toList(),
    pendingMemberName: json['pendingMemberName']! as String,
    pendingMemberScore: json['pendingMemberScore']! as String,
    participants: (json['participants']! as List<Object?>)
        .map((value) => Participant.fromJson(value! as Map<String, Object?>))
        .toList(),
    teamSizeInput: json['teamSizeInput']! as String,
    title: json['title']! as String,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspaceState &&
          other.selectedTabIndex == selectedTabIndex &&
          _listEquals(other.draftMembers, draftMembers) &&
          other.pendingMemberName == pendingMemberName &&
          other.pendingMemberScore == pendingMemberScore &&
          _listEquals(other.participants, participants) &&
          other.teamSizeInput == teamSizeInput &&
          other.title == title;

  @override
  int get hashCode => Object.hash(
    selectedTabIndex,
    Object.hashAll(draftMembers),
    pendingMemberName,
    pendingMemberScore,
    Object.hashAll(participants),
    teamSizeInput,
    title,
  );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
