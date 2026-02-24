import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chestore2/src/services/profile_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String password;
  final String? name;
  final String? phone;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.password,
    this.name,
    this.phone,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;

  SupabaseClient get _sb => Supabase.instance.client;

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await _sb.auth.resend(type: OtpType.signup, email: widget.email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Письмо отправлено ещё раз')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkAndLogin() async {
    setState(() => _checking = true);
    try {
      final authRes = await _sb.auth.signInWithPassword(
        email: widget.email,
        password: widget.password,
      );

      if (authRes.session == null || authRes.user == null) {
        throw const AuthException('Не удалось войти');
      }

      final userId = authRes.user!.id;

      // ✅ Сохраняем имя и телефон в таблицу users
      if (widget.name != null || widget.phone != null) {
        final profile = ProfileService();
        await profile.updateProfile(userId, {
          if (widget.name != null) 'display_name': widget.name,
          if (widget.name != null) 'name': widget.name,
          if (widget.phone != null) 'phone': widget.phone,
        });
      }

      if (!mounted) return;

      // Теперь AuthGate увидит session и пустит в MainShell
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ещё не подтверждено: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подтвердите email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Мы отправили письмо для подтверждения на:\n${widget.email}'),
            const SizedBox(height: 12),
            const Text('Открой письмо и нажми "Confirm".'),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _sending ? null : _resend,
              child: Text(_sending ? 'Отправляем...' : 'Отправить письмо ещё раз'),
            ),

            const SizedBox(height: 12),

            FilledButton.tonal(
              onPressed: _checking ? null : _checkAndLogin,
              child: Text(_checking ? 'Проверяем...' : 'Я подтвердил — войти'),
            ),
          ],
        ),
      ),
    );
  }
}