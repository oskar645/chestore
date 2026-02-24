import 'package:chestore2/src/features/favorites/favorites_screen.dart';
import 'package:chestore2/src/features/home/home_screen.dart';
import 'package:chestore2/src/features/inbox/inbox_screen.dart';
import 'package:chestore2/src/features/listings/my_listings_screen.dart';
import 'package:chestore2/src/features/profile/profile_screen.dart';
import 'package:chestore2/src/services/auth_service.dart';
import 'package:chestore2/src/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _i = 0;

  final _pages = const [
    HomeScreen(), // Поиск
    FavoritesScreen(), // Избранное
    MyListingsScreen(), // Объявления
    InboxScreen(), // Сообщения
    ProfileScreen(), // Профиль
  ];

// ✅ цвета вкладок
  static const _inactive = Color(0xFF8E95A3);

  static const _search = Colors.blue;
  static const _fav = Colors.red;
  static const _listings = Colors.blue;
  static const _msgs = Colors.blue;
  static const _profile = Color.fromARGB(221, 175, 162, 23);

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    final uid = auth.currentUser!.uid;

    return Scaffold(
      body: _pages[_i],
      bottomNavigationBar: StreamBuilder<int>(
        stream: chat.streamUnreadTotal(uid),
        builder: (context, snap) {
          final unread = snap.data ?? 0;

// иконка сообщений с бейджем
          Widget msgIcon(Color color) {
            final icon = Icon(Icons.chat_bubble_outline, color: color);
            if (unread <= 0) return icon;

            return Badge(
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: icon,
            );
          }

          return SafeArea(
            top: false,
            child: NavigationBar(
              selectedIndex: _i,
              onDestinationSelected: (v) => setState(() => _i = v),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.search, color: _inactive),
                  selectedIcon: Icon(Icons.search, color: _search),
                  label: 'Поиск',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.favorite_border, color: _inactive),
                  selectedIcon: Icon(Icons.favorite, color: _fav),
                  label: 'Избранное',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.list_alt, color: _inactive),
                  selectedIcon: Icon(Icons.list_alt, color: _listings),
                  label: 'Объявления',
                ),
                NavigationDestination(
                  icon: msgIcon(_inactive),
                  selectedIcon: msgIcon(_msgs),
                  label: 'Сообщения',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline, color: _inactive),
                  selectedIcon: Icon(Icons.person, color: _profile),
                  label: 'Профиль',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
