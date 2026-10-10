import 'package:equatable/equatable.dart';

sealed class TeacherWorkspaceEvent extends Equatable {
  const TeacherWorkspaceEvent();

  @override
  List<Object?> get props => [];
}

class TeacherSectionsRequested extends TeacherWorkspaceEvent {
  const TeacherSectionsRequested();
}

class TeacherSubjectsRequested extends TeacherWorkspaceEvent {
  const TeacherSubjectsRequested();
}

/// Drops every loaded section and subject and invalidates requests still in
/// flight. Sent when the session ends or the signed-in account changes.
class TeacherWorkspaceReset extends TeacherWorkspaceEvent {
  const TeacherWorkspaceReset();
}
