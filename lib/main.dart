import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/location_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    print('✓ Loaded .env file successfully');
    print('✓ GEMINI_API_KEY loaded: ${dotenv.env['GEMINI_API_KEY'] != null ? "Yes" : "No"}');
    print('✓ GROQ_API_KEY loaded: ${dotenv.env['GROQ_API_KEY'] != null ? "Yes" : "No"}');
  } catch (e) {
    print('Warning: Failed to load .env file: $e');
  }
  runApp(const SpeechAIApp());
}

class SpeechAIApp extends StatelessWidget {
  const SpeechAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Site Lenz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(
        child: const LocationScreen(),
      ),
      routes: {
        '/main': (context) => const MainNavigationScreen(),
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LogsScreen(),
    const ChatbotScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Refresh logs screen when navigating to it
            if (index == 1) {
              // Logs screen will refresh on navigation
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'AI Chat',
          ),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}