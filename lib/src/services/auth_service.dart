// lib/src/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Простой пользователь, похожий на Firebase User
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;

  /// Аналог Firebase: user.emailVerified
  final bool emailVerified;

  /// Аналог Firebase: user.photoURL
  final String? photoURL;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    required this.emailVerified,
    this.photoURL,
  });
}

class AuthService {
  final sb.SupabaseClient _client = sb.Supabase.instance.client;

  /// Стрим изменений авторизации (аналог Firebase authStateChanges)
  ///
  /// Важно: сначала эмитим текущее состояние, потом слушаем onAuthStateChange.
  Stream<AppUser?> authStateChanges() async* {
    // 1) текущее состояние
    yield currentUser;

    // 2) изменения
    yield* _client.auth.onAuthStateChange.map((_) {
      final u = _client.auth.currentUser;
      return u == null ? null : _fromSbUser(u);
    });
  }

  /// Текущий пользователь (или null)
  AppUser? get currentUser {
    final sb.User? u = _client.auth.currentUser;
    if (u == null) return null;
    return _fromSbUser(u);
  }

  AppUser _fromSbUser(sb.User u) {
    final meta = u.userMetadata ?? const <String, dynamic>{};

    final name = (meta['displayName'] ??
            meta['display_name'] ??
            meta['name'])
        ?.toString();

    final photo = (meta['photoURL'] ??
            meta['photo_url'] ??
            meta['avatar_url'] ??
            meta['avatarUrl'])
        ?.toString();

    // В Supabase email подтверждён, если emailConfirmedAt != null
    final verified = u.emailConfirmedAt != null;

    return AppUser(
      uid: u.id,
      email: u.email,
      displayName: name,
      emailVerified: verified,
      photoURL: photo,
    );
  }

  /// Регистрация по email + password
  Future<void> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );

    if (res.user == null) {
      throw Exception('Не удалось создать пользователя');
    }
  }

  /// Вход по email + password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.session == null) {
      throw Exception('Не удалось войти');
    }
  }

  /// Повторно отправить письмо подтверждения (если включено подтверждение email в Supabase)
  Future<void> sendVerificationEmail() async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) return;

    await _client.auth.resend(
      type: sb.OtpType.signup,
      email: email,
    );
  }

  /// Обновление данных пользователя
  Future<void> reloadUser() async {
    await _client.auth.getUser();
  }

  /// Выход
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}