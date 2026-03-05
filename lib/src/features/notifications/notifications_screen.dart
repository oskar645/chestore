import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    timeago.setLocaleMessages('ru', timeago.RuMessages());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final me = context.read<AuthService>().currentUser;
      if (me == null) return;
      await context.read<NotificationsService>().markAllSeen(me.uid);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthService>().currentUser!;
    final notifications = context.read<NotificationsService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          IconButton(
            tooltip: 'Отметить все как прочитанные',
            onPressed: () async {
              await notifications.markAllSeen(me.uid);
            },
            icon: const Icon(Icons.done_all),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Общие'),
            Tab(text: 'Личные'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: notifications.streamGlobal(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Ошибка: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const Center(child: Text('Пока нет общих уведомлений'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = items[i];
                  final title = (n['title'] ?? '').toString();
                  final body = (n['body'] ?? '').toString();
                  final createdRaw = n['created_at'];
                  DateTime? created;
                  if (createdRaw is String) created = DateTime.tryParse(createdRaw);
                  if (createdRaw is DateTime) created = createdRaw;

                  return Card(
                    child: ListTile(
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(body),
                          if (created != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              timeago.format(created, locale: 'ru'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: notifications.streamPersonal(me.uid),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Ошибка: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const Center(child: Text('Личных уведомлений пока нет'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = items[i];
                  final id = (n['id'] ?? '').toString();
                  final title = (n['title'] ?? '').toString();
                  final body = (n['body'] ?? '').toString();
                  final isRead = n['is_read'] == true;
                  final createdRaw = n['created_at'];
                  DateTime? created;
                  if (createdRaw is String) created = DateTime.tryParse(createdRaw);
                  if (createdRaw is DateTime) created = createdRaw;

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isRead ? Icons.mark_email_read : Icons.mark_email_unread,
                        color: isRead
                            ? Theme.of(context).colorScheme.outline
                            : Colors.red,
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isRead
                              ? Theme.of(context).colorScheme.outline
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(body),
                          if (created != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              timeago.format(created, locale: 'ru'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () async {
                        if (!isRead) {
                          await notifications.markPersonalReadById(id);
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
