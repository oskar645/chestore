import 'package:chestore2/src/features/listings/listing_detail_screen.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/reports_service.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Жалобы')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: reports.streamOpenReports(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!;
          if (docs.isEmpty) {
            return const Center(child: Text('Жалоб пока нет'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final x = docs[i];

              final listingId = (x['listing_id'] ?? '').toString();
              final listingOwnerId =
                  (x['listing_owner_id'] ?? '').toString();
              final reporterId = (x['reporter_id'] ?? '').toString();
              final reason = (x['reason'] ?? '').toString();
              final comment = (x['comment'] ?? '').toString();

              final createdRaw = x['created_at'];
              DateTime? createdAt;
              if (createdRaw is DateTime) createdAt = createdRaw;
              if (createdRaw is String) {
                createdAt = DateTime.tryParse(createdRaw);
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
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
                    Text('Владелец: $listingOwnerId'),
                    Text('Кто пожаловался: $reporterId'),

                    if (comment.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Комментарий: $comment'),
                    ],

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: listingId.isEmpty
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ListingDetailScreen(
                                                listingId: listingId),
                                      ),
                                    );
                                  },
                            child: const Text('Открыть объявление'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await reports.closeReport(
                                reportId: x['id'].toString(),
                                adminUid: me.uid,
                                result: 'closed',
                              );

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Жалоба закрыта')),
                              );
                            },
                            child: const Text('Закрыть'),
                          ),
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