import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o serviço de API
  await ApiService.init();

  runApp(const UnienergyApp());
}

class UnienergyApp extends StatelessWidget {
  const UnienergyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unienergy Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Viga',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.white,
          titleTextStyle: TextStyle(
            fontFamily: 'Viga',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Viga'),
          displayMedium: TextStyle(fontFamily: 'Viga'),
          displaySmall: TextStyle(fontFamily: 'Viga'),
          headlineMedium: TextStyle(fontFamily: 'Viga'),
          headlineSmall: TextStyle(fontFamily: 'Viga'),
          titleLarge: TextStyle(fontFamily: 'Viga'),
          titleMedium: TextStyle(fontFamily: 'Viga'),
          titleSmall: TextStyle(fontFamily: 'Viga'),
          bodyLarge: TextStyle(fontFamily: 'Montserrat'),
          bodyMedium: TextStyle(fontFamily: 'Montserrat'),
          bodySmall: TextStyle(fontFamily: 'Montserrat'),
          labelLarge: TextStyle(fontFamily: 'Montserrat'),
          labelMedium: TextStyle(fontFamily: 'Montserrat'),
          labelSmall: TextStyle(fontFamily: 'Montserrat'),
        ),
      ),
      home: FutureBuilder<bool>(
        future: ApiService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final isLoggedIn = snapshot.data ?? false;

          if (!isLoggedIn) {
            return const LoginScreen();
          }

          // Se está logado, verifica a role
          return FutureBuilder<String?>(
            future: ApiService.getUserRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final role = roleSnapshot.data;

              // Redireciona baseado na role
              if (role == 'investor') {
                return const HomeScreen();
              } else {
                return const DashboardScreen();
              }
            },
          );
        },
      ),
    );
  }
}
