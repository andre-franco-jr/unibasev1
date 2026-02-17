import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';

class DocumentosTab extends StatefulWidget {
  const DocumentosTab({super.key});

  @override
  State<DocumentosTab> createState() => _DocumentosTabState();
}

class _DocumentosTabState extends State<DocumentosTab> {
  List<dynamic> _pastas = [];
  List<dynamic> _arquivos = [];
  String? _pastaSelecionada;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? pasta}) async {
    setState(() => _isLoading = true);
    try {
      final pRes = await ApiService.getDocumentosPastas();
      final aRes = await ApiService.getDocumentosArquivos(pasta: pasta);
      if (mounted) {
        setState(() {
          _pastas = pRes['pastas'] ?? [];
          _arquivos = aRes['arquivos'] ?? [];
          _pastaSelecionada = pasta;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  IconData _fileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart_outlined;
      case 'docx':
      case 'doc':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    return Container(
      color: const Color(0xFF001f2e),
      child: Column(
        children: [
          // ── HEADER FIXO ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.folder, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Meus Documentos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── CONTEÚDO SCROLLÁVEL ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Pastas
                if (_pastas.isNotEmpty) ...[
                  const Text('Pastas',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._pastas.map((p) => GestureDetector(
                        onTap: () => _load(pasta: p['pasta']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _pastaSelecionada == p['pasta']
                                ? AppColors.accent.withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: _pastaSelecionada == p['pasta']
                                ? Border.all(color: AppColors.accent)
                                : null,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_rounded,
                                  color: AppColors.accent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(p['pasta'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF004D66))),
                              ),
                              Text(
                                '${p['total_arquivos']} arq.',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF6b7280)),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Color(0xFF6b7280), size: 18),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],

                // Breadcrumb se dentro de pasta
                if (_pastaSelecionada != null)
                  GestureDetector(
                    onTap: () => _load(),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back,
                              color: Colors.white60, size: 16),
                          const SizedBox(width: 6),
                          Text(_pastaSelecionada!,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                // Arquivos
                if (_arquivos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.folder_open_outlined,
                            color: Colors.white24, size: 40),
                        SizedBox(height: 10),
                        Text('Nenhum arquivo encontrado',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 13)),
                      ],
                    ),
                  )
                else
                  ..._arquivos.map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF004D66).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                _fileIcon(a['extensao'] ?? ''),
                                color: const Color(0xFF004D66),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['titulo'] ?? a['file_name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF004D66),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    a['uploaded_at'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF6b7280)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.download_outlined,
                                  color: Color(0xFF004D66), size: 20),
                              onPressed: () {
                                // URL para download:
                                // ApiService.getDocumentoDownloadUrl(a['id'])
                              },
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
