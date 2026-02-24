import 'package:chestore2/src/features/inbox/chat_screen.dart';
import 'package:chestore2/src/models/chat.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('ru', timeago.RuMessages());
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    final uid = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: StreamBuilder<List<Chat>>(
        stream: chat.streamMyChats(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;
          if (items.isEmpty) return const Center(child: Text('Нет чатов'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = items[i];

              final otherEmail = c.memberEmails.entries.firstWhere(
                (e) => e.key != uid,
                orElse: () => MapEntry(uid, 'Пользователь'),
              ).value;

              final unread = c.unreadFor(uid);
              final isUnread = unread > 0;

              return Dismissible(
                key: ValueKey(c.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Удалить переписку?'),
                          content: const Text('Чат будет удалён из списка.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Удалить'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) async {
                  try {
                    await chat.deleteChat(chatId: c.id, uid: uid);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка удаления: $e')),
                    );
                  }
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

                  onTap: () async {
                    // ✅ СНАЧАЛА сброс unread
                    await chat.markChatRead(chatId: c.id, uid: uid);

                    if (!context.mounted) return;

                    // ✅ потом открыть чат
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ChatScreen(chatId: c.id)),
                    );
                  },

                  title: Text(
                    otherEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),

                  subtitle: Text(
                    '${c.listingTitle}\n${c.lastMessage}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: isUnread
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),

                  isThreeLine: true,

                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeago.format(c.updatedAt, locale: 'ru'),
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                      if (isUnread) ...[
                        const SizedBox(height: 8),
                        Badge(
                          backgroundColor: Colors.red,
                          label: Text(unread > 99 ? '99+' : '$unread'),
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
    );
  }
}
