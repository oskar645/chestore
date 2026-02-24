import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _niceAuthError(AuthException e) {
    final msg = e.message.toLowerCase();

    if (msg.contains('email rate limit exceeded')) {
      return 'Слишком часто отправляли письма. Подожди немного и попробуй снова.';
    }
    if (msg.contains('invalid login credentials')) {
      return 'Неверный email или пароль.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email не подтверждён. Открой письмо и подтвердите.';
    }
    if (msg.contains('user already registered')) {
      return 'Этот email уже зарегистрирован. Попробуй войти.';
    }
    return e.message;
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _snack('Введите email, чтобы восстановить пароль');
      return;
    }

    setState(() => _loading = true);
    try {
      await _sb.auth.resetPasswordForEmail(email);
      _snack('Ссылка для сброса пароля отправлена на почту');
    } on AuthException catch (e) {
      _snack(_niceAuthError(e));
    } catch (e) {
      _snack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _snack('Введите email и пароль');
      return;
    }

    if (!_isLogin) {
      if (name.isEmpty) {
        _snack('Введите имя');
        return;
      }
      if (phone.isEmpty) {
        _snack('Введите номер телефона');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        // ===== ВХОД =====
        final res = await _sb.auth.signInWithPassword(email: email, password: pass);

        if (res.session == null) {
          // при включённой проверке email обычно будет ошибка, но на всякий случай
          throw const AuthException('Не удалось войти. Подтвердите email и попробуйте снова.');
        }
      } else {
        // ===== РЕГИСТРАЦИЯ =====
        // Важно: при включенном подтверждении email session может быть null,
        // поэтому НЕЛЬЗЯ после signUp писать в public.users (RLS не даст).
        await _sb.auth.signUp(
          email: email,
          password: pass,
          data: {
            'name': name,
            'displayName': name,
            'phone': phone,
          },
        );

        if (!mounted) return;

        // Открываем экран подтверждения письма
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              email: email,
              password: pass,
              name: name,
              phone: phone,
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      _snack(_niceAuthError(e));
    } catch (e) {
      _snack('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Вход' : 'Регистрация'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_isLogin) ...[
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Телефон'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Пароль'),
            onSubmitted: (_) => _loading ? null : _submit(),
          ),

          if (_isLogin) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _loading ? null : _resetPassword,
                child: const Text('Забыли пароль?'),
              ),
            ),
          ],

          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Подождите...' : (_isLogin ? 'Войти' : 'Создать аккаунт')),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _passCtrl.clear();
                    });
                  },
            child: Text(_isLogin ? 'Нет аккаунта? Регистрация' : 'Уже есть аккаунт? Войти'),
          ),
        ],
      ),
    );
  }
}