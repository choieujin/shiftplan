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

  final List<ShiftType> _types = [];
  // dateKey('yyyy-MM-dd') -> shiftTypeId
  final Map<String, String> _assignments = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<ShiftType> get types => List.unmodifiable(_types);

  Map<String, ShiftType> get typesById => {for (final t in _types) t.id: t};

  Map<String, String> get assignments => Map.unmodifiable(_assignments);

  ShiftType? typeForDate(DateTime date) {
    final String? id = _assignments[ShiftAssignment.keyFor(date)];
    if (id == null) return null;
    return typesById[id];
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
    final prefs = await SharedPreferences.getInstance();
    await _persistTypes(prefs);
    await _persistAssignments(prefs);
    notifyListeners();
    await _syncWidget();
  }

  // --- 날짜 배정 ------------------------------------------------------------

  Future<void> assign(DateTime date, String? shiftTypeId) async {
    final String key = ShiftAssignment.keyFor(date);
    if (shiftTypeId == null) {
      _assignments.remove(key);
    } else {
      _assignments[key] = shiftTypeId;
    }
    final prefs = await SharedPreferences.getInstance();
    await _persistAssignments(prefs);
    notifyListeners();
    await _syncWidget();
  }

  /// [start]부터 [days]일 동안 [pattern](근무 유형 id 목록)을 반복 적용한다.
  /// pattern의 요소가 null이면 해당 날짜를 비운다.
  Future<void> applyPattern({
    required DateTime start,
    required int days,
    required List<String?> pattern,
  }) async {
    if (pattern.isEmpty || days <= 0) return;
    final DateTime base = DateTime(start.year, start.month, start.day);
    for (int i = 0; i < days; i++) {
      final DateTime date = base.add(Duration(days: i));
      final String? typeId = pattern[i % pattern.length];
      final String key = ShiftAssignment.keyFor(date);
      if (typeId == null) {
        _assignments.remove(key);
      } else {
        _assignments[key] = typeId;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await _persistAssignments(prefs);
    notifyListeners();
    await _syncWidget();
  }

  Future<void> _syncWidget() async {
    await WidgetService.update(
      assignments: _assignments,
      typesById: typesById,
    );
  }
}
