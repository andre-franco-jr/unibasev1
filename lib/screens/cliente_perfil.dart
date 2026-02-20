import 'package:flutter/material.dart';
import 'clientes_documentos.dart';

const _bgDark = Color(0xFF001f2e);

class ClientePerfilTab extends StatelessWidget {
  const ClientePerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: const SafeArea(
        child: ClienteDocumentosTab(),
      ),
    );
  }
}
