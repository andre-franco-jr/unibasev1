import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';
import 'login_screen.dart';
import 'usinas_tab.dart';
import 'dashboard_tab.dart';
import 'documentos_tab.dart';
import 'dre_tab.dart';
import 'financeiro_tab.dart';

// ═══════════════════════════════════════════════
// TELA PRINCIPAL COM ABAS
// ═══════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<State<DashboardTab>> _dashboardKey =
      GlobalKey<State<DashboardTab>>();
  final GlobalKey<UsinasTabState> _usinasKey = GlobalKey<UsinasTabState>();
  final GlobalKey<State<DocumentosTab>> _documentosKey =
      GlobalKey<State<DocumentosTab>>();

  Future<void> _handleRefresh() async {
    if (_currentIndex == 0) {
      await (_dashboardKey.currentState as dynamic)?.refresh();
    } else if (_currentIndex == 1) {
      await _usinasKey.currentState?.refresh();
    } else if (_currentIndex == 2) {
      await (_documentosKey.currentState as dynamic)?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardTab(key: _dashboardKey),
      UsinasTab(key: _usinasKey),
      DocumentosTab(key: _documentosKey),
      const FinanceiroTab(),
      const DRETab(),
    ];

    const navItems = [
      _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
      ),
      _NavItem(
        icon: Icons.solar_power_outlined,
        activeIcon: Icons.solar_power,
        label: 'Usinas',
      ),
      _NavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        label: 'Documentos',
      ),
      _NavItem(
        icon: Icons.paid_outlined,
        activeIcon: Icons.paid,
        label: 'Financeiro',
      ),
      _NavItem(
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics,
        label: 'DRE',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF001f2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001f2e),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.trending_up,
                  color: AppColors.accent, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Painel do Investidor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(height: 1, color: AppColors.accent.withOpacity(0.9)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            onPressed: _handleRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
            onPressed: () async {
              await ApiService.logout();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF001f2e),
          border: Border(
            top:
                BorderSide(color: AppColors.accent.withOpacity(0.25), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final selected = _currentIndex == index;
                final color = selected ? AppColors.accent : Colors.white38;
                final xOffset = index == 3
                    ? 6.0
                    : index == 4
                        ? -3.0
                        : 0.0;

                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = index),
                    child: Transform.translate(
                      offset: Offset(xOffset, 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 5,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 20,
                              color: color,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              width: selected ? 16 : 0,
                              height: 2,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
