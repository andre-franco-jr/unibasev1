import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class FinanceiroTab extends StatelessWidget {
  const FinanceiroTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF001f2e),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF003a4d),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.25)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.paid_outlined, color: AppColors.accent, size: 48),
              SizedBox(height: 16),
              Text('Financeiro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  )),
              SizedBox(height: 6),
              Text('Em breve',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
