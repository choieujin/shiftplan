import 'package:flutter/material.dart';

import '../models/shift_type.dart';

/// 근무 유형 색상 범례를 가로로 표시한다.
class ShiftLegend extends StatelessWidget {
  const ShiftLegend({super.key, required this.types});

  final List<ShiftType> types;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final type in types)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: type.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(type.name),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
