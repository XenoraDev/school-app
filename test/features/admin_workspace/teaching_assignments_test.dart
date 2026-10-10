import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';
import 'package:school_app/features/admin_workspace/domain/repositories/admin_repository.dart';
import 'package:school_app/features/admin_workspace/presentation/bloc/admin_workspace_cubit.dart';
import 'package:school_app/features/admin_workspace/presentation/screens/teaching_assignments_screen.dart';

void main() {
  group('endpoints', () {
    test('match the teaching-assignment routes in the API', () {
      expect(
        ApiEndpoints.teachingAssignments,
        '/school/teaching-assignments',
      );
      expect(
        ApiEndpoints.teachingAssignmentEnd('abc'),
        '/school/teaching-assignments/abc/end',
      );
      expect(
        ApiEndpoints.teachingAssignmentReactivate('abc'),
        '/school/teaching-assignments/abc/reactivate',
      );
    });
  });

  group('AdminWorkspaceCubit.fetchAll', () {
    test('reads every page, 100 at a time, without touching state', () async {
      final repository = _Repository()..pageSize = 2;
      final cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      final emitted = <AdminWorkspaceState>[];
      final subscription = cubit.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      final staff = await cubit.fetchAll(ApiEndpoints.staff);

      expect(staff.map((s) => s.id), ['t1', 't2', 't3']);
      final calls = repository.pageCalls
          .where((c) => c.$1 == ApiEndpoints.staff)
          .toList();
      expect(calls, hasLength(2));
      expect(calls.first.$2, {'per_page': 100});
      expect(calls.last.$2, {'per_page': 100, 'cursor': '2'});
      await pumpEventQueue();
      expect(emitted, isEmpty);
    });

    test('stops at the page cap instead of looping forever', () async {
      final repository = _Repository()..pageSize = 1;
      final cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);

      final staff = await cubit.fetchAll(ApiEndpoints.staff, maxPages: 2);

      expect(staff, hasLength(2));
    });
  });

  group('AdminWorkspaceCubit list races', () {
    late _GatedRepository repository;
    late AdminWorkspaceCubit cubit;

    setUp(() {
      repository = _GatedRepository();
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
    });

    List<String> ids() => cubit.state.records.map((r) => r.id).toList();

    Future<void> firstPage() async {
      final first = cubit.load('/rows');
      repository.complete(0, ['a1'], nextCursor: 'c1');
      await first;
    }

    test('a late loadMore cannot append rows after a newer load', () async {
      await firstPage();
      unawaited(cubit.loadMore('/rows'));
      await pumpEventQueue();
      unawaited(cubit.load('/rows', query: {'filter[status]': 'ended'}));
      await pumpEventQueue();

      repository.complete(1, ['stale-page-2']); // the loadMore, now outdated
      await pumpEventQueue();
      expect(cubit.state.loading, isTrue, reason: 'the new load still runs');
      expect(ids(), isEmpty);

      repository.complete(2, ['e1']);
      await pumpEventQueue();
      expect(ids(), ['e1']);
      expect(cubit.state.loading, isFalse);
    });

    test('a late loadMore error cannot replace the new list with an error', () async {
      await firstPage();
      unawaited(cubit.loadMore('/rows'));
      await pumpEventQueue();
      unawaited(cubit.load('/rows', query: {'filter[status]': 'ended'}));
      await pumpEventQueue();

      repository.fail(1);
      await pumpEventQueue();
      expect(cubit.state.error, isNull);
      expect(cubit.state.loading, isTrue);

      repository.complete(2, ['e1']);
      await pumpEventQueue();
      expect(ids(), ['e1']);
    });

    test('an older load finishing last does not overwrite the newer one', () async {
      unawaited(cubit.load('/rows', query: {'filter[status]': 'active'}));
      await pumpEventQueue();
      unawaited(cubit.load('/rows', query: {'filter[status]': 'ended'}));
      await pumpEventQueue();

      repository.complete(1, ['ended-row']);
      await pumpEventQueue();
      repository.complete(0, ['active-row']); // arrives last, but is older
      await pumpEventQueue();

      expect(ids(), ['ended-row']);
      expect(cubit.state.loading, isFalse);
    });

    test('loadMore still appends when nothing newer started', () async {
      await firstPage();
      final more = cubit.loadMore('/rows');
      repository.complete(1, ['a2']);
      await more;

      expect(ids(), ['a1', 'a2']);
    });

    test('the session guard still wins over the list guard', () async {
      unawaited(cubit.load('/rows'));
      await pumpEventQueue();
      cubit.reset();

      repository.complete(0, ['old-account']);
      await pumpEventQueue();

      expect(ids(), isEmpty);
      expect(cubit.state.loading, isFalse);
    });
  });

  group('TeachingAssignmentsScreen', () {
    late _Repository repository;
    late AdminWorkspaceCubit cubit;

    Future<void> pumpScreen(
      WidgetTester tester, {
      bool canManage = true,
    }) async {
      repository = _Repository();
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: canManage));
      await tester.pumpAndSettle();
    }

    testWidgets('lists assignments with names, year and status', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Mathematics · 8-A (Class 8)'), findsOneWidget);
      expect(find.textContaining('Asha Verma'), findsWidgets);
      expect(find.textContaining('2026-2027 · Active'), findsNWidgets(2));
      expect(find.textContaining('2026-2027 · Ended'), findsOneWidget);
      expect(find.text('Unknown subject · Unknown section'), findsOneWidget);
      expect(find.textContaining('Unknown staff member'), findsOneWidget);
    });

    testWidgets('status chips filter through the API', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ended'));
      await tester.pumpAndSettle();

      expect(
        repository.pageCalls.last.$2,
        containsPair('filter[status]', 'ended'),
      );
      expect(find.textContaining('· Active'), findsNothing);
      expect(find.textContaining('· Ended'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.textContaining('· Active'), findsNWidgets(2));
    });

    testWidgets('shows an empty state, plain and filtered', (tester) async {
      repository = _Repository()..assignments.clear();
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: true));
      await tester.pumpAndSettle();
      expect(find.text('No teaching assignments yet.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
      await tester.pumpAndSettle();
      expect(find.text('No active teaching assignments.'), findsOneWidget);
    });

    testWidgets('shows a load error with a working retry', (tester) async {
      repository = _Repository()..failAssignments = true;
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: true));
      await tester.pumpAndSettle();
      expect(find.text('Teaching assignments could not be loaded'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);

      repository.failAssignments = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Mathematics · 8-A (Class 8)'), findsOneWidget);
    });

    testWidgets('read-only users see no way to change assignments', (
      tester,
    ) async {
      await pumpScreen(tester, canManage: false);

      expect(find.text('Mathematics · 8-A (Class 8)'), findsOneWidget);
      expect(find.text('Assign teacher'), findsNothing);
      expect(find.text('End'), findsNothing);
      expect(find.text('Reactivate'), findsNothing);
    });

    testWidgets('managers see the assign, end and reactivate controls', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Assign teacher'), findsOneWidget);
      expect(find.text('End'), findsWidgets);
      expect(find.text('Reactivate'), findsWidgets);
    });

    testWidgets('the picker offers only active sections, subjects and teachers', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Assign teacher'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Section'));
      await tester.pumpAndSettle();
      expect(find.text('8-A (Class 8) · 2026-2027').hitTestable(), findsWidgets);
      expect(find.text('8-B (Class 8) · 2026-2027').hitTestable(), findsWidgets);
      expect(
        find.textContaining('8-C'),
        findsNothing,
        reason: 'closed section',
      );
      await tester.tap(find.text('8-B (Class 8) · 2026-2027').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Subject'));
      await tester.pumpAndSettle();
      expect(find.text('Science').hitTestable(), findsWidgets);
      expect(find.text('Old subject'), findsNothing, reason: 'archived subject');
      await tester.tap(find.text('Science').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Teacher'));
      await tester.pumpAndSettle();
      expect(find.text('Asha Verma').hitTestable(), findsWidgets);
      expect(find.text('Bimal Roy'), findsNothing, reason: 'not marked teaching');
      expect(find.text('Chitra Rao'), findsNothing, reason: 'resigned');
    });

    testWidgets('requires all three choices before sending', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Assign teacher'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsNWidgets(3));
      expect(repository.sent, isEmpty);
    });

    Future<void> chooseAndAssign(WidgetTester tester) async {
      await tester.tap(find.text('Assign teacher'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Section'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8-B (Class 8) · 2026-2027').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Subject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Science').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Teacher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha Verma').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();
    }

    testWidgets('assigning posts the three ids and refreshes the list', (
      tester,
    ) async {
      await pumpScreen(tester);

      await chooseAndAssign(tester);

      expect(repository.sent, hasLength(1));
      expect(repository.sent.single.$1, 'POST');
      expect(repository.sent.single.$2, '/school/teaching-assignments');
      expect(repository.sent.single.$3, {
        'section': 's2',
        'subject': 'sub2',
        'staff': 't1',
      });
      expect(find.text('Teacher assigned.'), findsOneWidget);
      expect(find.text('Science · 8-B (Class 8)'), findsOneWidget);
    });

    testWidgets('a server rejection is shown and the list still reloads', (
      tester,
    ) async {
      await pumpScreen(tester);
      repository.sendError = const ConflictFailure(
        message: 'The academic year is closed.',
        isInvalidState: true,
      );
      final loadsBefore = repository.pageCalls
          .where((c) => c.$1 == ApiEndpoints.teachingAssignments)
          .length;

      await chooseAndAssign(tester);

      expect(find.text('The academic year is closed.'), findsOneWidget);
      expect(find.text('Teacher assigned.'), findsNothing);
      expect(
        repository.pageCalls
            .where((c) => c.$1 == ApiEndpoints.teachingAssignments)
            .length,
        loadsBefore + 1,
      );
      expect(find.text('Mathematics · 8-A (Class 8)'), findsOneWidget);
    });

    testWidgets('ending asks first and cancelling changes nothing', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('End').first);
      await tester.pumpAndSettle();
      expect(find.text('End this assignment?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.sent, isEmpty);
    });

    testWidgets('confirming ends the assignment through the API', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('End').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('End assignment'));
      await tester.pumpAndSettle();

      expect(repository.sent, hasLength(1));
      expect(repository.sent.single.$1, 'POST');
      expect(repository.sent.single.$2, '/school/teaching-assignments/a1/end');
      expect(repository.sent.single.$3, isNull);
      expect(find.text('Assignment ended.'), findsOneWidget);
      expect(find.textContaining('· Ended'), findsNWidgets(2));
    });

    testWidgets('reactivating posts to the reactivate route', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Reactivate').first);
      await tester.pumpAndSettle();

      expect(repository.sent, hasLength(1));
      expect(repository.sent.single.$1, 'POST');
      expect(
        repository.sent.single.$2,
        '/school/teaching-assignments/a2/reactivate',
      );
      expect(find.text('Assignment reactivated.'), findsOneWidget);
    });

    testWidgets('controls are disabled while a change is being saved', (
      tester,
    ) async {
      await pumpScreen(tester);
      final gate = Completer<void>();
      repository.sendGate = gate.future;

      await tester.tap(find.text('Reactivate').first);
      await tester.pump();
      await tester.pump();

      final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
      expect(buttons.where((b) => b.onPressed != null), isEmpty);
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      expect(repository.sent, hasLength(1));
    });

    testWidgets('long lists load more on request', (tester) async {
      repository = _Repository()..assignmentPageSize = 1;
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: true));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('sections with the same name in two years are told apart', (
      tester,
    ) async {
      repository = _Repository();
      repository.lookups[ApiEndpoints.academicYears]!.add(
        _r({'id': 'y2', 'name': '2027-2028'}),
      );
      repository.lookups[ApiEndpoints.sections]!.add(
        _r({
          'id': 's4',
          'name': '8-A',
          'grade_level': 'g1',
          'academic_year': 'y2',
          'status': 'active',
        }),
      );
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Assign teacher'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Section'));
      await tester.pumpAndSettle();

      expect(find.text('8-A (Class 8) · 2026-2027').hitTestable(), findsOneWidget);
      expect(find.text('8-A (Class 8) · 2027-2028').hitTestable(), findsOneWidget);
      await tester.tap(find.text('8-A (Class 8) · 2027-2028').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Subject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Science').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Teacher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha Verma').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(repository.sent.single.$3, containsPair('section', 's4'));
    });

    testWidgets('one forbidden lookup keeps the other names and blocks assigning', (
      tester,
    ) async {
      repository = _Repository()..forbidden.add(ApiEndpoints.staff);
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: true));
      await tester.pumpAndSettle();

      // Names from the lookups that worked are still resolved...
      expect(find.text('Mathematics · 8-A (Class 8)'), findsOneWidget);
      expect(find.textContaining('2026-2027 · Active'), findsNWidgets(2));
      // ...the forbidden one is called out, not shown as a missing record.
      expect(find.textContaining('Not available'), findsWidgets);
      expect(find.textContaining('Unknown staff member'), findsNothing);
      expect(find.textContaining('staff (no access)'), findsOneWidget);
      // Nothing the user cannot identify or complete is offered.
      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(fab.onPressed, isNull);
      expect(find.text('End'), findsNothing);
      expect(find.text('Reactivate'), findsNothing);
      expect(repository.sent, isEmpty);
    });

    testWidgets('a forbidden grade-level list only blocks assigning', (
      tester,
    ) async {
      repository = _Repository()..forbidden.add(ApiEndpoints.gradeLevels);
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: true));
      await tester.pumpAndSettle();

      expect(find.text('Mathematics · 8-A'), findsOneWidget, reason: 'no grade name');
      expect(find.textContaining('grade levels (no access)'), findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(fab.onPressed, isNull, reason: 'picker labels would be ambiguous');
      final end = tester.widget<TextButton>(find.widgetWithText(TextButton, 'End').first);
      expect(end.onPressed, isNotNull, reason: 'rows are still identifiable');
    });

    testWidgets('a failed lookup can be retried and then enables everything', (
      tester,
    ) async {
      repository = _Repository()..failStaff = true;
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('staff (could not be loaded)'), findsOneWidget);
      expect(
        tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed,
        isNull,
      );

      repository.failStaff = false;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unavailable'), findsNothing);
      expect(find.text('Mathematics · 8-A (Class 8)'), findsOneWidget);
      expect(
        tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('a late page for the old filter is not added after switching filter', (
      tester,
    ) async {
      repository = _Repository()..assignmentPageSize = 1;
      cubit = AdminWorkspaceCubit(repository);
      addTearDown(cubit.close);
      await tester.pumpWidget(_host(cubit, canManage: true));
      await tester.pumpAndSettle();
      // The unfiltered second page (an ended assignment) is held in flight.
      repository.holdCursorPage = Completer<void>();
      await tester.tap(find.text('Load more'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
      await tester.pumpAndSettle();
      expect(find.textContaining('· Ended'), findsNothing);

      repository.holdCursorPage!.complete();
      await tester.pumpAndSettle();

      expect(find.textContaining('· Ended'), findsNothing, reason: 'stale page dropped');
      expect(find.textContaining('· Active'), findsOneWidget);
    });
  });
}

Widget _host(AdminWorkspaceCubit cubit, {required bool canManage}) =>
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: TeachingAssignmentsScreen(canManage: canManage),
      ),
    );

