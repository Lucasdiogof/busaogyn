import 'package:flutter/material.dart';

class BusaoGynApp extends StatelessWidget {
  const BusaoGynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BusãoGyn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const _FoundationPage(),
    );
  }
}

class _FoundationPage extends StatelessWidget {
  const _FoundationPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_bus_rounded, size: 64),
                SizedBox(height: 16),
                Text(
                  'BusãoGyn',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Saiba onde seu ônibus está.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
