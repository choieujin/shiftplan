import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shift_assignment.dart';
import '../models/shift_type.dart';
import 'widget_service.dart';

/// 근무 유형과 날짜별 배정을 관리하는 단일 소스.
///
/// [ChangeNotifier]로 UI에 변경을 알리고, 변경마다 홈 위젯을 갱신한다.
class ShiftRepository extends ChangeNotifier {
  static const String _typesKey = 'shift_types';
  static const String _assignmentsKey = 'shift_assignments';
  static const String _ruleKey = 'pattern_rule';
  static const String _memosKey = 'shift_memos';

  /// 반복 패턴이 덮는 날짜를 명시적으로 비웠음을 나타내는 배정값.
  static const String _clearedMarker = '';

  final List<ShiftType> _types = [];
  // dateKey('yyyy-MM-dd') -> shiftTypeId ('' 은 명시적 비움)
  final Map<String, String> _assignments = {};
  // dateKey('yyyy-MM-dd') -> 메모 텍스트 (약속/연차/월차 등)
  final Map<String, String> _memos = {};

  // 시작일부터 무제한 반복되는 패턴 규칙.
  DateTime? _ruleStart;
  List<String?> _rulePattern = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<ShiftType> get types => List.unmodifiable(_types);

  Map<String, ShiftType> get typesById => {for (final t in _types) t.id: t};

  Map<String, String> get assignments => Map.unmodifiable(_assignments);

  Map<String, String> get memos => Map.unmodifiable(_memos);

  /// [date]에 기록된 메모. 없으면 빈 문자열.
  String memoForDate(DateTime date) =>
      _memos[ShiftAssignment.keyFor(date)] ?? '';

  bool get hasPatternRule => _ruleStart != null && _rulePattern.isNotEmpty;

  DateTime? get patternRuleStart => _ruleStart;

  List<String?> get patternRule => List.unmodifiable(_rulePattern);

  ShiftType? typeForDate(DateTime date) {
    final String? id = _assignments[ShiftAssignment.keyFor(date)];
    if (id != null) {
      return id == _clearedMarker ? null : typesById[id];
    }
    final String? ruleId = _ruleTypeIdFor(date);
    return ruleId == null ? null : typesById[ruleId];
  }

  /// 반복 패턴 규칙이 [date]에 배정하는 근무 유형 id. 규칙이 없거나
  /// 시작일 이전이거나 해당 칸이 비움이면 null.
  String? _ruleTypeIdFor(DateTime date) {
    final DateTime? start = _ruleStart;
    if (start == null || _rulePattern.isEmpty) return null;
    final DateTime day = DateTime(date.year, date.month, date.day);
    final int diff = day.difference(start).inDays;
    if (diff < 0) return null;
    return _rulePattern[diff % _rulePattern.length];
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? typesRaw = prefs.getString(_typesKey);
    _types.clear();
    if (typesRaw != null) {
      final List<dynamic> list = jsonDecode(typesRaw) as List<dynamic>;
      _types.addAll(
        list.map((e) => ShiftType.fromJson(e as Map<String, dynamic>)),
      );
    }
    if (_types.isEmpty) {
      _types.addAll(ShiftType.defaults());
    }

    final String? assignRaw = prefs.getString(_assignmentsKey);
    _assignments.clear();
    if (assignRaw != null) {
      final Map<String, dynamic> map =
          jsonDecode(assignRaw) as Map<String, dynamic>;
      map.forEach((k, v) => _assignments[k] = v as String);
    }

    final String? memosRaw = prefs.getString(_memosKey);
    _memos.clear();
    if (memosRaw != null) {
      final Map<String, dynamic> map =
          jsonDecode(memosRaw) as Map<String, dynamic>;
      map.forEach((k, v) => _memos[k] = v as String);
    }

    final String? ruleRaw = prefs.getString(_ruleKey);
    _ruleStart = null;
    _rulePattern = [];
    if (ruleRaw != null) {
      final Map<String, dynamic> rule =
          jsonDecode(ruleRaw) as Map<String, dynamic>;
      _ruleStart = DateTime.parse(rule['start'] as String);
      _rulePattern = (rule['pattern'] as List<dynamic>)
          .map((e) => e as String?)
          .toList();
    }

    _loaded = true;
    notifyListeners();
    await _syncWidget();
  }

