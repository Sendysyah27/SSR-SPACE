import 'package:flutter/material.dart';
import 'package:ssr_space/core/session/session_service.dart';

class HomeScreen extends StatelessWidget {
  final SessionService session;
  const HomeScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSR SPACE')),
      body: Center(child: Text('Sesi: ${session.sessionId.substring(0, 8)}...')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
