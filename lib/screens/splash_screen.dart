import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend_parchis/service/prefs_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/splash/splash_logo.png'), context);

      Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          final lastRoom = PrefsService.lastRoomCode;

          // ✅ REGLA 2: Si el usuario recarga la página (Web),
          // detectamos si tenía una sala activa para reconectarlo automáticamente.
          if (lastRoom != null && lastRoom.isNotEmpty) {
            Navigator.of(context).pushReplacementNamed('/online_lobby');
          } else {
            Navigator.of(context).pushReplacementNamed('/menu');
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Center(
          child: Image.asset(
            'assets/splash/splash_logo.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'PARCHÉ',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
