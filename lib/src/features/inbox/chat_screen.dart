import 'dart:io';

import 'package:chestore2/src/models/message.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  bool _sending = false;

  @override
  void initState() {
    super.initState();

    // ✅ при открытии чата сбрасываем непрочитанные
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthService>();
      final chat = context.read<ChatService>();
      await chat.markChatRead(chatId: widget.chatId, uid: auth.currentUser!.uid);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;

    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();

    setState(() => _sending = true);
    try {
      await chat.sendMessage(
        chatId: widget.chatId,
        senderId: auth.currentUser!.uid,
        text: t,
      );
      _text.clear();

      // ✅ после отправки: я прочитал чат (0), чтобы badge не возвращался
      await chat.markChatRead(chatId: widget.chatId, uid: auth.currentUser!.uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ===== "+" КАК В AVITO =====
  void _openAttachMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Фото из галереи'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Камера'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickAndSendImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();

    final x = await _picker.pickImage(source: source, imageQuality: 80);
    if (x == null) return;

    setState(() => _sending = true);
    try {
      await chat.sendImage(
        chatId: widget.chatId,
        senderId: auth.currentUser!.uid,
        file: File(x.path),
      );

      // ✅ чтобы badge сразу пропал
      await chat.markChatRead(chatId: widget.chatId, uid: auth.currentUser!.uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    final uid = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Чат')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chat.streamMessages(widget.chatId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snap.data!;
                if (items.isEmpty) {
                  return const Center(child: Text('Напишите первое сообщение'));
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final mine = m.senderId == uid;

                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((m.imageUrl ?? '').isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  m.imageUrl!,
                                  width: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (m.text.isNotEmpty) ...[
                              if ((m.imageUrl ?? '').isNotEmpty) const SizedBox(height: 6),
                              Text(m.text),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _sending ? null : _openAttachMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(
                        hintText: 'Сообщение...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
