// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:school_app/core/config/api_endpoints.dart';
import 'package:school_app/features/admin_workspace/data/models/admin_models.dart';
import 'package:school_app/features/admin_workspace/presentation/bloc/admin_workspace_cubit.dart';
import 'package:school_app/features/auth/domain/entities/account_profile.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:school_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:school_app/shared/feedback/error_state_view.dart';

class AdminWorkspaceShell extends StatelessWidget {
  const AdminWorkspaceShell({
    required this.profile,
    required this.child,
    super.key,
  });
  final AccountProfile profile;
  final Widget child;
  static const items = <(String, String, IconData, String)>[
    ('/admin/setup', 'Setup', Icons.checklist, 'school.view'),
    ('/admin/profile', 'School profile', Icons.apartment, 'school.view'),
    ('/admin/settings', 'Settings', Icons.settings, 'school.view'),
    (
      '/admin/academic-years',
      'Academic years',
      Icons.calendar_month,
      'academic_years.view',
    ),
    ('/admin/terms', 'Terms', Icons.event_note, 'academic_years.view'),
    ('/admin/grade-levels', 'Grade levels', Icons.stairs, 'classes.view'),
    ('/admin/sections', 'Sections', Icons.class_, 'classes.view'),
    ('/admin/subjects', 'Subjects', Icons.menu_book, 'subjects.view'),
    ('/admin/curriculum', 'Curriculum', Icons.library_books, 'subjects.view'),
    ('/admin/staff', 'Staff directory', Icons.people, 'staff.view'),
    (
      '/admin/roles',
      'Roles & permissions',
      Icons.admin_panel_settings,
      'roles.view',
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(profile.school.name),
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    drawer: Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'School administration',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final item in items)
              if (profile.can(item.$4))
                ListTile(
                  leading: Icon(item.$3),
                  title: Text(item.$2),
                  selected: GoRouterState.of(context).uri.path == item.$1,
                  onTap: () {
                    Navigator.pop(context);
                    context.go(item.$1);
                  },
                ),
          ],
        ),
      ),
    ),
    body: child,
  );
}

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});
  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AdminWorkspaceCubit>().loadSetup();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AdminWorkspaceCubit, AdminWorkspaceState>(
        builder: (context, state) {
          if (state.loading && state.steps.isEmpty)
            return const Center(child: CircularProgressIndicator());
          if (state.error != null && state.steps.isEmpty)
            return ErrorStateView(
              title: 'Setup checklist could not be loaded',
              message: state.error!,
              onRetry: () => context.read<AdminWorkspaceCubit>().loadSetup(),
            );
          return RefreshIndicator(
            onRefresh: () => context.read<AdminWorkspaceCubit>().loadSetup(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'School setup',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                for (final step in state.steps)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        step.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: step.done ? Colors.green : null,
                      ),
                      title: Text(_label(step.key)),
                      subtitle: Text(step.done ? 'Complete' : 'Not complete'),
                    ),
                  ),
                if (state.error != null)
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

String _label(String key) => key
    .split('_')
    .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
    .join(' ');

class AdminResourceScreen extends StatefulWidget {
  const AdminResourceScreen({
    required this.title,
    required this.path,
    required this.fields,
    super.key,
    this.create = true,
    this.canEdit = true,
    this.updatePath,
    this.singleResource = false,
    this.canReorder = false,
    this.searchable = false,
    this.actions = const [],
  });
  final String title, path;
  final List<AdminField> fields;
  final bool create, canEdit, singleResource, canReorder, searchable;
  final String? updatePath;
  final List<AdminAction> actions;
  @override
  State<AdminResourceScreen> createState() => _AdminResourceScreenState();
}

class _AdminResourceScreenState extends State<AdminResourceScreen> {
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() => widget.singleResource
      ? context.read<AdminWorkspaceCubit>().loadProfile(widget.path)
      : context.read<AdminWorkspaceCubit>().load(
          widget.path,
          query: widget.canReorder ? {'per_page': 100} : null,
        );
  Future<void> _searchRows() => context.read<AdminWorkspaceCubit>().load(
    widget.path,
    query: _search.text.trim().isEmpty
        ? null
        : {'filter[q]': _search.text.trim()},
  );

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<AdminWorkspaceCubit, AdminWorkspaceState>(
    builder: (context, state) {
      if (state.loading && state.records.isEmpty)
        return const Center(child: CircularProgressIndicator());
      if (state.error != null && state.records.isEmpty)
        return ErrorStateView(
          title: '${widget.title} could not be loaded',
          message: state.error!,
          onRetry: _load,
        );
      return Column(
        children: [
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Search ${widget.title.toLowerCase()}',
                  suffixIcon: IconButton(
                    onPressed: _searchRows,
                    icon: const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (_) => _searchRows(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (widget.canReorder)
                  OutlinedButton(
                    onPressed: _reorder,
                    child: const Text('Reorder'),
                  ),
                if (widget.create)
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
              ],
            ),
          ),
          if (state.error != null)
            MaterialBanner(
              content: Text(state.error!),
              actions: [
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          Expanded(
            child: state.records.isEmpty
                ? Center(child: Text('No ${widget.title.toLowerCase()} found.'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        for (final record in state.records)
                          Card(
                            child: ListTile(
                              title: Text(
                                (record.values['name'] ??
                                        record.values['full_name'] ??
                                        record.values['employee_no'] ??
                                        record.id)
                                    .toString(),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.values.entries
                                        .where(
                                          (e) =>
                                              e.key != 'id' && e.key != 'name',
                                        )
                                        .take(3)
                                        .map(
                                          (e) =>
                                              '${_label(e.key)}: ${e.value ?? '\u2014'}',
                                        )
                                        .join(' \u00B7 '),
                                  ),
                                  SelectableText('ID: ${record.id}'),
                                ],
                              ),
                              onTap: widget.canEdit
                                  ? () => _edit(record)
                                  : null,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) => _action(record, value),
                                itemBuilder: (_) => [
                                  if (widget.canEdit)
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                  for (final action in widget.actions)
                                    if (_actionAvailable(record, action.suffix))
                                      PopupMenuItem(
                                        value: action.suffix,
                                        child: Text(action.label),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        if (state.hasMore)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: OutlinedButton(
                              onPressed: state.loading
                                  ? null
                                  : () => context
                                        .read<AdminWorkspaceCubit>()
                                        .loadMore(widget.path),
                              child: Text(
                                state.loading ? 'Loading…' : 'Load more',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    },
  );

  bool _actionAvailable(AdminRecord record, String action) {
    final status = record.values['status'];
    final login = record.values['login'];
    return switch (action) {
      'activate' => status == 'planned',
      'close' =>
        widget.path == ApiEndpoints.academicYears
            ? status == 'current'
            : status == 'active',
      'archive' => status == 'active',
      'unarchive' => status == 'archived',
      'reopen' => status == 'closed',
      'disable-login' => login == 'active',
      'enable-login' => login == 'disabled',
      _ => true,
    };
  }

  Future<void> _edit([AdminRecord? record]) async {
    if (record != null && !widget.canEdit) return;
    final fields = widget.fields
        .where((field) => record == null || field.editable)
        .toList();
    final controllers = {
      for (final field in fields)
        field.key: TextEditingController(
          text: record?.values[field.key]?.toString() ?? '',
        ),
    };
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          '${record == null ? 'Add' : 'Edit'} ${widget.title.singular}',
        ),
        content: Form(
          key: form,
          child: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        controller: controllers[field.key],
                        keyboardType: field.multiline
                            ? TextInputType.multiline
                            : TextInputType.text,
                        maxLines: field.multiline ? 3 : 1,
                        decoration: InputDecoration(
                          labelText: field.label,
                          hintText: field.hint,
                        ),
                        validator: field.required
                            ? (value) => value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _save(dialog, form, controllers, fields, record),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Future<void> _save(
    BuildContext dialog,
    GlobalKey<FormState> form,
    Map<String, TextEditingController> controllers,
    List<AdminField> fields,
    AdminRecord? record,
  ) async {
    if (!form.currentState!.validate()) return;
    final body = <String, dynamic>{};
    for (final field in fields) {
      final value = controllers[field.key]!.text.trim();
      if (value.isEmpty) {
        if (field.nullable) body[field.key] = null;
        continue;
      }
      body[field.key] = switch (field.type) {
        'int' => int.tryParse(value) ?? value,
        'bool' => value.toLowerCase() == 'true',
        'json' => jsonDecode(value),
        _ => value,
      };
    }
    if (record != null && record.values.containsKey('version'))
      body['version'] = record.version;
    final cubit = context.read<AdminWorkspaceCubit>();
    await cubit.send(
      record == null ? 'POST' : 'PATCH',
      record == null
          ? widget.path
          : (widget.updatePath ?? '${widget.path}/${record.id}'),
      body: body,
      refreshPath: widget.singleResource ? null : widget.path,
    );
    if (widget.singleResource && cubit.state.error == null)
      await cubit.loadProfile(widget.path);
    if (mounted && cubit.state.error == null && dialog.mounted)
      Navigator.pop(dialog);
  }

  Future<void> _action(AdminRecord record, String action) async {
    if (action == 'edit') {
      await _edit(record);
      return;
    }
    final base = switch (widget.path) {
      ApiEndpoints.academicYears => ApiEndpoints.academicYear(record.id),
      ApiEndpoints.terms => ApiEndpoints.term(record.id),
      ApiEndpoints.gradeLevels => ApiEndpoints.gradeLevel(record.id),
      ApiEndpoints.sections => '${ApiEndpoints.sections}/${record.id}',
      ApiEndpoints.subjects => ApiEndpoints.subject(record.id),
      ApiEndpoints.staff => ApiEndpoints.staffRecord(record.id),
      _ => widget.path,
    };
    final endpoint = widget.actions
        .firstWhere((item) => item.suffix == action)
        .endpoint(base, record.id);
    final cubit = context.read<AdminWorkspaceCubit>();
    if (action == 'close') {
      final body = await _closeDetails(record);
      if (body == null) return;
      await cubit.send('POST', endpoint, body: body, refreshPath: widget.path);
    } else if (action == 'class-teacher') {
      final staff = await _chooseStaff(cubit);
      if (identical(staff, _cancelled)) return;
      await cubit.send(
        'PUT',
        endpoint,
        body: {'staff': staff},
        refreshPath: widget.path,
      );
    } else if (action == 'delete') {
      await cubit.delete(endpoint, refreshPath: widget.path);
    } else {
      await cubit.send('POST', endpoint, refreshPath: widget.path);
    }
    if (mounted && cubit.state.error != null)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cubit.state.error!)));
  }

  static const Object _cancelled = Object();
  Future<Object?> _chooseStaff(AdminWorkspaceCubit cubit) async {
    final staff = await cubit.fetchRecords(ApiEndpoints.staff);
    if (!mounted) return _cancelled;
    return showDialog<Object?>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Assign class teacher'),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Clear assignment'),
                onTap: () => Navigator.pop(dialog, null),
              ),
              for (final member in staff)
                ListTile(
                  title: Text(member.values['full_name']?.toString() ?? ''),
                  subtitle: Text(
                    member.values['employee_no']?.toString() ?? '',
                  ),
                  onTap: () => Navigator.pop(dialog, member.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, _cancelled),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<JsonMap?> _closeDetails(AdminRecord record) async {
    final reason = TextEditingController(), password = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<JsonMap?>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Close academic year'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator: (value) => value == null || value.trim().length < 8
                    ? 'Enter at least 8 characters'
                    : null,
              ),
              TextFormField(
                initialValue: record.values['name']?.toString(),
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm year name',
                ),
              ),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(dialog, {
                  'reason': reason.text.trim(),
                  'confirm_name': record.values['name'],
                  'password': password.text,
                });
            },
            child: const Text('Close year'),
          ),
        ],
      ),
    );
    reason.dispose();
    password.dispose();
    return result;
  }

  Future<void> _reorder() async {
    final records = List<AdminRecord>.from(
      context.read<AdminWorkspaceCubit>().state.records,
    );
    final cubit = context.read<AdminWorkspaceCubit>();
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Reorder grade levels'),
          content: SizedBox(
            width: 480,
            height: 520,
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) => setDialog(() {
                if (newIndex > oldIndex) newIndex--;
                final row = records.removeAt(oldIndex);
                records.insert(newIndex, row);
              }),
              children: [
                for (final item in records)
                  ListTile(
                    key: ValueKey(item.id),
                    leading: const Icon(Icons.drag_handle),
                    title: Text(item.values['name']?.toString() ?? ''),
                    subtitle: Text(item.id),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await cubit.send(
                  'POST',
                  ApiEndpoints.gradeLevelReorder,
                  body: {'order': records.map((item) => item.id).toList()},
                  refreshPath: widget.path,
                );
                if (dialog.mounted && cubit.state.error == null)
                  Navigator.pop(dialog);
              },
              child: const Text('Save order'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String get singular => endsWith('s') ? substring(0, length - 1) : this;
}

class AdminField {
  const AdminField(
    this.key,
    this.label, {
    this.required = false,
    this.nullable = false,
    this.type = 'text',
    this.hint,
    this.multiline = false,
    this.editable = true,
  });
  final String key, label;
  final bool required, nullable, multiline, editable;
  final String type;
  final String? hint;
}

class AdminAction {
  const AdminAction(this.label, this.suffix, this.endpoint);
  final String label, suffix;
  final String Function(String, String) endpoint;
}
