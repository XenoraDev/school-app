import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/teacher_workspace/data/models/teacher_workspace_models.dart';
import 'package:school_app/features/teacher_workspace/domain/entities/teacher_workspace_entities.dart';
import 'package:school_app/features/teacher_workspace/domain/repositories/teacher_workspace_repository.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_bloc.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_event.dart';
import 'package:school_app/features/teacher_workspace/presentation/bloc/teacher_workspace_state.dart';
import 'package:school_app/features/teacher_workspace/presentation/screens/my_sections_screen.dart';
import 'package:school_app/features/teacher_workspace/presentation/screens/my_subjects_screen.dart';
import 'package:school_app/features/teacher_workspace/presentation/screens/teacher_workspace_shell.dart';

void main() {
  group('Teacher workspace response models', () {
    test(
      'maps section payload including class teacher and subject summaries',
      () {
        final model = TeacherSectionModel.fromJson({
          'id': 'section-ulid',
          'name': '8-A',
          'room': 'Room 101',
          'academic_year': {'id': 'year-ulid', 'name': '2026-2027'},
          'grade_level': {'id': 'grade-ulid', 'name': 'Class 8'},
          'is_class_teacher': true,
          'subjects': [
            {'id': 'subject-ulid', 'code': 'MATH08', 'name': 'Mathematics'},
          ],
        });
        final section = model.toEntity();

        expect(section.id, 'section-ulid');
        expect(section.academicYear.name, '2026-2027');
        expect(section.gradeLevel.name, 'Class 8');
        expect(section.isClassTeacher, isTrue);
        expect(section.subjects.single.code, 'MATH08');
      },
    );

    test('maps subject payload and nested assigned sections', () {
      final subject = TeacherSubjectModel.fromJson({
        'id': 'subject-ulid',
        'code': 'MATH08',
        'name': 'Mathematics',
        'sections': [
          {
            'id': 'section-ulid',
            'name': '8-A',
            'grade_level': {'id': 'grade-ulid', 'name': 'Class 8'},
          },
        ],
      }).toEntity();

      expect(subject.sections.single.id, 'section-ulid');
      expect(subject.sections.single.gradeLevel.name, 'Class 8');
    });
  });

  group('Teacher workspace authorization UX', () {
    test('requires a teacher or staff audience and a teacher ability', () {
      expect(_profile('teacher', []).canOpenTeacherWorkspace, isFalse);
      expect(
        _profile('parent', ['classes.view']).canOpenTeacherWorkspace,
        isFalse,
      );
      expect(
        _profile('staff', ['school.view']).canOpenTeacherWorkspace,
        isFalse,
      );
      expect(
        _profile('teacher', ['subjects.view']).canOpenTeacherWorkspace,
        isTrue,
      );
      expect(
        _profile('staff', ['classes.view']).canOpenTeacherWorkspace,
        isTrue,
      );
    });
  });

  group('TeacherWorkspaceBloc', () {
    late _FakeTeacherRepository repository;
    late TeacherWorkspaceBloc bloc;

    setUp(() {
      repository = _FakeTeacherRepository();
      bloc = TeacherWorkspaceBloc(repository: repository);
    });

    tearDown(() => bloc.close());

    test('loads sections and subjects independently', () async {
      repository.sections = [_section];
      repository.subjects = [_subject];
      final loaded = bloc.stream.firstWhere(
        (state) =>
            state.sectionsStatus == TeacherDataStatus.success &&
            state.subjectsStatus == TeacherDataStatus.success,
      );

      bloc
        ..add(const TeacherSectionsRequested())
        ..add(const TeacherSubjectsRequested());

      final state = await loaded;
      expect(state.sections, [_section]);
      expect(state.subjects, [_subject]);
    });

    test('emits retryable failure state with the repository message', () async {
      repository.sectionsFailure = const NetworkFailure(message: 'Offline');
      final failed = bloc.stream.firstWhere(
        (state) => state.sectionsStatus == TeacherDataStatus.failure,
      );
      bloc.add(const TeacherSectionsRequested());

      final state = await failed;
      expect(state.sectionsError, 'Offline');
      repository.sectionsFailure = null;
      repository.sections = [_section];
      final retried = bloc.stream.firstWhere(
        (state) => state.sectionsStatus == TeacherDataStatus.success,
      );
      bloc.add(const TeacherSectionsRequested());
      expect((await retried).sections, [_section]);
    });
  });

  group('Teacher workspace screens', () {
    late _SeededTeacherBloc bloc;

    setUp(() => bloc = _SeededTeacherBloc(_FakeTeacherRepository()));
    tearDown(() => bloc.close());

    testWidgets('shows empty state for an unassigned teacher', (tester) async {
      bloc.seedSections([]);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TeacherWorkspaceBloc>.value(
            value: bloc,
            child: const MySectionsScreen(),
          ),
        ),
      );
      expect(find.text('No assigned sections'), findsOneWidget);
    });

    testWidgets('renders class-teacher badge and subject chips', (
      tester,
    ) async {
      final loadedBloc = _SeededTeacherBloc(_FakeTeacherRepository());
      loadedBloc.seedSections([_section]);
      addTearDown(loadedBloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TeacherWorkspaceBloc>.value(
            value: loadedBloc,
            child: const MySectionsScreen(),
          ),
        ),
      );
      expect(find.text('Class teacher'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Class 8 · 2026-2027'), findsOneWidget);
      expect(find.textContaining('Â·'), findsNothing);
    });

    testWidgets('shows the empty subjects state', (tester) async {
      bloc.seedSubjects([]);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<TeacherWorkspaceBloc>.value(
            value: bloc,
            child: const MySubjectsScreen(),
          ),
        ),
      );
      expect(find.text('No assigned subjects'), findsOneWidget);
    });

    testWidgets('does not show an unavailable teacher destination', (
      tester,
    ) async {
      final shellBloc = _SeededTeacherBloc(_FakeTeacherRepository());
      addTearDown(shellBloc.close);
      final profile = _profile('staff', ['classes.view']);
      final router = _testTeacherRouter(profile);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => BlocProvider<TeacherWorkspaceBloc>.value(
            value: shellBloc,
            child: child!,
          ),
        ),
      );
      expect(find.text('Example School'), findsOneWidget);
      expect(find.text('Subjects'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('shows both destinations when both abilities are present', (
      tester,
    ) async {
      final shellBloc = _SeededTeacherBloc(_FakeTeacherRepository());
      addTearDown(shellBloc.close);
      final profile = _profile('teacher', ['classes.view', 'subjects.view']);
      final router = _testTeacherRouter(profile);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => BlocProvider<TeacherWorkspaceBloc>.value(
            value: shellBloc,
            child: child!,
          ),
        ),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Sections'), findsOneWidget);
      expect(find.text('Subjects'), findsOneWidget);
    });
  });
}

