import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import 'setup_screen.dart';
import 'login_screen.dart';
import 'tables_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final configured = await AppConfig.isConfigured();
    if (!configured) {
      _go(const SetupScreen());
      return;
    }
    final loggedIn = await AppConfig.isLoggedIn();
    if (!loggedIn) {
      _go(const LoginScreen());
      return;
    }
    _go(const TablesScreen());
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.restaurant_menu,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('FoodX',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text('Ofitsiant',
                style: TextStyle(
                    color: Colors.white.withAlpha(200), fontSize: 14)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}