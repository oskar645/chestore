import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import '../home/main_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final sb = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: sb.auth.onAuthStateChange,
      builder: (context, snap) {
        final session = sb.auth.currentSession;

        if (session == null) return const LoginScreen();

        return const MainShell();
      },
    );
  }
}