import 'package:flutter/material.dart';

/// Paleta de cores da aplicação Unienergy
/// Fornecido conforme captura de tela datada de 12/02/2026
class AppColors {
  // Cores principais
  static const Color primary = Color(0xFF148bad); // Azul turquesa
  static const Color primaryDark = Color(0xFF0c658f); // Azul escuro
  static const Color primaryDarker = Color(0xFF0a5672); // Azul mais escuro
  static const Color primaryDarkest = Color(0xFF003e52); // Azul muito escuro

  static const Color accent = Color(0xFFeac248); // Amarelo

  // Cores secundárias
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFC107);

  // Cores neutras
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;

  // Gradientes
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryDarker,
      primaryDarkest,
    ],
  );

  // Gradient para tela de login (cor sólida)
  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryDarkest,
      primaryDarkest,
    ],
  );

  static const Color background = Color(0xFFF7F9FC);
}