final _section = TeacherSection(
  id: 'section-ulid',
  name: '8-A',
  room: 'Room 101',
  academicYear: const TeacherYearSummary(id: 'year-ulid', name: '2026-2027'),
  gradeLevel: const TeacherGradeLevelSummary(id: 'grade-ulid', name: 'Class 8'),
  isClassTeacher: true,
  subjects: const [
    TeacherSectionSubject(
      id: 'subject-ulid',
      code: 'MATH08',
      name: 'Mathematics',
    ),
  ],
);

GoRouter _testTeacherRouter(AccountProfile profile) => GoRouter(
  initialLocation: profile.can('classes.view')
      ? '/teacher/sections'
      : '/teacher/subjects',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => TeacherWorkspaceShell(
        profile: profile,
        navigationShell: navigationShell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/teacher/sections',
              builder: (context, state) => const MySectionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/teacher/subjects',
              builder: (context, state) => const MySubjectsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

const _subject = TeacherSubject(
  id: 'subject-ulid',
  code: 'MATH08',
  name: 'Mathematics',
  sections: [
    TeacherSubjectSection(
      id: 'section-ulid',
      name: '8-A',
      gradeLevel: TeacherGradeLevelSummary(id: 'grade-ulid', name: 'Class 8'),
    ),
  ],
);

AccountProfile _profile(String userType, List<String> abilities) =>
    AccountProfile(
      id: 1,
      kind: 'school',
      name: 'Staff User',
      email: 'staff@example.test',
      userType: userType,
      school: const SchoolInfo(
        name: 'Example School',
        slug: 'example',
        status: 'active',
      ),
      abilities: abilities,
      emailVerified: true,
      mfaEnabled: false,
      mfaRequired: false,
    );

class _FakeTeacherRepository implements TeacherWorkspaceRepository {
  List<TeacherSection> sections = [];
  List<TeacherSubject> subjects = [];
  Failure? sectionsFailure;

  @override
  Future<List<TeacherSection>> getMySections() async {
    if (sectionsFailure case final failure?) throw failure;
    return sections;
  }

  @override
  Future<List<TeacherSubject>> getMySubjects() async => subjects;
}

class _SeededTeacherBloc extends TeacherWorkspaceBloc {
  _SeededTeacherBloc(TeacherWorkspaceRepository repository)
    : super(repository: repository);

  void seedSections(List<TeacherSection> sections) => emit(
    state.copyWith(
      sectionsStatus: TeacherDataStatus.success,
      sections: sections,
    ),
  );

  void seedSubjects(List<TeacherSubject> subjects) => emit(
    state.copyWith(
      subjectsStatus: TeacherDataStatus.success,
      subjects: subjects,
    ),
  );
}
