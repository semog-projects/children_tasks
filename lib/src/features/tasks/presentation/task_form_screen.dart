import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task.dart';
import '../../family/application/family_providers.dart';
import '../application/task_providers.dart';

/// Formulário de criar/editar uma tarefa.
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final Task? task;

  bool get isEditing => task != null;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
  late final _descCtrl = TextEditingController(text: widget.task?.description ?? '');
  late final _pointsCtrl =
      TextEditingController(text: (widget.task?.points ?? 10).toString());

  late TaskCategory _category = widget.task?.category ?? TaskCategory.routine;
  late String? _assigneeId = widget.task?.assigneeMemberId;
  late RecurrenceType _recurrenceType =
      widget.task?.recurrence.type ?? RecurrenceType.daily;
  final Set<int> _daysOfWeek = {};
  late DateTime _startDate = widget.task?.recurrence.startDate ?? _today();
  late DateTime? _endDate = widget.task?.recurrence.endDate;
  late bool _requiresApproval = widget.task?.requiresApproval ?? true;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _daysOfWeek.addAll(widget.task?.recurrence.daysOfWeek ?? const []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(_today().year - 1),
      lastDate: DateTime(_today().year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recurrenceType == RecurrenceType.weekly && _daysOfWeek.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha ao menos um dia da semana')),
      );
      return;
    }

    final description = _descCtrl.text.trim();
    final task = Task(
      id: widget.task?.id ?? '',
      title: _titleCtrl.text.trim(),
      description: description.isEmpty ? null : description,
      points: int.parse(_pointsCtrl.text),
      category: _category,
      assigneeMemberId: _assigneeId,
      requiresApproval: _requiresApproval,
      active: widget.task?.active ?? true,
      recurrence: Recurrence(
        type: _recurrenceType,
        daysOfWeek: _recurrenceType == RecurrenceType.weekly
            ? (_daysOfWeek.toList()..sort())
            : const [],
        startDate: _startDate,
        endDate: _recurrenceType == RecurrenceType.once ? null : _endDate,
      ),
      createdAt: widget.task?.createdAt,
      updatedAt: widget.task?.updatedAt,
    );

    await ref.read(taskControllerProvider.notifier).save(task);
    if (!ref.read(taskControllerProvider).hasError && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taskControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Não foi possível salvar a tarefa.')));
      }
    });

    final busy = ref.watch(taskControllerProvider).isLoading;
    final children = ref.watch(familyChildrenProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Editar tarefa' : 'Nova tarefa')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Título'),
                    textCapitalization: TextCapitalization.sentences,
                    autofocus: true,
                    maxLength: 80,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe um título' : null,
                  ),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pointsCtrl,
                    decoration: const InputDecoration(labelText: 'Pontos'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Informe um número maior que zero';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Categoria'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in TaskCategory.values)
                        ChoiceChip(
                          label: Text(c.label),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _assigneeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Para quem'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas as crianças')),
                      for (final child in children)
                        DropdownMenuItem(value: child.id, child: Text(child.displayName)),
                    ],
                    onChanged: (v) => setState(() => _assigneeId = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Repetição'),
                  const SizedBox(height: 8),
                  SegmentedButton<RecurrenceType>(
                    segments: [
                      for (final t in RecurrenceType.values)
                        ButtonSegment(value: t, label: Text(t.label)),
                    ],
                    selected: {_recurrenceType},
                    onSelectionChanged: (s) => setState(() => _recurrenceType = s.first),
                  ),
                  if (_recurrenceType == RecurrenceType.weekly) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          FilterChip(
                            label: Text(weekdayShortLabels[d - 1]),
                            selected: _daysOfWeek.contains(d),
                            onSelected: (on) => setState(() {
                              on ? _daysOfWeek.add(d) : _daysOfWeek.remove(d);
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Começa em'),
                    subtitle: Text(_fmt(_startDate)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _pickDate(isStart: true),
                    ),
                  ),
                  if (_recurrenceType != RecurrenceType.once)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Termina em (opcional)'),
                      subtitle: Text(_endDate == null ? 'Sem data de fim' : _fmt(_endDate!)),
                      trailing: Wrap(
                        children: [
                          if (_endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _endDate = null),
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => _pickDate(isStart: false),
                          ),
                        ],
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exige aprovação do responsável'),
                    subtitle: const Text('Os pontos só entram depois que você aprovar'),
                    value: _requiresApproval,
                    onChanged: (v) => setState(() => _requiresApproval = v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(busy ? 'Salvando…' : 'Salvar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
