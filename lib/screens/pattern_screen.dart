import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/shift_repository.dart';

/// 교대 패턴을 정의해 여러 날에 반복 적용하는 화면.
/// 예: [주, 주, 야, 야, 휴, 휴] 를 시작일부터 N일간 반복.
class PatternScreen extends StatefulWidget {
  const PatternScreen({
    super.key,
    required this.repository,
    required this.startDate,
  });

  final ShiftRepository repository;
  final DateTime startDate;

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  late DateTime _start;
  final TextEditingController _days = TextEditingController(text: '30');

  // 패턴 시퀀스. null 은 "배정 없음"(휴무처럼 비우기).
  final List<String?> _pattern = [];

  @override
  void initState() {
    super.initState();
    _start = widget.startDate;
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    return Scaffold(
      appBar: AppBar(title: const Text('근무 패턴 적용')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_arrow),
            title: const Text('시작일'),
            subtitle: Text(DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_start)),
            trailing: TextButton(
              onPressed: _pickStart,
              child: const Text('변경'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _days,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '적용 일수',
              hintText: '예: 30',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('패턴 순서', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '아래 근무를 눌러 순서를 추가하세요. 이 순서가 반복 적용됩니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildPatternPreview(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in repo.types)
                ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: type.color,
                    radius: 10,
                  ),
                  label: Text(type.name),
                  onPressed: () => setState(() => _pattern.add(type.id)),
                ),
              ActionChip(
                avatar: const CircleAvatar(radius: 10, child: Icon(Icons.remove, size: 12)),
                label: const Text('휴무/비움'),
                onPressed: () => setState(() => _pattern.add(null)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _pattern.isEmpty ? null : _apply,
            icon: const Icon(Icons.check),
            label: const Text('패턴 적용'),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternPreview() {
    if (_pattern.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('아직 패턴이 없습니다.'),
        ),
      );
    }
    final typesById = widget.repository.typesById;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < _pattern.length; i++)
              InputChip(
                backgroundColor: _pattern[i] == null
                    ? null
                    : typesById[_pattern[i]]?.color.withOpacity(0.2),
                label: Text(
                  _pattern[i] == null
                      ? '휴'
                      : (typesById[_pattern[i]]?.shortLabel ?? '?'),
                ),
                onDeleted: () => setState(() => _pattern.removeAt(i)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _apply() async {
    final int days = int.tryParse(_days.text.trim()) ?? 0;
    if (days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('적용 일수를 올바르게 입력하세요.')),
      );
      return;
    }
    await widget.repository.applyPattern(
      start: _start,
      days: days,
      pattern: _pattern,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$days일간 패턴을 적용했습니다.')),
    );
    Navigator.pop(context);
  }
}
