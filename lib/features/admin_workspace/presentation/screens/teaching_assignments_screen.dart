import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/core/errors/failures.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';
import 'package:school_app/features/admin_workspace/presentation/bloc/admin_workspace_cubit.dart';
import 'package:school_app/shared/feedback/error_state_view.dart';

/// Teacher x section x subject assignments (`/school/teaching-assignments`).
///
/// Reading needs `classes.view`; assigning, ending and reactivating need
/// `teaching_assignments.manage` ([canManage]). The API enforces both and all
/// the business rules (open year, active section, curriculum, active teaching
/// staff); this screen only offers sensible choices and shows the server's
/// answer.
class TeachingAssignmentsScreen extends StatefulWidget {
  const TeachingAssignmentsScreen({required this.canManage, super.key});

  final bool canManage;

  @override
  State<TeachingAssignmentsScreen> createState() =>
      _TeachingAssignmentsScreenState();
}

class _TeachingAssignmentsScreenState extends State<TeachingAssignmentsScreen> {
  String? _status;
  _Lookups? _lookups;

  AdminWorkspaceCubit get _cubit => context.read<AdminWorkspaceCubit>();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
    unawaited(_loadLookups());
  }

  Map<String, dynamic>? get _query =>
      _status == null ? null : {'filter[status]': _status};

  Future<void> _reload() =>
      _cubit.load(ApiEndpoints.teachingAssignments, query: _query);

  /// Loads the five name lookups independently, so one that fails (for
  /// example a 403 for a missing `staff.view`) leaves the others usable.
  Future<void> _loadLookups() async {
    final cubit = _cubit;
    final records = <_Lookup, List<AdminRecord>>{};
    final failures = <_Lookup, bool>{}; // value: true when forbidden
    await Future.wait([
      for (final kind in _Lookup.values)
        () async {
          try {
            records[kind] = await cubit.fetchAll(kind.path);
          } catch (error) {
            failures[kind] = error is ForbiddenFailure;
          }
        }(),
    ]);
    if (!mounted) return;
    setState(() => _lookups = _Lookups(records: records, failures: failures));
  }

  void _setStatus(String? status) {
    if (status == _status) return;
    setState(() => _status = status);
    unawaited(_reload());
  }

  Future<void> _assign() async {
    final lookups = _lookups;
    if (lookups == null || !lookups.canAssign) return;
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AssignDialog(lookups: lookups),
    );
    if (body == null || !mounted) return;
    await _run(
      () => _cubit.send('POST', ApiEndpoints.teachingAssignments, body: body),
      success: 'Teacher assigned.',
    );
  }

  Future<void> _end(AdminRecord record, _Lookups lookups) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('End this assignment?'),
        content: Text(
          '${lookups.staffName(record.values['staff'])} will stop teaching '
          '${lookups.subjectName(record.values['subject'])} in '
          '${lookups.sectionLabel(record.values['section'], withYear: true)}. '
          'You can reactivate it later while the year is open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('End assignment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _cubit.send('POST', ApiEndpoints.teachingAssignmentEnd(record.id)),
      success: 'Assignment ended.',
    );
  }

  Future<void> _reactivate(AdminRecord record) => _run(
    () => _cubit.send(
      'POST',
      ApiEndpoints.teachingAssignmentReactivate(record.id),
    ),
    success: 'Assignment reactivated.',
  );

  /// Runs a mutation, shows the server's message on failure, and reloads the
  /// list with the current filter either way.
  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    final cubit = _cubit;
    final messenger = ScaffoldMessenger.of(context);
    await action();
    final error = cubit.state.error;
    if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text(error ?? success)));
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AdminWorkspaceCubit, AdminWorkspaceState>(
        builder: (context, state) {
          final lookups = _lookups;
          return Scaffold(
            floatingActionButton: widget.canManage
                ? FloatingActionButton.extended(
                    onPressed: lookups == null ||
                            !lookups.canAssign ||
                            state.saving
                        ? null
                        : _assign,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Assign teacher'),
                  )
                : null,
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final option in const [
                        (null, 'All'),
                        ('active', 'Active'),
                        ('ended', 'Ended'),
                      ])
                        ChoiceChip(
                          label: Text(option.$2),
                          selected: _status == option.$1,
                          onSelected: (_) => _setStatus(option.$1),
                        ),
                    ],
                  ),
                ),
                if (lookups?.problem case final problem?)
                  MaterialBanner(
                    content: Text(problem),
                    actions: [
                      TextButton(
                        onPressed: _loadLookups,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(child: _body(state, lookups)),
              ],
            ),
          );
        },
      );

  Widget _body(AdminWorkspaceState state, _Lookups? lookups) {
    if (state.loading && state.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.records.isEmpty) {
      return ErrorStateView(
        title: 'Teaching assignments could not be loaded',
        message: state.error!,
        onRetry: _reload,
      );
    }
    if (state.records.isEmpty) {
      return Center(
        child: Text(
          _status == null
              ? 'No teaching assignments yet.'
              : 'No ${_status!} teaching assignments.',
        ),
      );
    }
    final labels = lookups ?? const _Lookups.empty();
    return RefreshIndicator(
      onRefresh: () async {
        await _reload();
        await _loadLookups();
      },
      child: ListView(
        children: [
          for (final record in state.records)
            _AssignmentCard(
              record: record,
              lookups: labels,
              canManage:
                  widget.canManage && (lookups?.canIdentifyRows ?? false),
              busy: state.saving,
              onEnd: () => _end(record, labels),
              onReactivate: () => _reactivate(record),
            ),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: state.loading
                    ? null
                    : () => _cubit.loadMore(ApiEndpoints.teachingAssignments),
                child: Text(state.loading ? 'Loading…' : 'Load more'),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.record,
    required this.lookups,
    required this.canManage,
    required this.busy,
    required this.onEnd,
    required this.onReactivate,
  });

  final AdminRecord record;
  final _Lookups lookups;
  final bool canManage, busy;
  final VoidCallback onEnd, onReactivate;

  @override
  Widget build(BuildContext context) {
    final values = record.values;
    final ended = values['status'] == 'ended';
    return Card(
      child: ListTile(
        title: Text(
          '${lookups.subjectName(values['subject'])} · '
          '${lookups.sectionLabel(values['section'])}',
        ),
        subtitle: Text(
          '${lookups.staffName(values['staff'])}\n'
          '${lookups.yearName(values['academic_year'])}'
          '${ended ? ' · Ended' : ' · Active'}',
        ),
        isThreeLine: true,
        trailing: !canManage
            ? null
            : ended
            ? TextButton(
                onPressed: busy ? null : onReactivate,
                child: const Text('Reactivate'),
              )
            : TextButton(
                onPressed: busy ? null : onEnd,
                child: const Text('End'),
              ),
      ),
    );
  }
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({required this.lookups});

  final _Lookups lookups;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  final _form = GlobalKey<FormState>();
  String? _section, _subject, _staff;

  @override
  Widget build(BuildContext context) {
    final lookups = widget.lookups;
    final sections = lookups.assignableSections;
    final subjects = lookups.assignableSubjects;
    final staff = lookups.assignableStaff;
    return AlertDialog(
      title: const Text('Assign teacher'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _picker(
                  label: 'Section',
                  emptyHint: 'No active sections.',
                  options: [
                    for (final s in sections)
                      (s.id, lookups.sectionLabel(s.id, withYear: true)),
                  ],
                  onChanged: (v) => _section = v,
                ),
                _picker(
                  label: 'Subject',
                  emptyHint: 'No active subjects.',
                  options: [
                    for (final s in subjects)
                      (s.id, lookups.subjectName(s.id)),
                  ],
                  onChanged: (v) => _subject = v,
                ),
                _picker(
                  label: 'Teacher',
                  emptyHint:
                      'No active teaching staff. Mark a staff member as '
                      'teaching first.',
                  options: [
                    for (final s in staff) (s.id, lookups.staffName(s.id)),
                  ],
                  onChanged: (v) => _staff = v,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, {
              'section': _section,
              'subject': _subject,
              'staff': _staff,
            });
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }

  Widget _picker({
    required String label,
    required String emptyHint,
    required List<(String, String)> options,
    required void Function(String?) onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: options.isEmpty
        ? InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Text(emptyHint),
          )
        : DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [
              for (final option in options)
                DropdownMenuItem(value: option.$1, child: Text(option.$2)),
            ],
            onChanged: onChanged,
            validator: (v) => v == null ? 'Required' : null,
          ),
  );
}

enum _Lookup {
  sections(ApiEndpoints.sections, 'sections'),
  gradeLevels(ApiEndpoints.gradeLevels, 'grade levels'),
  years(ApiEndpoints.academicYears, 'academic years'),
  subjects(ApiEndpoints.subjects, 'subjects'),
  staff(ApiEndpoints.staff, 'staff');

  const _Lookup(this.path, this.label);
  final String path, label;
}

/// Names for the ids the assignment API returns, resolved from the sections,
/// grade levels, academic years, subjects and staff lists. Each list loads on
/// its own: [records] holds the ones that loaded and [failures] the ones that
/// did not (value `true` = forbidden). An id missing from a loaded list reads
/// "Unknown ..."; a list that could not be loaded reads "Not available".
class _Lookups {
  const _Lookups({required this.records, required this.failures});

  const _Lookups.empty() : records = const {}, failures = const {};

  final Map<_Lookup, List<AdminRecord>> records;
  final Map<_Lookup, bool> failures;

  bool has(_Lookup kind) => records.containsKey(kind);

  /// Assigning needs all five lists: the pickers need sections, subjects and
  /// staff, and their labels need grade levels and years to be unambiguous.
  bool get canAssign => failures.isEmpty && _Lookup.values.every(has);

  /// Ending or reactivating needs the row to be identifiable by name.
  bool get canIdentifyRows =>
      has(_Lookup.sections) && has(_Lookup.subjects) && has(_Lookup.staff);

  String? get problem {
    if (failures.isEmpty) return null;
    final parts = [
      for (final entry in failures.entries)
        '${entry.key.label} (${entry.value ? 'no access' : 'could not be loaded'})',
    ];
    return 'Unavailable: ${parts.join(', ')}.'
        '${canAssign ? '' : ' Assigning is turned off.'}'
        '${canIdentifyRows ? '' : ' End and Reactivate are turned off.'}';
  }

  List<AdminRecord> _list(_Lookup kind) => records[kind] ?? const [];

  AdminRecord? _find(_Lookup kind, Object? id) {
    for (final record in _list(kind)) {
      if (record.id == id) return record;
    }
    return null;
  }

  String _name(_Lookup kind, Object? id, String unknown, String? Function(AdminRecord) name) {
    if (failures.containsKey(kind)) return 'Not available';
    final record = _find(kind, id);
    return record == null ? unknown : name(record) ?? unknown;
  }

  /// "8-A (Class 8)", plus " · 2026-2027" when [withYear] is set. Pickers and
  /// confirmations use the year: the same section name can exist in more
  /// than one academic year.
  String sectionLabel(Object? id, {bool withYear = false}) {
    if (failures.containsKey(_Lookup.sections)) return 'Not available';
    final section = _find(_Lookup.sections, id);
    if (section == null) return 'Unknown section';
    final grade = failures.containsKey(_Lookup.gradeLevels)
        ? null
        : _find(_Lookup.gradeLevels, section.values['grade_level'])?.name;
    final base = grade == null ? '${section.name}' : '${section.name} ($grade)';
    if (!withYear) return base;
    return '$base · ${yearName(section.values['academic_year'])}';
  }

  String subjectName(Object? id) =>
      _name(_Lookup.subjects, id, 'Unknown subject', (r) => r.name);

  String staffName(Object? id) => _name(
    _Lookup.staff,
    id,
    'Unknown staff member',
    (r) => r.values['full_name']?.toString(),
  );

  String yearName(Object? id) =>
      _name(_Lookup.years, id, 'Unknown year', (r) => r.name);

  Iterable<AdminRecord> get assignableSections =>
      _list(_Lookup.sections).where((s) => s.values['status'] == 'active');

  Iterable<AdminRecord> get assignableSubjects =>
      _list(_Lookup.subjects).where((s) => s.values['status'] == 'active');

  Iterable<AdminRecord> get assignableStaff => _list(_Lookup.staff).where(
    (s) => s.values['status'] == 'active' && s.values['is_teaching'] == true,
  );
}
