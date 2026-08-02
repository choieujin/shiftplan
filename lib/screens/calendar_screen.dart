import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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

  /// 달력 영역을 이미지로 캡처하기 위한 경계 키.
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  ShiftRepository get repo => widget.repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교대근무 시간표'),
        actions: [
          IconButton(
            tooltip: '달력 이미지 공유',
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            onPressed: _sharing ? null : _shareCalendar,
          ),
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
              RepaintBoundary(
                key: _shareKey,
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      _buildCalendar(),
                      const Divider(height: 1),
                      ShiftLegend(types: repo.types),
                    ],
                  ),
                ),
              ),
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
      rowHeight: 54,
      daysOfWeekHeight: 20,
      sixWeekMonthsEnforced: false,
      availableCalendarFormats: const {CalendarFormat.month: '월간'},
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      // 일요일과 대한민국 공휴일은 빨간 글씨로 표시한다.
      weekendDays: const [DateTime.sunday],
      holidayPredicate: HolidayService.isHoliday,
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
      // 날짜 숫자를 근무색 원으로 표시하고 그 아래 메모를 한 줄 띄운다.
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, _) => _dayCell(day),
        todayBuilder: (context, day, _) => _dayCell(day, today: true),
        selectedBuilder: (context, day, _) => _dayCell(day, selected: true),
        holidayBuilder: (context, day, _) => _dayCell(day),
        outsideBuilder: (context, day, _) => _dayCell(day, outside: true),
        disabledBuilder: (context, day, _) => _dayCell(day, outside: true),
      ),
    );
  }

  /// 날짜 한 칸: 근무가 있으면 숫자를 근무색 원으로, 없으면 평범한 숫자로
  /// 그리고 그 아래에 메모(있으면)를 한 줄 표시한다.
  Widget _dayCell(
    DateTime day, {
    bool selected = false,
    bool today = false,
    bool outside = false,
  }) {
    final ShiftType? type = repo.typeForDate(day);
    final String memo = repo.memoForDate(day);
    final bool red =
        day.weekday == DateTime.sunday || HolidayService.isHoliday(day);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Color numberColor = outside
        ? scheme.onSurface.withOpacity(0.35)
        : (red ? Colors.red : scheme.onSurface);

    Widget number;
    if (type != null) {
      number = Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: type.color.withOpacity(outside ? 0.45 : 1),
          shape: BoxShape.circle,
        ),
        child: Text(
          '${day.day}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      number = Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: today
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary, width: 1.5),
              )
            : null,
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: numberColor,
            fontSize: 13,
            fontWeight: today ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? Border.all(color: scheme.primary, width: 1.6)
            : (today
                ? Border.all(color: scheme.primary.withOpacity(0.4), width: 1)
                : null),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          number,
          const SizedBox(height: 2),
          SizedBox(
            height: 12,
            width: double.infinity,
            child: memo.isEmpty
                ? const SizedBox.shrink()
                : Text(
                    memo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5,
                      height: 1.1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayPanel() {
    final ShiftType? type = repo.typeForDate(_selectedDay);
    final String memo = repo.memoForDate(_selectedDay);
    final String dateLabel =
        DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedDay);
    final String? holiday = HolidayService.holidayName(_selectedDay);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 92),
      children: [
        Column(
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
          const SizedBox(height: 8),
          if (type == null)
            const Card(
              margin: EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.event_available),
                title: Text('배정된 근무 없음'),
                subtitle: Text('아래 버튼으로 근무를 배정하세요.'),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                dense: true,
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
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.event_note),
            title: Text(memo.isEmpty ? '메모 없음' : memo),
            subtitle: Text(
              memo.isEmpty ? '약속·연차·월차 등을 기록하세요.' : '탭하여 수정',
            ),
            trailing: memo.isEmpty
                ? const Icon(Icons.add)
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '메모 삭제',
                    onPressed: () => repo.setMemo(_selectedDay, ''),
                  ),
            onTap: () => _editMemo(_selectedDay),
          ),
        ),
      ],
    );
  }

  Future<void> _editMemo(DateTime date) async {
    final controller =
        TextEditingController(text: repo.memoForDate(date));
    final String dateLabel = DateFormat('M월 d일 (E)', 'ko').format(date);
    final String? result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$dateLabel 메모'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: '예: 연차, 오후 3시 약속',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != null) {
      await repo.setMemo(date, result);
    }
  }

  Future<void> _shareCalendar() async {
    setState(() => _sharing = true);
    Uint8List? bytes;
    try {
      // 한 프레임 기다려 최신 상태가 그려지도록 한다.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final boundary = _shareKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = byteData?.buffer.asUint8List();
      }
    } catch (_) {
      bytes = null;
    } finally {
      // 캡처가 끝나면 즉시 스피너를 멈춘다. 공유시트의 취소 동작은
      // (iOS에서 future가 늦게/안 돌아올 수 있어) 스피너와 분리한다.
      if (mounted) setState(() => _sharing = false);
    }

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('달력 이미지를 만들지 못했습니다.')),
        );
      }
      return;
    }

    final String stamp = DateFormat('yyyyMM').format(_focusedDay);
    final String monthLabel =
        DateFormat('yyyy년 M월', 'ko').format(_focusedDay);
    try {
      // 파일을 직접 만들지 않고 바이트로 공유해 웹까지 동일하게 동작한다.
      // iOS/Android 공유시트에서 '이미지 저장' 및 '복사'를 지원한다.
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'shiftplan_$stamp.png',
            mimeType: 'image/png',
          ),
        ],
        text: '$monthLabel 근무표',
      );
    } catch (_) {
      // 공유시트 취소/실패는 조용히 무시한다.
    }
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
