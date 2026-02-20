import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure fonts are available if needed directly, though AppTheme handles it
import 'theme/app_theme.dart';
import 'vault_page.dart';
import 'focus_page.dart';
import 'mind_page.dart';
import 'dashboard_page.dart';

// If you have pixelarticons, import them. For now using standard Icons but styled.
// import 'package:pixelarticons/pixelarticons.dart'; 

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  List<Widget> get _pages => [
    DashboardPage(onNavigate: (i) => setState(() => index = i)),
    const VaultPage(),
    const FocusPage(),
    const MindPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background color handled by theme, but we can enforce if needed
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        title: Text('UniSync', style: AppTextStyles.pixelHeader),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
           Padding(
             padding: const EdgeInsets.only(right: 8.0),
             child: IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout, color: AppColors.text),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Leaving so soon?', style: AppTextStyles.pixelHeader),
                    content: Text('Are you sure you want to log out?', style: AppTextStyles.pixelBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Stay', style: AppTextStyles.pixelButton),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Logout', style: AppTextStyles.pixelButton.copyWith(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await Supabase.instance.client.auth.signOut();
                }
              },
             ),
           ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            color: AppColors.text,
            height: 2,
          ),
        ),
      ),
      body: _pages[index],
      bottomNavigationBar: _PixelBottomBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomBarItem(icon: Icons.dashboard_outlined, label: 'Dash'),
          BottomBarItem(icon: Icons.account_balance_wallet_outlined, label: 'Vault'),
          BottomBarItem(icon: Icons.timer_outlined, label: 'Focus'),
          BottomBarItem(icon: Icons.menu_book_outlined, label: 'Mind'),
        ],
      ),
    );
  }
}

class BottomBarItem {
  final IconData icon;
  final String label;
  const BottomBarItem({required this.icon, required this.label});
}

class _PixelBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomBarItem> items;

  const _PixelBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.text, width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
            final isSelected = i == currentIndex;
            return GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: isSelected ? BoxDecoration(
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.text, width: 2),
                   boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i].icon, 
                      color: AppColors.text,
                      size: 24,
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                       Text(
                        items[i].label,
                        style: AppTextStyles.pixelBody.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                       ),
                    ]
                  ],
                ),
              ),
            );
        }),
      ),
    );
  }
}
