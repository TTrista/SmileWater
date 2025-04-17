import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'home_page.dart';
import 'history_page.dart';
import 'profile_page.dart';

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
      home: const SplashScreenWrapper(),
    );
  }
}

// 启动画面控制器：显示 splash，然后跳转主页
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _showMain = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _showMain = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showMain ? const MainNavigationPage() :  SplashScreen();
  }
}

// 主界面带底部导航，使用 IndexedStack 保持页面状态
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 1;

  final List<Widget> _pages = const [
    HistoryPage(),
    HomePage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.history_edu), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_emotions), label: 'Me'),
        ],
      ),
    );
  }
}
