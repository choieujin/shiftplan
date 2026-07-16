import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/shift_repository.dart';

/// 교대 패턴을 정의해 여러 날에 반복 적용하는 화면.
/// 예: "주주야비휴" 를 입력하면 [주, 주, 야, 비, 휴] 를 시작일부터 N일간 반복.
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

/// 패턴 문자열 파싱 결과.
class _ParseResult {
  const _ParseResult(this.pattern, this.error);

  /// 근무 유형 id 시퀀스. null 은 "배정 없음"(비우기).
  final List<String?> pattern;
  final String? error;
}

class _PatternScreenState extends State<PatternScreen> {
  late DateTime _start;
  bool _unlimited = true;
  final TextEditingController _days = TextEditingController(text: '30');
  final TextEditingController _patternText = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start = widget.startDate;
  }

  @override
  void dispose() {
    _days.dispose();
    _patternText.dispose();
    super.dispose();
  }

  /// 패턴 문자열을 근무 유형 id 목록으로 파싱한다.
  ///
  /// - 짧은 라벨("주")과 이름("주간") 모두 인식하며, 긴 것부터 매칭한다.
  /// - 공백/쉼표는 구분자로 무시하고, '-' 는 "배정 비우기"로 처리한다.
  _ParseResult _parse(String text) {
    final entries = <MapEntry<String, String>>[
      for (final t in widget.repository.types) ...[
        MapEntry(t.shortLabel, t.id),
        MapEntry(t.name, t.id),
      ],
    ]
      ..removeWhere((e) => e.key.isEmpty)
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    final List<String?> result = [];
    int i = 0;
    while (i < text.length) {
      final String ch = text[i];
      if (ch == ' ' || ch == ',' || ch == '/') {
        i++;
        continue;
      }
      if (ch == '-') {
        result.add(null);
        i++;
        continue;
      }
      MapEntry<String, String>? matched;
      for (final e in entries) {
        if (text.startsWith(e.key, i)) {
          matched = e;
          break;
        }
      }
      if (matched == null) {
        return _ParseResult(
          const [],
          "'$ch'에 해당하는 근무 유형이 없습니다. 근무 유형 관리에서 먼저 추가하세요.",
        );
      }
      result.add(matched.value);
      i += matched.key.length;
    }
    return _ParseResult(result, null);
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final _ParseResult parsed = _parse(_patternText.text);
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('무제한 적용'),
            subtitle: const Text('시작일 이후 모든 날짜에 계속 반복됩니다.'),
            value: _unlimited,
            onChanged: (v) => setState(() => _unlimited = v),
          ),
          if (!_unlimited) ...[
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
          ],
          if (repo.hasPatternRule) ...[
            const SizedBox(height: 8),
            _buildCurrentRuleCard(),
          ],
          const SizedBox(height: 24),
          Text('근무 패턴', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '근무 라벨을 이어서 입력하세요. 이 순서가 반복 적용됩니다. '
            "'-' 는 배정 비우기입니다.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _patternText,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: '패턴 입력',
              hintText: '예: 주주야비휴',
              border: const OutlineInputBorder(),
              errorText: parsed.error,
              suffixIcon: _patternText.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _patternText.clear()),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPatternPreview(parsed),
          const SizedBox(height: 16),
          Text(
            '아래 근무를 눌러 패턴에 추가할 수도 있습니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
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
                  onPressed: () => _append(type.shortLabel),
                ),
              ActionChip(
                avatar: const CircleAvatar(
                    radius: 10, child: Icon(Icons.remove, size: 12)),
                label: const Text('비움'),
                onPressed: () => _append('-'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed:
                parsed.error != null || parsed.pattern.isEmpty ? null : _apply,
            icon: const Icon(Icons.check),
            label: const Text('패턴 적용'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentRuleCard() {
    final repo = widget.repository;
    final typesById = repo.typesById;
    final String labels = repo.patternRule
        .map((id) => id == null ? '-' : (typesById[id]?.shortLabel ?? '?'))
        .join();
    final String since =
        DateFormat('yyyy년 M월 d일', 'ko').format(repo.patternRuleStart!);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.all_inclusive),
        title: Text('적용 중인 무제한 패턴: $labels'),
        subtitle: Text('$since 부터 반복'),
        trailing: TextButton(
          onPressed: () async {
            await repo.clearPatternRule();
            if (mounted) setState(() {});
          },
          child: const Text('해제'),
        ),
      ),
    );
  }

  void _append(String label) {
    setState(() {
      _patternText.text += label;
    });
  }

  Widget _buildPatternPreview(_ParseResult parsed) {
    if (parsed.pattern.isEmpty) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${parsed.pattern.length}일 주기로 반복',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final String? id in parsed.pattern)
                  Chip(
                    backgroundColor: id == null
                        ? null
                        : typesById[id]?.color.withOpacity(0.2),
                    label: Text(
                      id == null ? '비움' : (typesById[id]?.shortLabel ?? '?'),
                    ),
                  ),
              ],
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
    int? days;
    if (!_unlimited) {
      days = int.tryParse(_days.text.trim()) ?? 0;
      if (days <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('적용 일수를 올바르게 입력하세요.')),
        );
        return;
      }
    }
    final _ParseResult parsed = _parse(_patternText.text);
    if (parsed.error != null || parsed.pattern.isEmpty) return;
    await widget.repository.applyPattern(
      start: _start,
      days: days,
      pattern: parsed.pattern,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          days == null ? '시작일 이후 무제한으로 패턴을 적용했습니다.' : '$days일간 패턴을 적용했습니다.',
        ),
      ),
    );
    Navigator.pop(context);
  }
}
