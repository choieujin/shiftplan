import 'package:flutter/material.dart';

/// 근무 유형 (예: 주간, 야간, 휴무).
class ShiftType {
  ShiftType({
    required this.id,
    required this.name,
    required this.shortLabel,
    required this.colorValue,
    this.startTime,
    this.endTime,
  });

  /// 고유 id (문자열).
  final String id;

  /// 표시 이름 (예: "주간").
  final String name;

  /// 달력/위젯에 표시할 짧은 라벨 (예: "주").
  final String shortLabel;

  /// ARGB 정수 색상값.
  final int colorValue;

  /// 시작 시간 (예: "09:00"). 선택 사항.
  final String? startTime;

  /// 종료 시간 (예: "18:00"). 선택 사항.
  final String? endTime;

  Color get color => Color(colorValue);

  /// 시간 범위 문자열 (없으면 빈 문자열).
  String get timeRange {
    if (startTime == null || endTime == null) return '';
    return '$startTime ~ $endTime';
  }

  ShiftType copyWith({
    String? name,
    String? shortLabel,
    int? colorValue,
    String? startTime,
    String? endTime,
  }) {
    return ShiftType(
      id: id,
      name: name ?? this.name,
      shortLabel: shortLabel ?? this.shortLabel,
      colorValue: colorValue ?? this.colorValue,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortLabel': shortLabel,
        'colorValue': colorValue,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory ShiftType.fromJson(Map<String, dynamic> json) => ShiftType(
        id: json['id'] as String,
        name: json['name'] as String,
        shortLabel: json['shortLabel'] as String,
        colorValue: json['colorValue'] as int,
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
      );

  /// 앱 최초 실행 시 제공되는 기본 근무 유형들.
  static List<ShiftType> defaults() => [
        ShiftType(
          id: 'day',
          name: '주간',
          shortLabel: '주',
          colorValue: 0xFF2E7D32, // green 800
          startTime: '07:00',
          endTime: '15:00',
        ),
        ShiftType(
          id: 'evening',
          name: '오후',
          shortLabel: '오',
          colorValue: 0xFFF9A825, // amber 800
          startTime: '15:00',
          endTime: '23:00',
        ),
        ShiftType(
          id: 'night',
          name: '야간',
          shortLabel: '야',
          colorValue: 0xFF1565C0, // blue 800
          startTime: '23:00',
          endTime: '07:00',
        ),
        ShiftType(
          id: 'rest',
          name: '비번',
          shortLabel: '비',
          colorValue: 0xFF6D4C41, // brown 600
        ),
        ShiftType(
          id: 'off',
          name: '휴무',
          shortLabel: '휴',
          colorValue: 0xFF9E9E9E, // grey
        ),
      ];
}
