import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'splash_screen.dart';
import 'models/history_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        fontFamily: 'Nunito', // theme font
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),

      home: const SplashScreenWrapper(),
    );
  }
}

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
    return _showMain ? const MainNavigationPage() : SplashScreen();
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 1;
  List<HistoryEntry> _records = [];

  void _addRecord(HistoryEntry entry) {
    setState(() {
      _records.insert(0, entry); 
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      const HistoryPage(), 
      HomePage(onNewRecord: _addRecord),
      const ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,

        selectedLabelStyle: const TextStyle(
          fontFamily: 'BubblegumSans', 
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'BubblegumSans',
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history_edu),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sentiment_satisfied_alt_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