AdminRecord _r(Map<String, dynamic> json) => AdminRecord.fromJson(json);

class _Repository implements AdminRepository {
  int pageSize = 100;
  int assignmentPageSize = 100;
  bool failAssignments = false;
  bool failStaff = false;
  final Set<String> forbidden = {};
  Completer<void>? holdCursorPage;
  Object? sendError;
  Future<void>? sendGate;
  final List<(String, Map<String, dynamic>?)> pageCalls = [];
  final List<(String, String, JsonMap?)> sent = [];

  final List<AdminRecord> assignments = [
    _r({
      'id': 'a1',
      'academic_year': 'y1',
      'section': 's1',
      'subject': 'sub1',
      'staff': 't1',
      'status': 'active',
    }),
    _r({
      'id': 'a2',
      'academic_year': 'y1',
      'section': 's1',
      'subject': 'sub2',
      'staff': 't1',
      'status': 'ended',
    }),
    _r({
      'id': 'a3',
      'academic_year': 'y1',
      'section': 'gone-section',
      'subject': 'gone-subject',
      'staff': 'gone-staff',
      'status': 'active',
    }),
  ];

  late final Map<String, List<AdminRecord>> lookups = {
    ApiEndpoints.academicYears: [_r({'id': 'y1', 'name': '2026-2027'})],
    ApiEndpoints.gradeLevels: [_r({'id': 'g1', 'name': 'Class 8'})],
    ApiEndpoints.sections: [
      _r({'id': 's1', 'name': '8-A', 'grade_level': 'g1', 'academic_year': 'y1', 'status': 'active'}),
      _r({'id': 's2', 'name': '8-B', 'grade_level': 'g1', 'academic_year': 'y1', 'status': 'active'}),
      _r({'id': 's3', 'name': '8-C', 'grade_level': 'g1', 'academic_year': 'y1', 'status': 'closed'}),
    ],
    ApiEndpoints.subjects: [
      _r({'id': 'sub1', 'name': 'Mathematics', 'status': 'active'}),
      _r({'id': 'sub2', 'name': 'Science', 'status': 'active'}),
      _r({'id': 'sub3', 'name': 'Old subject', 'status': 'archived'}),
    ],
    ApiEndpoints.staff: [
      _r({
        'id': 't1',
        'full_name': 'Asha Verma',
        'status': 'active',
        'is_teaching': true,
      }),
      _r({
        'id': 't2',
        'full_name': 'Bimal Roy',
        'status': 'active',
        'is_teaching': false,
      }),
      _r({
        'id': 't3',
        'full_name': 'Chitra Rao',
        'status': 'resigned',
        'is_teaching': true,
      }),
    ],
  };

