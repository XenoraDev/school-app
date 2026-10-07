// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';
import 'package:school_app/features/admin_workspace/presentation/bloc/admin_workspace_cubit.dart';
import 'package:school_app/shared/feedback/error_state_view.dart';

class SchoolSettingsScreen extends StatefulWidget {
  const SchoolSettingsScreen({this.canManage = false, super.key});
  final bool canManage;
  @override
  State<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends State<SchoolSettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Set<int>? _workingDays;
  int? _weekStart;

  Future<void> _loadSettings() async {
    final cubit = context.read<AdminWorkspaceCubit>();
    await cubit.load(ApiEndpoints.schoolSettings);
    if (!mounted) return;
    final values = {
      for (final row in cubit.state.records)
        row.values['key']: row.values['value'],
    };
    setState(() {
      _workingDays = ((values['working_days'] as List?) ?? const [])
          .cast<num>()
          .map((n) => n.toInt())
          .toSet();
      _weekStart = values['week_start_day'] as int? ?? 1;
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AdminWorkspaceCubit, AdminWorkspaceState>(
        builder: (context, state) {
          if (state.loading && state.records.isEmpty)
            return const Center(child: CircularProgressIndicator());
          if (state.error != null && state.records.isEmpty)
            return ErrorStateView(
              title: 'Settings could not be loaded',
              message: state.error!,
              onRetry: _loadSettings,
            );
          final byKey = {
            for (final r in state.records) r.values['key'] as String: r,
          };
          final serverDays =
              (byKey['working_days']?.values['value'] as List?)
                  ?.cast<num>()
                  .map((n) => n.toInt())
                  .toSet() ??
              <int>{};
          final start = byKey['week_start_day']?.values['value'] as int? ?? 1;
          final days = _workingDays ?? serverDays;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'School settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text('Working days'),
              Wrap(
                spacing: 8,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(
                        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day -
                            1],
                      ),
                      selected: days.contains(day),
                      onSelected: (selected) => setState(() {
                        final next = Set<int>.from(days);
                        if (selected) {
                          next.add(day);
                        } else {
                          next.remove(day);
                        }
                        _workingDays = next;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _weekStart ?? start,
                decoration: const InputDecoration(labelText: 'Week starts on'),
                items: [
                  for (var day = 1; day <= 7; day++)
                    DropdownMenuItem(
                      value: day,
                      child: Text(
                        [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday',
                        ][day - 1],
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _weekStart = v);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: !widget.canManage || state.saving || byKey.length < 2
                    ? null
                    : () => _save(context, byKey, days, _weekStart ?? start),
                child: state.saving
                    ? const CircularProgressIndicator()
                    : const Text('Save settings'),
              ),
              if (state.error != null)
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          );
        },
      );
  Future<void> _save(
    BuildContext context,
    Map<String, AdminRecord> records,
    Set<int> days,
    int start,
  ) async {
    final cubit = context.read<AdminWorkspaceCubit>();
    await cubit.saveSpecial(
      (repo) => repo.updateSettings({
        'settings': [
          {
            'key': 'working_days',
            'value': days.toList()..sort(),
            'version': records['working_days']!.version,
          },
          {
            'key': 'week_start_day',
            'value': start,
            'version': records['week_start_day']!.version,
          },
        ],
      }),
    );
    if (mounted && cubit.state.error == null) await _loadSettings();
  }
}

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({this.canManage = false, super.key});
  final bool canManage;
  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  final year = TextEditingController(),
      grade = TextEditingController(),
      subjects = TextEditingController();
  @override
  void dispose() {
    year.dispose();
    grade.dispose();
    subjects.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AdminWorkspaceCubit, AdminWorkspaceState>(
    builder: (context, state) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Curriculum', style: Theme.of(context).textTheme.headlineSmall),
        const Text(
          'Use academic year and grade level IDs from the structure lists. One subject ID per line; each selected subject is saved as core.',
        ),
        TextField(
          controller: year,
          decoration: const InputDecoration(labelText: 'Academic year ID'),
        ),
        TextField(
          controller: grade,
          decoration: const InputDecoration(labelText: 'Grade level ID'),
        ),
        TextField(
          controller: subjects,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Subject IDs, one per line',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: state.loading ? null : () => _load(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Load curriculum'),
        ),
        FilledButton(
          onPressed: !widget.canManage || state.saving
              ? null
              : () => _save(context),
          child: state.saving
              ? const CircularProgressIndicator()
              : const Text('Replace curriculum'),
        ),
        if (state.error != null)
          Text(
            state.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (state.records.isNotEmpty) ...[
          const Divider(),
          for (final item in state.records)
            ListTile(
              title: Text(
                (item.values['subject'] as Map?)?['name']?.toString() ??
                    'Subject',
              ),
              subtitle: Text(item.values['kind']?.toString() ?? ''),
            ),
        ],
      ],
    ),
  );
  Future<void> _load(BuildContext context) async {
    if (year.text.trim().isEmpty || grade.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Academic year and grade level IDs are required.'),
        ),
      );
      return;
    }
    await context.read<AdminWorkspaceCubit>().load(
      ApiEndpoints.curriculum,
      query: {
        'academic_year': year.text.trim(),
        'grade_level': grade.text.trim(),
      },
    );
  }

  Future<void> _save(BuildContext context) async {
    final ids = subjects.text
        .split(RegExp(r'[\r\n,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (year.text.trim().isEmpty || grade.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Academic year and grade level IDs are required.'),
        ),
      );
      return;
    }
    final cubit = context.read<AdminWorkspaceCubit>();
    await cubit.replaceCurriculum(
      {
        'academic_year': year.text.trim(),
        'grade_level': grade.text.trim(),
        'subjects': [
          for (final id in ids) {'subject': id, 'kind': 'core'},
        ],
      },
      year.text.trim(),
      grade.text.trim(),
    );
  }
}

