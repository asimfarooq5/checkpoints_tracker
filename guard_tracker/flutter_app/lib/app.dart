import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/home_screen.dart';
import 'screens/checkpoint_detail_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guard Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2563EB),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/permissions': (_) => const PermissionScreen(),
        '/home': (_) => const HomeScreen(),
        '/checkpoint-detail': (_) => const CheckpointDetailScreen(),
      },
    );
  }
}
