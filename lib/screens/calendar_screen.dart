import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/shift_type.dart';
import '../services/holiday_service.dart';
import '../services/shift_repository.dart';
import '../widgets/ad_banner.dart';
import '../widgets/shift_legend.dart';
import 'pattern_screen.dart';
import 'shift_types_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.repository});

  final ShiftRepository repository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  ShiftRepository get repo => widget.repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교대근무 시간표'),
        actions: [
          IconButton(
            tooltip: '근무 패턴 적용',
            icon: const Icon(Icons.repeat),
            onPressed: _openPatternScreen,
          ),
          IconButton(
            tooltip: '근무 유형 관리',
            icon: const Icon(Icons.settings),
            onPressed: _openTypesScreen,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: repo,
        builder: (context, _) {
          return Column(
            children: [
              _buildCalendar(),
              const Divider(height: 1),
              ShiftLegend(types: repo.types),
              const Divider(height: 1),
              Expanded(child: _buildSelectedDayPanel()),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignSheet(_selectedDay),
        icon: const Icon(Icons.edit_calendar),
        label: const Text('근무 배정'),
      ),
      bottomNavigationBar: const AdBanner(),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      locale: 'ko',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableCalendarFormats: const {CalendarFormat.month: '월간'},
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      // 일요일과 대한민국 공휴일은 빨간 글씨로 표시한다.
      weekendDays: const [DateTime.sunday],
      holidayPredicate: HolidayService.isHoliday,
      calendarStyle: const CalendarStyle(
        weekendTextStyle: TextStyle(color: Colors.red),
        holidayTextStyle: TextStyle(color: Colors.red),
        holidayDecoration: BoxDecoration(),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekendStyle: TextStyle(color: Colors.red),
      ),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
      },
      onPageChanged: (focused) => _focusedDay = focused,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          final ShiftType? type = repo.typeForDate(day);
          if (type == null) return null;
          return Positioned(
            bottom: 4,
            child: Container(
              width: 20,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: type.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type.shortLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedDayPanel() {
    final ShiftType? type = repo.typeForDate(_selectedDay);
    final String dateLabel =
        DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedDay);
    final String? holiday = HolidayService.holidayName(_selectedDay);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(dateLabel, style: Theme.of(context).textTheme.titleMedium),
              if (holiday != null) ...[
                const SizedBox(width: 8),
                Text(
                  holiday,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Colors.red),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (type == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.event_available),
                title: Text('배정된 근무 없음'),
                subtitle: Text('아래 버튼으로 근무를 배정하세요.'),
              ),
            )
          else
            Card(
              child: ListTile(
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
                subtitle:
                    type.timeRange.isEmpty ? null : Text(type.timeRange),
                trailing: IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: '배정 취소',
                  onPressed: () => repo.assign(_selectedDay, null),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAssignSheet(DateTime date) async {
    final String dateLabel =
        DateFormat('M월 d일 (E)', 'ko').format(date);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$dateLabel 근무 선택',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...repo.types.map(
                (type) => ListTile(
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
                  subtitle:
                      type.timeRange.isEmpty ? null : Text(type.timeRange),
                  onTap: () {
                    repo.assign(date, type.id);
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.clear)),
                title: const Text('배정 없음'),
                onTap: () {
                  repo.assign(date, null);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openTypesScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShiftTypesScreen(repository: repo),
      ),
    );
  }

  void _openPatternScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatternScreen(repository: repo, startDate: _selectedDay),
      ),
    );
  }
}
