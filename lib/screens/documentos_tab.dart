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

class DocumentosTab extends StatefulWidget {
  const DocumentosTab({super.key});

  @override
  State<DocumentosTab> createState() => _DocumentosTabState();
}

class _DocumentosTabState extends State<DocumentosTab> {
  Map<String, List<dynamic>> _arquivosPorPasta = {};
  final Set<String> _pastasExpandidas = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final pRes = await ApiService.getDocumentosPastas();
      if (!mounted) return;

      final Map<String, List<dynamic>> arquivosPorPasta = {};
      final pastas = pRes['pastas'] ?? [];

      // Carregar arquivos sem pasta (raiz)
      final aResRaiz = await ApiService.getDocumentosArquivos(pasta: null);
      final arquivosRaiz = aResRaiz['arquivos'] ?? [];
      if (arquivosRaiz.isNotEmpty) {
        final arquivosFiltrados = arquivosRaiz
            .where((arq) =>
                arq['file_name'] != '.folder' &&
                arq['extensao']?.toString().toLowerCase() != 'folder')
            .toList();
        if (arquivosFiltrados.isNotEmpty) {
          arquivosPorPasta['_raiz'] = arquivosFiltrados;
        }
      }

      // Carregar arquivos de cada pasta
      for (var pasta in pastas) {
        final nomePasta = pasta['pasta'];
        if (nomePasta != null && nomePasta.isNotEmpty) {
          final aRes = await ApiService.getDocumentosArquivos(pasta: nomePasta);
          final arquivos = aRes['arquivos'] ?? [];
          if (arquivos.isNotEmpty) {
            final arquivosFiltrados = arquivos
                .where((arq) =>
                    arq['file_name'] != '.folder' &&
                    arq['extensao']?.toString().toLowerCase() != 'folder')
                .toList();
            if (arquivosFiltrados.isNotEmpty) {
              arquivosPorPasta[nomePasta] = arquivosFiltrados;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _arquivosPorPasta = arquivosPorPasta;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  IconData _extIcon(String ext) {
    switch (ext.toLowerCase()) {
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
    switch (ext.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _buildDocumentos(),
    );
  }

  Widget _buildDocumentos() {
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
      String nomePasta, List<dynamic> arquivos, IconData icon) {
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
                children:
                    arquivos.map((arq) => _buildArquivoCard(arq)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArquivoCard(dynamic arq) {
    final ext = (arq['extensao'] ?? 'file').toString().toLowerCase();
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

  Future<void> _downloadArquivo(dynamic arq) async {
    try {
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

      // URL de download - ajustar conforme API
      final url =
          'https://unienergyportal.com/api/mobile/investor/documentos/download/$id';

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

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

      String finalPath =
          '${downloadsDir.path}/${nomeArquivo}_$timestamp.$extensao';
      int counter = 1;
      while (await File(finalPath).exists()) {
        finalPath =
            '${downloadsDir.path}/${nomeArquivo}_${timestamp}_($counter).$extensao';
        counter++;
      }

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
                ? 'Arquivo salvo na pasta Downloads'
                : 'Arquivo salvo com sucesso',
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
}
