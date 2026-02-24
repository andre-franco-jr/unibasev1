import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

const _bgDark = Color(0xFF001f2e);
const _bgMid = Color(0xFF003a4d);
const _bgCard = Color(0xFF004D66);
const _accent = Color(0xFFEAC248);

class ClienteDocumentosTab extends StatefulWidget {
  const ClienteDocumentosTab({super.key});

  @override
  State<ClienteDocumentosTab> createState() => ClienteDocumentosTabState();
}

class ClienteDocumentosTabState extends State<ClienteDocumentosTab> {
  List<Map<String, dynamic>> _pastas = [];
  Map<String, List<Map<String, dynamic>>> _arquivosPorPasta = {};
  final Set<String> _pastasExpandidas = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDocumentos();
  }

  Future<void> refresh() => _loadDocumentos();

  Future<void> _loadDocumentos() async {
    setState(() => _loading = true);
    try {
      // Carregar pastas
      final pastas = await ApiService.clienteDocumentosPastas();
      if (!mounted) return;

      // Carregar arquivos de cada pasta
      final Map<String, List<Map<String, dynamic>>> arquivosPorPasta = {};

      // Carregar arquivos sem pasta (raiz)
      final arquivosRaiz =
          await ApiService.clienteDocumentosArquivos(pasta: null);
      if (arquivosRaiz.isNotEmpty) {
        // Filtrar arquivos .folder
        final arquivosFiltrados = arquivosRaiz
            .where((arq) =>
                arq['file_name'] != '.folder' &&
                arq['extensao']?.toString().toLowerCase() != 'folder')
            .toList();
        if (arquivosFiltrados.isNotEmpty) {
          arquivosPorPasta['_raiz'] =
              List<Map<String, dynamic>>.from(arquivosFiltrados);
        }
      }

      // Carregar arquivos de cada pasta
      for (var pasta in pastas) {
        final nomePasta = pasta['pasta'] as String?;
        if (nomePasta != null && nomePasta.isNotEmpty) {
          final arquivos =
              await ApiService.clienteDocumentosArquivos(pasta: nomePasta);
          if (arquivos.isNotEmpty) {
            // Filtrar arquivos .folder
            final arquivosFiltrados = arquivos
                .where((arq) =>
                    arq['file_name'] != '.folder' &&
                    arq['extensao']?.toString().toLowerCase() != 'folder')
                .toList();
            if (arquivosFiltrados.isNotEmpty) {
              arquivosPorPasta[nomePasta] =
                  List<Map<String, dynamic>>.from(arquivosFiltrados);
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _pastas = List<Map<String, dynamic>>.from(pastas);
        _arquivosPorPasta = arquivosPorPasta;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _buildCascataDocumentos(),
    );
  }

  // ── VISUALIZAÇÃO EM CASCATA ─────────────────────────────────────────────────

  Widget _buildCascataDocumentos() {
    if (_arquivosPorPasta.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 10),
            Text('Nenhum documento disponível',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Documentos na raiz (se existirem)
        if (_arquivosPorPasta.containsKey('_raiz'))
          _buildSecaoPasta(
            'Documentos Gerais',
            _arquivosPorPasta['_raiz']!,
            Icons.description_outlined,
          ),

        // Documentos por pasta
        ..._arquivosPorPasta.entries
            .where((entry) => entry.key != '_raiz')
            .map((entry) => _buildSecaoPasta(
                  entry.key,
                  entry.value,
                  Icons.folder_outlined,
                )),
      ],
    );
  }

  Widget _buildSecaoPasta(
      String nomePasta, List<Map<String, dynamic>> arquivos, IconData icon) {
    final isExpanded = _pastasExpandidas.contains(nomePasta);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _bgMid.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da pasta (clicável para expandir/colapsar)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _pastasExpandidas.remove(nomePasta);
                } else {
                  _pastasExpandidas.add(nomePasta);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _bgMid,
                borderRadius: BorderRadius.circular(12),
                border: isExpanded
                    ? const Border(
                        bottom: BorderSide(color: _accent, width: 2),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(icon, color: _accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nomePasta,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${arquivos.length} ${arquivos.length == 1 ? 'arquivo' : 'arquivos'}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _accent,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Lista de arquivos (visível apenas quando expandido)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: arquivos
                    .map((arq) => _buildArquivoCard(arq, nomePasta))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArquivoCard(Map<String, dynamic> arq, String nomePasta) {
    final ext = (arq['extensao'] ?? 'file').toString().toLowerCase();
    final icon = _extIcon(ext);
    final color = _extColor(ext);

    return GestureDetector(
      onTap: () => _downloadArquivo(arq, nomePasta),
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
                            style:
                                TextStyle(color: Colors.white24, fontSize: 9)),
                        Text(
                          _fmtSize(arq['file_size']),
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFFb0c4ce)),
                        ),
                      ],
                      if (arq['uploaded_at'] != null) ...[
                        const Text(' · ',
                            style:
                                TextStyle(color: Colors.white24, fontSize: 9)),
                        Text(
                          arq['uploaded_at'].toString(),
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFFb0c4ce)),
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
              child:
                  const Icon(Icons.download_outlined, color: _accent, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadArquivo(
      Map<String, dynamic> arq, String nomePasta) async {
    try {
      // Mostrar diálogo de carregamento
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );

      final id = arq['id'];
      final titulo = arq['titulo'] ?? arq['file_name'] ?? 'documento';
      final fileName = arq['file_name']?.toString() ?? '';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Obter extensão do arquivo - priorizar file_name
      String extensao = 'pdf';
      if (fileName.contains('.')) {
        extensao = fileName.split('.').last.toLowerCase();
      } else if (arq['extensao'] != null) {
        extensao = arq['extensao'].toString().toLowerCase();
      }

      final nomeArquivo = titulo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      // Verificar se é uma pasta (download completo) ou arquivo individual
      final isPasta = fileName == '.folder' || extensao == 'folder';

      // URL de download
      String url;
      if (isPasta) {
        // Para download de pasta completa, usar o nome da pasta
        final pastaReal = nomePasta == '_raiz' ? '' : nomePasta;
        url =
            'https://unienergyportal.com/api/mobile/cliente/documentos/download-pasta?pasta=${Uri.encodeComponent(pastaReal)}';
      } else {
        // Para arquivo individual, usar o ID
        url =
            'https://unienergyportal.com/api/mobile/cliente/documentos/download/$id';
      }

      // Obter token de autenticação
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      // Obter diretório de downloads
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Não foi possível acessar o diretório de downloads');
      }

      // Gerar nome único com extensão correta
      final finalExtensao = isPasta ? 'zip' : extensao;
      final finalNome = isPasta
          ? nomePasta.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          : nomeArquivo;
      String finalPath =
          '${downloadsDir.path}/${finalNome}_$timestamp.$finalExtensao';
      int counter = 1;
      while (await File(finalPath).exists()) {
        finalPath =
            '${downloadsDir.path}/${finalNome}_${timestamp}_($counter).$finalExtensao';
        counter++;
      }

      // Fazer download com autenticação
      final dio = Dio();
      await dio.download(
        url,
        finalPath,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Platform.isAndroid
                ? (isPasta
                    ? 'Pasta zipada salva na pasta Downloads'
                    : 'Arquivo salvo na pasta Downloads')
                : (isPasta
                    ? 'Pasta zipada salva com sucesso'
                    : 'Arquivo salvo com sucesso'),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      // Extrair mensagem de erro mais detalhada
      String errorMsg = 'Erro ao baixar arquivo';
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          errorMsg = 'Arquivo não encontrado no servidor';
        } else if (e.response?.statusCode == 401) {
          errorMsg = 'Sessão expirada. Faça login novamente';
        } else {
          errorMsg = 'Erro: ${e.response?.statusCode ?? e.message}';
        }
      } else {
        errorMsg = 'Erro: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  IconData _extIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'docx':
      case 'doc':
        return Icons.description_outlined;
      case 'txt':
        return Icons.text_snippet_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _extColor(String ext) {
    switch (ext) {
      case 'pdf':
        return const Color(0xFFef4444);
      case 'xlsx':
      case 'xls':
      case 'csv':
        return const Color(0xFF10b981);
      case 'docx':
      case 'doc':
        return const Color(0xFF3b82f6);
      case 'txt':
        return const Color(0xFF6b7280);
      case 'png':
      case 'jpg':
      case 'jpeg':
        return const Color(0xFF8b5cf6);
      default:
        return const Color(0xFFb0c4ce);
    }
  }

  String _fmtSize(dynamic bytes) {
    final b = int.tryParse(bytes.toString()) ?? 0;
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }
}
