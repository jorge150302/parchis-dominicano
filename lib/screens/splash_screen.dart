import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // Intentamos precargar la imagen para evitar el flash negro en Web
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/splash/splash_logo.png'), context);

      // Reducimos un poco el tiempo o lo hacemos dinámico
      Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/menu');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Color de fondo mientras carga la imagen
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
            // Añadimos un placeholder o error builder para debug
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
