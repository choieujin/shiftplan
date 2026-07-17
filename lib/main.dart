import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/calendar_screen.dart';
import 'services/shift_repository.dart';
import 'services/widget_service.dart';
import 'widgets/ad_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  await WidgetService.init();
  if (AdBanner.supported) {
    // 광고 SDK 초기화는 앱 표시를 막지 않도록 기다리지 않는다.
    unawaited(MobileAds.instance.initialize());
  }

  final ShiftRepository repository = ShiftRepository();
  await repository.load();

  runApp(ShiftPlanApp(repository: repository));
}

class ShiftPlanApp extends StatelessWidget {
  const ShiftPlanApp({super.key, required this.repository});

  final ShiftRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '교대근무 시간표',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3F51B5),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3F51B5),
        brightness: Brightness.dark,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      locale: const Locale('ko'),
      home: CalendarScreen(repository: repository),
    );
  }
}