class RolesScreen extends StatefulWidget {
  const RolesScreen({this.canManage = false, super.key});
  final bool canManage;
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AdminWorkspaceCubit>().load(ApiEndpoints.roles);
    context.read<AdminWorkspaceCubit>().loadPermissions();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AdminWorkspaceCubit, AdminWorkspaceState>(
    builder: (context, state) {
      if (state.loading && state.records.isEmpty)
        return const Center(child: CircularProgressIndicator());
      if (state.error != null && state.records.isEmpty)
        return ErrorStateView(
          title: 'Roles could not be loaded',
          message: state.error!,
          onRetry: () =>
              context.read<AdminWorkspaceCubit>().load(ApiEndpoints.roles),
        );
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Roles & permissions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Review role permission sets. Replacing permissions requires your password and signs out current holders.',
          ),
          for (final role in state.records)
            Card(
              child: ListTile(
                title: Text(role.values['name']?.toString() ?? ''),
                subtitle: Text(
                  '${role.values['permission_count']} permissions · ${role.values['holder_count']} holders',
                ),
                onTap: widget.canManage ? () => _edit(context, role) : null,
              ),
            ),
          if (state.error != null)
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      );
    },
  );
  Future<void> _edit(BuildContext context, AdminRecord role) async {
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<AdminWorkspaceCubit>();
    await cubit.loadProfile(ApiEndpoints.role(role.id));
    if (!mounted) return;
    if (cubit.state.records.isEmpty) return;
    final initial =
        (cubit.state.records.first.values['permissions'] as List?)
            ?.cast<String>()
            .toSet() ??
        <String>{};
    final selected = Set<String>.from(initial);
    final password = TextEditingController();
    final dialogContext = context;
    final ok = await showDialog<bool>(
      context: dialogContext,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('${role.values['name']} permissions'),
          content: SizedBox(
            width: 520,
            height: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final group in cubit.state.permissions)
                          ExpansionTile(
                            title: Text(group.module),
                            children: [
                              for (final item in group.permissions)
                                CheckboxListTile(
                                  value: selected.contains(item.name),
                                  title: Text(item.name),
                                  subtitle: Text(item.action),
                                  onChanged: (value) => setDialog(
                                    () => value == true
                                        ? selected.add(item.name)
                                        : selected.remove(item.name),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Replace permissions'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final saved = await cubit.replacePermissions(role.id, {
        'permissions': selected.toList(),
        'password': password.text,
      });
      if (!mounted) return;
      if (!saved && cubit.state.error != null)
        messenger.showSnackBar(SnackBar(content: Text(cubit.state.error!)));
      if (saved) await cubit.load(ApiEndpoints.roles);
    } else {
      await cubit.load(ApiEndpoints.roles);
    }
    password.dispose();
  }
}
