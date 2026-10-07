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
