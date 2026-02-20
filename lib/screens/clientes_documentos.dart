import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

const _bgDark = Color(0xFF001f2e);
const _bgMid  = Color(0xFF003a4d);
const _bgCard = Color(0xFF004D66);
const _accent = Color(0xFFEAC248);

class ClienteDocumentosTab extends StatefulWidget {
  const ClienteDocumentosTab({super.key});

  @override
  State<ClienteDocumentosTab> createState() => ClienteDocumentosTabState();
}

class ClienteDocumentosTabState extends State<ClienteDocumentosTab> {
  List<Map<String, dynamic>> _pastas    = [];
  List<Map<String, dynamic>> _arquivos  = [];
  String? _pastaSelecionada;
  bool _loadingPastas   = true;
  bool _loadingArquivos = false;

  @override
  void initState() {
    super.initState();
    _loadPastas();
  }

  Future<void> refresh() => _loadPastas();

  Future<void> _loadPastas() async {
    setState(() => _loadingPastas = true);
    try {
      final r = await ApiService.clienteDocumentosPastas();
      if (!mounted) return;
      setState(() {
        _pastas       = List<Map<String, dynamic>>.from(r);
        _loadingPastas = false;
      });
      // Carregar arquivos sem pasta (raiz)
      _loadArquivos(null);
    } catch (_) {
      if (mounted) setState(() => _loadingPastas = false);
    }
  }

  Future<void> _loadArquivos(String? pasta) async {
    setState(() {
      _pastaSelecionada = pasta;
      _loadingArquivos  = true;
      _arquivos         = [];
    });
    try {
      final r = await ApiService.clienteDocumentosArquivos(pasta: pasta);
      if (!mounted) return;
      setState(() {
        _arquivos        = List<Map<String, dynamic>>.from(r);
        _loadingArquivos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingArquivos = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: _loadingPastas
          ? const Center(
              child: CircularProgressIndicator(color: _accent))
          : Row(
              children: [
                // Painel lateral de pastas (sempre visível)
                _buildPainelPastas(),
                // Área principal de arquivos
                Expanded(child: _buildAreaArquivos()),
              ],
            ),
    );
  }

  // ── PAINEL DE PASTAS ─────────────────────────────────────────────────────────

  Widget _buildPainelPastas() {
    return Container(
      width: 130,
      color: _bgMid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _accent, width: 2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.folder_outlined, color: _accent, size: 14),
                SizedBox(width: 6),
                Text('Pastas',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                _pastaItem(null, 'Todos', Icons.folder_special_outlined),
                ..._pastas.map((p) => _pastaItem(
                    p['pasta'] as String?,
                    p['pasta'] ?? 'Sem nome',
                    Icons.folder_outlined,
                    total: p['total_arquivos'] as int? ?? 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastaItem(
    String? pasta,
    String label,
    IconData icon, {
    int total = 0,
  }) {
    final active = _pastaSelecionada == pasta;
    return GestureDetector(
      onTap: () => _loadArquivos(pasta),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? _accent.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? _accent : Colors.white54,
                size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? _accent : Colors.white70,
                  fontWeight: active
                      ? FontWeight.w700 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ÁREA DE ARQUIVOS ─────────────────────────────────────────────────────────

  Widget _buildAreaArquivos() {
    if (_loadingArquivos) {
      return const Center(
          child: CircularProgressIndicator(color: _accent));
    }

    if (_arquivos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined,
                color: Colors.white24, size: 48),
            SizedBox(height: 10),
            Text('Nenhum arquivo nesta pasta',
                style: TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header da área
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: _bgMid,
            border: const Border(
              bottom: BorderSide(color: _accent, width: 2),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined,
                  color: _accent, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pastaSelecionada ?? 'Todos os arquivos',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${_arquivos.length} arquivo${_arquivos.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFFb0c4ce))),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
            itemCount: _arquivos.length,
            itemBuilder: (_, i) => _buildArquivoCard(_arquivos[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildArquivoCard(Map<String, dynamic> arq) {
    final ext  = (arq['extensao'] ?? 'file').toString().toLowerCase();
    final icon = _extIcon(ext);
    final color = _extColor(ext);

    return GestureDetector(
      onTap: () => _downloadArquivo(arq),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _bgMid,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accent.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            // Ícone de extensão
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arq['titulo'] ?? arq['file_name'] ?? '—',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        ext.toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            color: color,
                            fontWeight: FontWeight.w700),
                      ),
                      if (arq['file_size'] != null) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 9)),
                        Text(
                          _fmtSize(arq['file_size']),
                          style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFFb0c4ce)),
                        ),
                      ],
                      if (arq['uploaded_at'] != null) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 9)),
                        Text(
                          arq['uploaded_at'].toString(),
                          style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFFb0c4ce)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Botão download
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.download_outlined,
                  color: _accent, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadArquivo(Map<String, dynamic> arq) async {
    try {
      final id  = arq['id'];
      final url = 'https://unienergyportal.com'
          '/api/mobile/cliente/documentos/download/$id';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (_) {}
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  IconData _extIcon(String ext) {
    switch (ext) {
      case 'pdf':  return Icons.picture_as_pdf_outlined;
      case 'xlsx':
      case 'xls':  return Icons.table_chart_outlined;
      case 'docx':
      case 'doc':  return Icons.description_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg': return Icons.image_outlined;
      default:     return Icons.insert_drive_file_outlined;
    }
  }

  Color _extColor(String ext) {
    switch (ext) {
      case 'pdf':  return const Color(0xFFef4444);
      case 'xlsx':
      case 'xls':  return const Color(0xFF10b981);
      case 'docx':
      case 'doc':  return const Color(0xFF3b82f6);
      case 'png':
      case 'jpg':
      case 'jpeg': return const Color(0xFF8b5cf6);
      default:     return const Color(0xFFb0c4ce);
    }
  }

  String _fmtSize(dynamic bytes) {
    final b = int.tryParse(bytes.toString()) ?? 0;
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }
}