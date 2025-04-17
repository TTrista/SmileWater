import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'home_page.dart';
import 'history_page.dart';
import 'history_records_list.dart';
//import 'history_bar_chart.dart';
import 'profile_page.dart';
//import 'package:intl/intl.dart';

void main() {
  runApp(const SmileWaterApp());
}

class SmileWaterApp extends StatelessWidget {
  const SmileWaterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smile Water',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/home': (context) => HomePage(), // 主页
        '/history': (context) => const HistoryPage(),
        '/history_list': (context) => const HistoryRecordsListPage(), // 你要写的记录页
        //'/history_chart': (context) => const HistoryBarChartPage(), // 你要写的图表页
        '/profile': (context) => const ProfilePage(), // 个人资料页
      },
    );
  }
}
