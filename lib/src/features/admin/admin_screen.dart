import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:chestore2/src/features/admin/admin_reports_screen.dart';
import 'admin_support_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Дашборд'),
            Tab(text: 'Модерация'),
            Tab(text: 'Поддержка'),
            Tab(text: 'Жалобы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _DashboardTab(),
          _ModerationTab(),
          AdminSupportTab(),
          AdminReportsScreen(),
        ],
      ),
    );
  }
}

// ----------------
// 0) ДАШБОРД
// ----------------
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  Future<int> _count(
    String table, {
    Map<String, dynamic>? eqFilters,
  }) async {
    final client = Supabase.instance.client;

    try {
      // максимально совместимый вариант: просто вытягиваем id и считаем длину
      // (не идеально по скорости, но точно без ошибок компиляции)
      var q = client.from(table).select('id');

      if (eqFilters != null) {
        for (final e in eqFilters.entries) {
          q = q.eq(e.key, e.value);
        }
      }

      final res = await q;
      return (res as List).length;
    } catch (e) {
      debugPrint('Count error [$table]: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        _count('users'),
        _count('listings'),
        _count('listings', eqFilters: {'status': 'pending'}),
        _count('support_tickets'),
        _count('reports', eqFilters: {'status': 'open'}),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!;
        final users = data[0];
        final listings = data[1];
        final pending = data[2];
        final tickets = data[3];
        final reports = data[4];

        Widget card(String title, String value, IconData icon) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            card('Пользователей', '$users', Icons.people),
            card('Объявлений всего', '$listings', Icons.list_alt),
            card('На модерации', '$pending', Icons.shield),
            card('Тикетов поддержки', '$tickets', Icons.support_agent),
            card('Жалоб (open)', '$reports', Icons.report),
          ],
        );
      },
    );
  }
}

// ----------------
// 1) МОДЕРАЦИЯ
// ----------------
class _ModerationTab extends StatelessWidget {
  const _ModerationTab();

  Stream<List<Map<String, dynamic>>> _getPendingListings() {
    return Supabase.instance.client
        .from('listings')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getPendingListings(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Ошибка: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!;
        if (docs.isEmpty) {
          return const Center(child: Text('Нет объявлений на модерации'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final data = docs[i];
            final id = (data['id'] ?? '').toString();

            final title = (data['title'] ?? '').toString();
            final price = (data['price'] ?? 0).toString();
            final city = (data['city'] ?? '').toString();
            final category = (data['category'] ?? '').toString();

            final raw = data['photo_urls'] ?? [];
            final photos = (raw is List)
                ? raw.map((e) => e.toString()).toList()
                : <String>[];

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminListingReviewScreen(
                      listingId: id,
                      listingData: data,
                    ),
                  ),
                );
              },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 64,
                          height: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: photos.isNotEmpty
                              ? Image.network(photos.first, fit: BoxFit.cover)
                              : const Icon(Icons.photo),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text('Цена: $price • $city'),
                            const SizedBox(height: 4),
                            Text(
                              'Категория: $category',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.outline),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Нажми, чтобы открыть и проверить полностью →',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminListingReviewScreen extends StatefulWidget {
  final String listingId;
  final Map<String, dynamic> listingData;

  const AdminListingReviewScreen({
    super.key,
    required this.listingId,
    required this.listingData,
  });

  @override
  State<AdminListingReviewScreen> createState() =>
      _AdminListingReviewScreenState();
}

class _AdminListingReviewScreenState extends State<AdminListingReviewScreen> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.from('listings').update({
        'status': 'approved',
        'rejection_reason': null,
      }).eq('id', widget.listingId);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Ошибка одобрения: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _askReason();
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.from('listings').update({
        'status': 'rejected',
        'rejection_reason': reason,
      }).eq('id', widget.listingId);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Ошибка отклонения: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason() async {
    final c = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Причина отклонения'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            hintText: 'Например: запрещённый товар / мат / спам / фейк',
            border: OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Ок'),
          ),
        ],
      ),
    );

    final t = (res ?? '').trim();
    if (t.isEmpty) return null;
    return t;
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: const Text('Это действие нельзя отменить.'),
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
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client
          .from('listings')
          .delete()
          .eq('id', widget.listingId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Ошибка удаления: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.listingData;

    final title = (d['title'] ?? '').toString();
    final price = (d['price'] ?? 0).toString();
    final city = (d['city'] ?? '').toString();
    final category = (d['category'] ?? '').toString();
    final desc = (d['description'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final ownerId = (d['owner_id'] ?? '').toString();

    final raw = d['photo_urls'] ?? [];
    final images =
        (raw is List) ? raw.map((e) => e.toString()).toList() : <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Проверка объявления')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(images[i], width: 300, fit: BoxFit.cover),
                ),
              ),
            )
          else
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: const Icon(Icons.photo, size: 44),
            ),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text('Цена: $price • Город: $city • Категория: $category'),
          const SizedBox(height: 10),
          Text(desc.isEmpty ? 'Описание отсутствует' : desc),
          const SizedBox(height: 10),
          Text('Телефон: $phone'),
          const SizedBox(height: 8),
          Text('owner_id: $ownerId',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _approve,
                  child: Text(_busy ? '...' : 'Одобрить ✅'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _busy ? null : _reject,
                  child: Text(_busy ? '...' : 'Отклонить ❌'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            label: const Text('Удалить полностью'),
          ),
        ],
      ),
    );
  }
}