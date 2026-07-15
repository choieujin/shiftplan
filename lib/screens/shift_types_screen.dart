import 'package:flutter/material.dart';

import '../models/shift_type.dart';
import '../services/shift_repository.dart';

class ShiftTypesScreen extends StatelessWidget {
  const ShiftTypesScreen({super.key, required this.repository});

  final ShiftRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('근무 유형 관리')),
      body: AnimatedBuilder(
        animation: repository,
        builder: (context, _) {
          final types = repository.types;
          return ListView.separated(
            itemCount: types.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final type = types[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: type.color,
                  child: Text(
                    type.shortLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(type.name),
                subtitle: type.timeRange.isEmpty ? null : Text(type.timeRange),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openEditor(context, existing: type),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, type),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ShiftType type) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${type.name}" 삭제'),
        content: const Text('이 근무 유형과 배정된 날짜가 모두 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repository.deleteType(type.id);
    }
  }

  Future<void> _openEditor(BuildContext context, {ShiftType? existing}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ShiftTypeEditor(
        repository: repository,
        existing: existing,
      ),
    );
  }
}

class _ShiftTypeEditor extends StatefulWidget {
  const _ShiftTypeEditor({required this.repository, this.existing});

  final ShiftRepository repository;
  final ShiftType? existing;

  @override
  State<_ShiftTypeEditor> createState() => _ShiftTypeEditorState();
}

class _ShiftTypeEditorState extends State<_ShiftTypeEditor> {
  static const List<int> _palette = [
    0xFF2E7D32,
    0xFF1565C0,
    0xFFF9A825,
    0xFFC62828,
    0xFF6A1B9A,
    0xFF00838F,
    0xFFEF6C00,
    0xFF9E9E9E,
    0xFF37474F,
    0xFFAD1457,
  ];

  late final TextEditingController _name;
  late final TextEditingController _short;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late int _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _short = TextEditingController(text: e?.shortLabel ?? '');
    _start = TextEditingController(text: e?.startTime ?? '');
    _end = TextEditingController(text: e?.endTime ?? '');
    _color = e?.colorValue ?? _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? '근무 유형 수정' : '근무 유형 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '이름 (예: 주간)'),
            ),
            TextField(
              controller: _short,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: '짧은 라벨 (예: 주)',
                counterText: '',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _start,
                    decoration: const InputDecoration(
                      labelText: '시작 (선택)',
                      hintText: '09:00',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _end,
                    decoration: const InputDecoration(
                      labelText: '종료 (선택)',
                      hintText: '18:00',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('색상', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    final String short = _short.text.trim();
    if (name.isEmpty || short.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 짧은 라벨을 입력하세요.')),
      );
      return;
    }
    final String? start = _start.text.trim().isEmpty ? null : _start.text.trim();
    final String? end = _end.text.trim().isEmpty ? null : _end.text.trim();

    if (widget.existing == null) {
      await widget.repository.addType(
        ShiftType(
          id: 'type_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          shortLabel: short,
          colorValue: _color,
          startTime: start,
          endTime: end,
        ),
      );
    } else {
      await widget.repository.updateType(
        widget.existing!.copyWith(
          name: name,
          shortLabel: short,
          colorValue: _color,
          startTime: start,
          endTime: end,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
