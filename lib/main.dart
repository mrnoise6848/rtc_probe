import 'package:flutter/material.dart';
import 'package:rtc_probe/ui/dashboard_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RTCProbe',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF155E75)),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF67E8F9),
        brightness: Brightness.dark,
      ),
    ),
    home: const DashboardScreen(),
  );
}