  @override
  Future<AdminPage> listPage(String path, {Map<String, dynamic>? query}) async {
    pageCalls.add((path, query));
    if (path == ApiEndpoints.teachingAssignments && failAssignments) {
      throw const NetworkFailure(message: 'Offline');
    }
    if (path == ApiEndpoints.staff && failStaff) {
      throw const NetworkFailure(message: 'Offline');
    }
    if (forbidden.contains(path)) {
      throw const ForbiddenFailure(message: 'This action is unauthorized.');
    }
    if (path == ApiEndpoints.teachingAssignments &&
        query?['cursor'] != null &&
        holdCursorPage != null) {
      await holdCursorPage!.future;
    }
    var rows = path == ApiEndpoints.teachingAssignments
        ? assignments.toList()
        : (lookups[path] ?? const []);
    final status = query?['filter[status]'];
    if (path == ApiEndpoints.teachingAssignments && status != null) {
      rows = rows.where((r) => r.values['status'] == status).toList();
    }
    final size = path == ApiEndpoints.teachingAssignments
        ? assignmentPageSize
        : pageSize;
    final start = int.tryParse('${query?['cursor'] ?? 0}') ?? 0;
    final end = (start + size).clamp(0, rows.length);
    return AdminPage(
      records: rows.sublist(start.clamp(0, rows.length), end),
      nextCursor: end < rows.length ? '$end' : null,
      hasMore: end < rows.length,
    );
  }

