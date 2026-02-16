import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';
import 'login_screen.dart';
import 'usinas_tab.dart';
import 'dashboard_tab.dart';
import 'documentos_tab.dart';
import 'dre_tab.dart';

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
      const DRETab(),
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
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.solar_power_outlined),
              activeIcon: Icon(Icons.solar_power),
              label: 'Usinas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Documentos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'DRE',
            ),
          ],
        ),
      ),
    );
  }
}
