import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../core/auth/auth_gate.dart';
import 'cliente_dashboard.dart';
import 'cliente_contas.dart';
import 'cliente_perfil.dart';

class ClientShellScreen extends StatefulWidget {
  const ClientShellScreen({super.key});

  @override
  State<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends State<ClientShellScreen> {
  int _index = 0;

  Key _dashboardKey = UniqueKey();
  Key _faturasKey = UniqueKey();
  Key _documentosKey = UniqueKey();

  Future<void> _refreshCurrentTab() async {
    setState(() {
      if (_index == 0) _dashboardKey = UniqueKey();
      if (_index == 1) _faturasKey = UniqueKey();
      if (_index == 2) _documentosKey = UniqueKey();
    });
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  Widget _navItem({
    required int i,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color accent,
  }) {
    final selected = _index == i;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 20,
                color: selected ? accent : Colors.white38,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? accent : Colors.white38,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: selected ? 16 : 0, // abre do centro para as extremidades
                height: 2,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const investidorBgDark = Color(0xFF001f2e);
    const investidorAccent = Color(0xFFEAC248);

    final pages = [
      SafeArea(child: ClienteDashboardTab(key: _dashboardKey)),
      SafeArea(child: ClienteFaturasTab(key: _faturasKey)),
      SafeArea(child: ClientePerfilTab(key: _documentosKey)),
    ];

    return Scaffold(
      backgroundColor: investidorBgDark,
      appBar: AppBar(
        backgroundColor: investidorBgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: investidorBgDark,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: investidorAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_outline,
                color: investidorAccent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Área do Cliente',
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
          child: Container(
            height: 1,
            color: investidorAccent.withOpacity(0.9),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refreshCurrentTab,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: investidorBgDark,
          border: Border(
            top: BorderSide(
              color: investidorAccent.withOpacity(0.25),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _navItem(
                  i: 0,
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'Dashboard',
                  accent: investidorAccent,
                ),
                _navItem(
                  i: 1,
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: 'Faturas',
                  accent: investidorAccent,
                ),
                _navItem(
                  i: 2,
                  icon: Icons.folder_outlined,
                  selectedIcon: Icons.folder,
                  label: 'Documentos',
                  accent: investidorAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