  @override
  Future<AdminRecord> send(String method, String path, {JsonMap? body}) async {
    sent.add((method, path, body));
    await sendGate;
    if (sendError != null) throw sendError!;
    if (path == ApiEndpoints.teachingAssignments) {
      final created = _r({
        'id': 'new',
        'academic_year': 'y1',
        ...?body,
        'status': 'active',
      });
      assignments.add(created);
      return created;
    }
    final id = path.split('/')[3];
    final index = assignments.indexWhere((r) => r.id == id);
    final status = path.endsWith('/end') ? 'ended' : 'active';
    assignments[index] = _r({...assignments[index].values, 'status': status});
    return assignments[index];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A repository whose list calls are answered by the test, in any order.
class _GatedRepository implements AdminRepository {
  final List<Completer<AdminPage>> _calls = [];

  void complete(int call, List<String> ids, {String? nextCursor}) =>
      _calls[call].complete(
        AdminPage(
          records: [for (final id in ids) _r({'id': id})],
          nextCursor: nextCursor,
          hasMore: nextCursor != null,
        ),
      );

  void fail(int call) =>
      _calls[call].completeError(const NetworkFailure(message: 'Offline'));

  @override
  Future<AdminPage> listPage(String path, {Map<String, dynamic>? query}) {
    final completer = Completer<AdminPage>();
    _calls.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
