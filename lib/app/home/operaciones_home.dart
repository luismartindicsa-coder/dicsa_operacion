import 'package:flutter/material.dart';

class OperacionesHome extends StatelessWidget {
  const OperacionesHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Dashboard OPERACIONES',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}