import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/reviews_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SellerReviewsScreen extends StatefulWidget {
  final String sellerId;
  final String sellerName;
  final String listingId;

  const SellerReviewsScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.listingId,
  });

  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final me = context.read<AuthService>().currentUser!;
      if (me.uid == widget.sellerId) {
        await context.read<ReviewsService>().resetNewReviewsCount(widget.sellerId);
      }
    });
  }

  Future<void> _openAddReview() async {
    final me = context.read<AuthService>().currentUser!;
    if (me.uid == widget.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя оставить отзыв самому себе')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddReviewSheet(
        sellerId: widget.sellerId,
        listingId: widget.listingId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviews = context.read<ReviewsService>();

    return Scaffold(
      appBar: AppBar(title: Text('Отзывы: ${widget.sellerName}')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: reviews.streamSellerReviews(widget.sellerId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              FilledButton.icon(
                onPressed: _openAddReview,
                icon: Icon(
                  Icons.rate_review_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: const Text('Оставить отзыв'),
              ),
              const SizedBox(height: 12),

              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Пока нет отзывов.\nБудь первым 🙂',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ),

              ...items.map((r) => _ReviewTile(
                    sellerId: widget.sellerId,
                    review: r,
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final String sellerId;
  final Map<String, dynamic> review;

  const _ReviewTile({required this.sellerId, required this.review});

  String _dateText(dynamic v) {
    DateTime? dt;
    if (v is DateTime) dt = v;
    if (v is String) dt = DateTime.tryParse(v);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthService>().currentUser!;
    final isSeller = me.uid == sellerId;

    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final text = (review['text'] ?? '').toString();
    final reviewerName = (review['reviewer_name'] ?? review['reviewerName'] ?? 'Пользователь').toString();
    final createdAt = _dateText(review['created_at'] ?? review['createdAt']);
    final replyText = (review['reply_text'] ?? review['replyText'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reviewerName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  createdAt,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              children: List.generate(5, (i) {
                final filled = i < rating;
                return Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: 16,
                  color: filled ? Colors.amber : Theme.of(context).colorScheme.outline,
                );
              }),
            ),

            const SizedBox(height: 8),
            Text(text),

            if (replyText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Text('Ответ продавца: $replyText'),
              ),
            ],

            if (isSeller) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  final res = await showDialog<String>(
                    context: context,
                    builder: (_) => _ReplyDialog(initial: replyText),
                  );
                  if (res == null || res.trim().isEmpty) return;

                  await context.read<ReviewsService>().replyToReview(
                        sellerId: sellerId,
                        reviewId: (review['id'] ?? '').toString(),
                        replyText: res,
                      );
                },
                icon: const Icon(Icons.reply),
                label: Text(replyText.isEmpty ? 'Ответить' : 'Изменить ответ'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddReviewSheet extends StatefulWidget {
  final String sellerId;
  final String listingId;
  const _AddReviewSheet({required this.sellerId, required this.listingId});

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  int _rating = 5;
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthService>().currentUser!;
    final name = (me.displayName?.trim().isNotEmpty ?? false)
        ? me.displayName!.trim()
        : (me.email ?? 'Пользователь');

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ваш отзыв', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),

          Row(
            children: List.generate(5, (i) {
              final idx = i + 1;
              final filled = idx <= _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = idx),
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? Colors.amber : Theme.of(context).colorScheme.outline,
                ),
              );
            }),
          ),

          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Напишите, как прошла сделка…',
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;

                      setState(() => _saving = true);
                      try {
                        await context.read<ReviewsService>().addReview(
                              sellerId: widget.sellerId,
                              reviewerId: me.uid,
                              reviewerName: name,
                              listingId: widget.listingId,
                              rating: _rating,
                              text: text,
                            );
                        if (context.mounted) Navigator.pop(context);
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(_saving ? 'Отправляем…' : 'Отправить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  final String initial;
  const _ReplyDialog({required this.initial});

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ответ продавца'),
      content: TextField(
        controller: _c,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Например: Спасибо за отзыв!'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: const Text('Сохранить')),
      ],
    );
  }
}