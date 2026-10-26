import 'package:flutter/material.dart';

import '../../services/workout_category_service.dart';

class WorkoutCategoriesScreen extends StatefulWidget {
  const WorkoutCategoriesScreen({super.key, required this.legacyCategories});
  final List<String> legacyCategories;

  @override
  State<WorkoutCategoriesScreen> createState() =>
      _WorkoutCategoriesScreenState();
}

class _WorkoutCategoriesScreenState extends State<WorkoutCategoriesScreen> {
  final _settings = WorkoutCategoryService.instance.watch();

  Future<void> _edit(
    WorkoutCategorySettings settings, {
    String? existing,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryNameDialog(existing: existing),
    );
    if (value == null || !mounted) return;
    try {
      if (existing == null) {
        await WorkoutCategoryService.instance.add(value, settings);
      } else {
        await WorkoutCategoryService.instance.rename(existing, value, settings);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    }
  }

  Future<void> _delete(WorkoutCategorySettings settings, String name) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '“$name” will be removed from your category list. Existing workouts keep this category and remain available under All and search.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await WorkoutCategoryService.instance.delete(name, settings);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    }
  }

  String _friendlyError(Object error) =>
      error is ArgumentError || error is StateError
      ? error.toString().replaceFirst('Invalid argument(s): ', '')
      : 'Could not save category. Check your connection and try again.';

  Future<void> _setVisible(
    WorkoutCategorySettings settings,
    String name,
    bool visible,
  ) async {
    try {
      await WorkoutCategoryService.instance.setVisible(name, visible, settings);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Categories')),
    body: StreamBuilder<WorkoutCategorySettings>(
      stream: _settings,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Unable to load categories. Please sign in and try again.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final settings = snapshot.data!;
        final categories = <String>{
          ...WorkoutCategoryService.systemCategories,
          ...settings.custom,
          ...widget.legacyCategories,
        }.toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Choose which categories appear in your Workout filters. Existing workout records are never changed.',
              style: TextStyle(color: Color(0xFF9AA69C)),
            ),
            const SizedBox(height: 16),
            ...categories.map((name) {
              final isSystem = WorkoutCategoryService.systemCategories.contains(
                name,
              );
              final isCustom = settings.custom.contains(name);
              final visible = !settings.hidden.contains(name);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B17),
                  border: Border.all(color: const Color(0xFF27332B)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(
                    isSystem
                        ? 'Built-in category'
                        : isCustom
                        ? 'Custom category'
                        : 'Used by existing workouts',
                  ),
                  leading: Icon(
                    isSystem ? Icons.lock_outline_rounded : Icons.sell_outlined,
                    color: const Color(0xFF9BFF3D),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCustom) ...[
                        IconButton(
                          tooltip: 'Rename',
                          onPressed: () => _edit(settings, existing: name),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(settings, name),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                      Switch(
                        value: visible,
                        onChanged: (value) =>
                            _setVisible(settings, name, value),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _edit(settings),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Category'),
            ),
          ],
        );
      },
    ),
  );
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({this.existing});

  final String? existing;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add category' : 'Rename category'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 30,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(hintText: 'e.g. Mobility'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(widget.existing == null ? 'Add' : 'Save'),
      ),
    ],
  );
}
