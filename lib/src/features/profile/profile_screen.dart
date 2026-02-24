import 'package:chestore2/src/features/admin/admin_screen.dart';
import 'package:chestore2/src/features/profile/settings_screen.dart';
import 'package:chestore2/src/services/admin_service.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/profile_service.dart';
import 'package:chestore2/src/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(
    BuildContext context,
    String uid,
    String currentName,
  ) async {
    final ctrl = TextEditingController(text: currentName);
    final profile = context.read<ProfileService>();

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Имя'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Введите имя'),
          onSubmitted: (_) => Navigator.pop(context, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    final name = (res ?? '').trim();
    if (name.isEmpty) return;

    // ✅ Supabase users
    await profile.updateProfile(uid, {
      'display_name': name,
      'name': name,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя сохранено')),
      );
    }
  }

  Future<void> _editPhone(
    BuildContext context,
    String uid,
    String currentPhone,
  ) async {
    final ctrl = TextEditingController(text: currentPhone);
    final profile = context.read<ProfileService>();

    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Номер телефона'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Введите номер телефона'),
          onSubmitted: (_) => Navigator.pop(context, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    final phone = (res ?? '').trim();
    if (phone.isEmpty) return;

    // ✅ Supabase users
    await profile.updateProfile(uid, {
      'phone': phone,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Номер телефона сохранен')),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthService>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final profile = context.read<ProfileService>();
    final admin = context.read<AdminService>();

    final user = auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Нужно войти')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: false,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: profile.streamProfile(user.uid),
        builder: (context, snap) {
          final data = snap.data ?? const <String, dynamic>{};

          final displayNameFs = (data['display_name'] ?? data['displayName'] ?? '').toString().trim();
          final nameFs = (data['name'] ?? '').toString().trim();

          final name = displayNameFs.isNotEmpty
              ? displayNameFs
              : (nameFs.isNotEmpty
                  ? nameFs
                  : ((user.displayName?.trim().isNotEmpty ?? false)
                      ? user.displayName!.trim()
                      : (user.email ?? 'Пользователь')));

          final phone = (data['phone'] ?? '').toString().trim();

          return ListView(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(photoUrl: user.photoURL, fallbackText: name),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _editName(context, user.uid, name),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _editPhone(context, user.uid, phone),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                phone.isEmpty ? 'Добавить телефон' : phone,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _StatsRow(
                            ratingAvgStream:
                                profile.streamMyRatingAvg(user.uid),
                            reviewsCountStream:
                                profile.streamMyReviewsCount(user.uid),
                            listingsStream:
                                profile.streamMyListingsCount(user.uid),
                            followers: '0',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      leading: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Тёмная тема'),
                      trailing: Switch(
                        value: context.watch<ThemeService>().mode ==
                            ThemeMode.dark,
                        onChanged: (v) =>
                            context.read<ThemeService>().toggle(v),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ✅ Админ-панель (видит только админ) — через Supabase AdminService
                    StreamBuilder<bool>(
                      stream: admin.streamIsAdmin(user.uid),
                      builder: (context, s) {
                        final isAdmin = s.data == true;
                        if (!isAdmin) return const SizedBox.shrink();

                        return Column(
                          children: [
                            ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              tileColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              leading: const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                              title: const Text('Админ-панель'),
                              subtitle:
                                  const Text('Управление приложением'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),

                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Настройки'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // ✅ ВЫХОД: красный + подтверждение
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Выйти',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String fallbackText;

  const _Avatar({this.photoUrl, required this.fallbackText});

  @override
  Widget build(BuildContext context) {
    final t = fallbackText.trim();
    final letter = t.isEmpty ? 'U' : t[0].toUpperCase();

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ClipOval(
        child: (photoUrl == null || photoUrl!.isEmpty)
            ? Center(
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(photoUrl!, fit: BoxFit.cover),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Stream<double> ratingAvgStream;
  final Stream<int> reviewsCountStream;
  final Stream<int> listingsStream;
  final String followers;

  const _StatsRow({
    required this.ratingAvgStream,
    required this.reviewsCountStream,
    required this.listingsStream,
    required this.followers,
  });

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StreamBuilder<double>(
          stream: ratingAvgStream,
          builder: (_, s) =>
              _stat(context, (s.data ?? 0.0).toStringAsFixed(1), 'Рейтинг'),
        ),
        StreamBuilder<int>(
          stream: reviewsCountStream,
          builder: (_, s) =>
              _stat(context, (s.data ?? 0).toString(), 'Отзывы'),
        ),
        StreamBuilder<int>(
          stream: listingsStream,
          builder: (_, s) =>
              _stat(context, (s.data ?? 0).toString(), 'Объявления'),
        ),
        _stat(context, followers, 'Подписчики'),
      ],
    );
  }
}