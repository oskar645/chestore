import 'package:chestore2/src/features/listings/listing_detail_screen.dart';
import 'package:chestore2/src/services/reports_service.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('ru', timeago.RuMessages());

    final reports = context.read<ReportsService>();
    final me = context.read<AuthService>().currentUser!;

    Future<String?> askAdminComment(BuildContext ctx, String title) async {
      final c = TextEditingController();
      final res = await showDialog<String?>(
        context: ctx,
        builder: (dctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              hintText: 'Комментарий (необязательно)',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, null),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dctx, c.text.trim()),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      final t = (res ?? '').trim();
      return t.isEmpty ? null : t;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Жалобы')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: reports.streamOpenReports(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Ошибка: ${snap.error}'));
          }

          final docs = snap.data ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Жалоб пока нет'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final x = docs[i];
              final reportId = x['id'].toString();
              final listingId = (x['listing_id'] ?? '').toString();
              final ownerUid = (x['listing_owner_id'] ?? '').toString();
              final reporterId = (x['reporter_id'] ?? '').toString();
              final reason = (x['reason'] ?? '').toString();
              final comment = (x['comment'] ?? '').toString();

              final createdRaw = x['created_at'];
              DateTime? createdAt;
              if (createdRaw is DateTime) createdAt = createdRaw;
              if (createdRaw is String) createdAt = DateTime.tryParse(createdRaw);

              Future<void> doDecision({
                required String decision,
                required bool deleteListing,
                required String notifyText,
              }) async {
                try {
                  final adminComment = await askAdminComment(
                    context,
                    'Комментарий админа (по желанию)',
                  );

                  if (deleteListing && listingId.isNotEmpty) {
                    await reports.deleteListingById(listingId);
                  }

                  await reports.closeReportDecision(
                    reportId: reportId,
                    adminUid: me.uid,
                    decision: decision,
                    adminComment: adminComment,
                  );

                  String? notifyError;
                  if (ownerUid.isNotEmpty) {
                    try {
                      await reports.notifyOwnerViaSupport(
                        ownerUid: ownerUid,
                        ownerName: 'Пользователь',
                        messageFromAdmin: notifyText +
                            (adminComment == null
                                ? ''
                                : '\n\nКомментарий: $adminComment'),
                      );
                    } catch (e) {
                      notifyError = e.toString();
                    }
                  }

                  if (!context.mounted) return;
                  if (notifyError == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Готово')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Жалоба закрыта, но не удалось отправить сообщение: $notifyError',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      createdAt == null
                          ? 'Время: ...'
                          : 'Время: ${timeago.format(createdAt, locale: 'ru')}',
                    ),
                    const SizedBox(height: 8),
                    Text('Объявление: $listingId'),
                    Text('Владелец: $ownerUid'),
                    Text('Кто пожаловался: $reporterId'),
                    if (comment.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Комментарий: $comment'),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: listingId.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ListingDetailScreen(
                                        listingId: listingId,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Открыть объявление'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => doDecision(
                            decision: 'no_violation',
                            deleteListing: false,
                            notifyText:
                                'Мы проверили объявление. Нарушений не обнаружено.',
                          ),
                          child: const Text('Нарушений нет'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => doDecision(
                            decision: 'warned',
                            deleteListing: false,
                            notifyText:
                                'По объявлению вынесено предупреждение. Исправьте, пожалуйста, нарушения.',
                          ),
                          child: const Text('Предупредить'),
                        ),
                        FilledButton(
                          onPressed: listingId.isEmpty
                              ? null
                              : () => doDecision(
                                    decision: 'removed',
                                    deleteListing: true,
                                    notifyText:
                                        'Объявление удалено из-за нарушения правил.',
                                  ),
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
