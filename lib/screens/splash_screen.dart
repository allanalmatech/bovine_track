import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_gate_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGateScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE7F7DC), Color(0xFFC6EDB8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white,
                child: Icon(Icons.pets, size: 56, color: Color(0xFF0B5D1E)),
              ),
              SizedBox(height: 16),
              Text(
                'BovineTrack',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6),
              Text('Livestock Security & Geofencing'),
            ],
          ),
        ),
      ),
    );
  }
}
