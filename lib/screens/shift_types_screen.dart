import 'package:flutter/cupertino.dart';
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
  String? _startTime;
  String? _endTime;
  late int _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _short = TextEditingController(text: e?.shortLabel ?? '');
    _startTime = e?.startTime;
    _endTime = e?.endTime;
    _color = e?.colorValue ?? _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: '시작',
                    value: _startTime,
                    onTap: () async {
                      final picked =
                          await _pickTime(_startTime ?? _endTime ?? '09:00');
                      if (picked != null) setState(() => _startTime = picked);
                    },
                    onClear: _startTime == null
                        ? null
                        : () => setState(() => _startTime = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: '종료',
                    value: _endTime,
                    onTap: () async {
                      final picked =
                          await _pickTime(_endTime ?? _startTime ?? '18:00');
                      if (picked != null) setState(() => _endTime = picked);
                    },
                    onClear: _endTime == null
                        ? null
                        : () => setState(() => _endTime = null),
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

  /// 시/분(10분 단위) 휠 피커를 띄우고 'HH:mm' 문자열을 돌려준다.
  /// 취소하면 null.
  Future<String?> _pickTime(String initial) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TimeWheelSheet(initial: initial),
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
    final String? start = _startTime;
    final String? end = _endTime;

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

/// 시작/종료 시간을 보여주고 탭하면 휠 피커를 여는 입력 필드.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        suffixIcon: hasValue
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: '시간 지우기',
                onPressed: onClear,
              )
            : const Icon(Icons.expand_more),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value ?? '선택 안 함',
            style: TextStyle(
              fontSize: 16,
              color: hasValue
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).hintColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// 시(0~23)와 분(10분 단위) 두 개의 휠로 시간을 고르는 바텀시트.
class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.initial});

  final String initial;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  static const List<int> _minutes = [0, 10, 20, 30, 40, 50];

  late int _hour;
  late int _minuteIndex;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    int h = 9;
    int m = 0;
    final parts = widget.initial.split(':');
    if (parts.length == 2) {
      h = int.tryParse(parts[0]) ?? 9;
      m = int.tryParse(parts[1]) ?? 0;
    }
    _hour = h.clamp(0, 23);
    // 가장 가까운 10분 눈금으로 맞춘다.
    final int rounded = ((m + 5) ~/ 10) * 10;
    _minuteIndex = _minutes.indexOf(rounded.clamp(0, 50));
    if (_minuteIndex < 0) _minuteIndex = 0;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minuteIndex);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  String get _formatted =>
      '${_hour.toString().padLeft(2, '0')}:'
      '${_minutes[_minuteIndex].toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '시간 선택',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _hourCtrl,
                    itemExtent: 40,
                    onSelectedItemChanged: (i) => setState(() => _hour = i),
                    children: [
                      for (int h = 0; h < 24; h++)
                        Center(
                          child: Text(
                            '${h.toString().padLeft(2, '0')}시',
                            style: TextStyle(fontSize: 20, color: onSurface),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _minuteCtrl,
                    itemExtent: 40,
                    onSelectedItemChanged: (i) =>
                        setState(() => _minuteIndex = i),
                    children: [
                      for (final m in _minutes)
                        Center(
                          child: Text(
                            '${m.toString().padLeft(2, '0')}분',
                            style: TextStyle(fontSize: 20, color: onSurface),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _formatted),
                    child: Text('$_formatted 선택'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
