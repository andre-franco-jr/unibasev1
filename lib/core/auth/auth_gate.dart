import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../screens/login_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/client_shell_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<_AuthState> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAuthState();
  }

  Future<_AuthState> _loadAuthState() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (!isLoggedIn) return _AuthState.loggedOut();

    final rawRole = (await ApiService.getUserRole()) ?? '';
    final role = rawRole.trim().toLowerCase();

    if (role == 'investor') return _AuthState.investor();
    if (role == 'client' || role == 'cliente') return _AuthState.client();
    return _AuthState.admin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthState>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final state = snapshot.data ?? _AuthState.loggedOut();

        switch (state.type) {
          case _AuthType.loggedOut:
            return const LoginScreen();
          case _AuthType.investor:
            return const HomeScreen();
          case _AuthType.client:
            return const ClientShellScreen();
          case _AuthType.admin:
            return const DashboardScreen();
        }
      },
    );
  }
}

enum _AuthType { loggedOut, investor, client, admin }

class _AuthState {
  final _AuthType type;
  const _AuthState(this.type);

  factory _AuthState.loggedOut() => const _AuthState(_AuthType.loggedOut);
  factory _AuthState.investor() => const _AuthState(_AuthType.investor);
  factory _AuthState.client() => const _AuthState(_AuthType.client);
  factory _AuthState.admin() => const _AuthState(_AuthType.admin);
}