import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import '../home/main_shell.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    final sb = Supabase.instance.client;

    _sub = sb.auth.onAuthStateChange.listen((state) {
      if (mounted) {
        setState(() {});
      }

      // Когда пользователь открыл ссылку Reset Password,
      // Supabase выдаёт событие passwordRecovery.
      if (state.event == AuthChangeEvent.passwordRecovery) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sb = Supabase.instance.client;
    final session = sb.auth.currentSession;

    if (session == null) return const LoginScreen();
    return const MainShell();
  }
}
