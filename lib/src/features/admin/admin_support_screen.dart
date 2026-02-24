import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chestore2/src/services/support_service.dart';

class AdminSupportTab extends StatelessWidget {
  const AdminSupportTab({super.key});

  @override
  Widget build(BuildContext context) {
    final support = context.read<SupportService>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: support.streamTicketsForAdmin(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!;
        if (docs.isEmpty) {
          return const Center(child: Text('Пока нет обращений'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final data = docs[i];

            final uid = (data['uid'] ?? '').toString();
            final name =
                (data['name'] ?? 'Пользователь').toString();
            final last =
                (data['last_message'] ?? '').toString();

            final unreadNum =
                (data['unread_for_admin'] == true) ? 1 : 0;

            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              leading: Icon(
                Icons.support_agent,
                color: unreadNum > 0
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(name),
              subtitle: Text(
                last.isEmpty ? 'Нет сообщений' : last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminTicketScreen(
                      ticketId: data['id'].toString(),
                      titleName: name,
                      userUid: uid,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class AdminTicketScreen extends StatefulWidget {
  final String ticketId;
  final String titleName;
  final String userUid;

  const AdminTicketScreen({
    super.key,
    required this.ticketId,
    required this.titleName,
    required this.userUid,
  });

  @override
  State<AdminTicketScreen> createState() =>
      _AdminTicketScreenState();
}

class _AdminTicketScreenState
    extends State<AdminTicketScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final support = context.read<SupportService>();
      await support.markReadByAdmin(widget.ticketId);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final support = context.read<SupportService>();

    setState(() => _sending = true);
    try {
      await support.adminReply(
        ticketId: widget.ticketId,
        text: t,
      );
      _text.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final support = context.read<SupportService>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.titleName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: support.streamMessages(widget.ticketId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final items = snap.data!;
                if (items.isEmpty) {
                  return const Center(
                      child: Text('Нет сообщений'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final sender =
                        (m['sender'] ?? '').toString();
                    final text =
                        (m['text'] ?? '').toString();

                    final isAdmin = sender == 'admin';

                    return Align(
                      alignment: isAdmin
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: Text(text),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    decoration: const InputDecoration(
                      hintText: 'Ответ...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed:
                      _sending ? null : () => _send(_text.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}