  Future<void> _persistTypes(SharedPreferences prefs) async {
    await prefs.setString(
      _typesKey,
      jsonEncode(_types.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _persistAssignments(SharedPreferences prefs) async {
    await prefs.setString(_assignmentsKey, jsonEncode(_assignments));
  }

  Future<void> _persistMemos(SharedPreferences prefs) async {
    await prefs.setString(_memosKey, jsonEncode(_memos));
  }

  Future<void> _persistRule(SharedPreferences prefs) async {
    if (_ruleStart == null || _rulePattern.isEmpty) {
      await prefs.remove(_ruleKey);
      return;
    }
    await prefs.setString(
      _ruleKey,
      jsonEncode({
        'start': ShiftAssignment.keyFor(_ruleStart!),
        'pattern': _rulePattern,
      }),
    );
  }

  // --- 근무 유형 관리 -------------------------------------------------------

  Future<void> addType(ShiftType type) async {
    _types.add(type);
    final prefs = await SharedPreferences.getInstance();
    await _persistTypes(prefs);
    notifyListeners();
    await _syncWidget();
  }

  Future<void> updateType(ShiftType type) async {
    final int idx = _types.indexWhere((t) => t.id == type.id);
    if (idx == -1) return;
    _types[idx] = type;
    final prefs = await SharedPreferences.getInstance();
    await _persistTypes(prefs);
    notifyListeners();
    await _syncWidget();
  }

  Future<void> deleteType(String id) async {
    _types.removeWhere((t) => t.id == id);
    // 해당 유형이 배정된 날짜도 비운다.
    _assignments.removeWhere((_, typeId) => typeId == id);
    // 반복 패턴 규칙에서도 해당 유형 칸을 비운다.
    _rulePattern = [
      for (final String? typeId in _rulePattern)
        typeId == id ? null : typeId,
    ];
    final prefs = await SharedPreferences.getInstance();
    await _persistTypes(prefs);
    await _persistAssignments(prefs);
    await _persistRule(prefs);
    notifyListeners();
    await _syncWidget();
  }

  // --- 날짜 배정 ------------------------------------------------------------

  Future<void> assign(DateTime date, String? shiftTypeId) async {
    final String key = ShiftAssignment.keyFor(date);
    _setAssignment(key, date, shiftTypeId);
    final prefs = await SharedPreferences.getInstance();
    await _persistAssignments(prefs);
    notifyListeners();
    await _syncWidget();
  }

  // --- 날짜 메모 -----------------------------------------------------------

  /// [date]의 메모를 [text]로 설정한다. 빈 문자열이면 메모를 삭제한다.
  Future<void> setMemo(DateTime date, String text) async {
    final String key = ShiftAssignment.keyFor(date);
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      _memos.remove(key);
    } else {
      _memos[key] = trimmed;
    }
    final prefs = await SharedPreferences.getInstance();
    await _persistMemos(prefs);
    notifyListeners();
    await _syncWidget();
  }

  /// [key]([date])의 배정을 [shiftTypeId]로 바꾼다. null 이면 비우되,
  /// 반복 패턴 규칙이 그 날짜를 덮고 있으면 명시적 비움으로 기록해
  /// 규칙이 다시 드러나지 않게 한다.
  void _setAssignment(String key, DateTime date, String? shiftTypeId) {
    if (shiftTypeId != null) {
      _assignments[key] = shiftTypeId;
    } else if (_ruleTypeIdFor(date) != null) {
      _assignments[key] = _clearedMarker;
    } else {
      _assignments.remove(key);
    }
  }

  /// [start]부터 [pattern](근무 유형 id 목록)을 반복 적용한다.
  /// pattern의 요소가 null이면 해당 날짜를 비운다.
  ///
  /// [days]가 null이면 시작일 이후 무제한 반복되는 규칙으로 저장하고,
  /// 시작일 이후의 기존 날짜별 배정은 제거한다.
  Future<void> applyPattern({
    required DateTime start,
    required List<String?> pattern,
    int? days,
  }) async {
    if (pattern.isEmpty || (days != null && days <= 0)) return;
    final DateTime base = DateTime(start.year, start.month, start.day);
    final prefs = await SharedPreferences.getInstance();

    if (days == null) {
      _ruleStart = base;
      _rulePattern = List.of(pattern);
      final String startKey = ShiftAssignment.keyFor(base);
      _assignments.removeWhere((key, _) => key.compareTo(startKey) >= 0);
      await _persistRule(prefs);
    } else {
      for (int i = 0; i < days; i++) {
        final DateTime date = base.add(Duration(days: i));
        _setAssignment(
          ShiftAssignment.keyFor(date),
          date,
          pattern[i % pattern.length],
        );
      }
    }
    await _persistAssignments(prefs);
    notifyListeners();
    await _syncWidget();
  }

  /// 무제한 반복 패턴 규칙을 해제한다. 규칙 위에 기록된 명시적 비움도
  /// 함께 정리한다.
  Future<void> clearPatternRule() async {
    if (!hasPatternRule) return;
    _ruleStart = null;
    _rulePattern = [];
    _assignments.removeWhere((_, typeId) => typeId == _clearedMarker);
    final prefs = await SharedPreferences.getInstance();
    await _persistRule(prefs);
    await _persistAssignments(prefs);
    notifyListeners();
    await _syncWidget();
  }

  Future<void> _syncWidget() async {
    // typeForDate가 반복 패턴 규칙과 명시적 비움까지 반영한다.
    await WidgetService.update(typeFor: typeForDate, memoFor: memoForDate);
  }
}
