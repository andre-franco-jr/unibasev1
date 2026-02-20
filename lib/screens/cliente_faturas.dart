import 'package:flutter/material.dart';
import 'cliente_contas.dart';

const _bgDark = Color(0xFF001f2e);

class ClienteFaturasTab extends StatelessWidget {
  const ClienteFaturasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: const SafeArea(
        child: ClienteContasTab(),
      ),
    );
  }
}