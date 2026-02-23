import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

const _bgDark = Color(0xFF001f2e);
const _bgMid = Color(0xFF003a4d);
const _bgCard = Color(0xFF004D66);
const _accent = Color(0xFFEAC248);

class ClienteContasTab extends StatefulWidget {
  const ClienteContasTab({super.key});

  @override
  State<ClienteContasTab> createState() => ClienteContasTabState();
}

class ClienteContasTabState extends State<ClienteContasTab> {
  List<Map<String, dynamic>> _contas = [];
  List<Map<String, dynamic>> _filtradas = [];
  bool _loading = true;
  String? _erro;
  final Set<int> _expandidos = {};

  String _busca = '';
  String? _mesAtivo;
  DateTime? _dataSelecionada;
  final _buscaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContas();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> refresh() => _loadContas();

  Future<void> _loadContas() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final r = await ApiService.clienteContasNeoenergia();
      if (!mounted) return;
      setState(() {
        _contas = List<Map<String, dynamic>>.from(r);
        _loading = false;
      });
      _aplicarFiltro();
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _erro = e.toString();
        });
    }
  }

  void _aplicarFiltro() {
    setState(() {
      _filtradas = _contas.where((c) {
        final mesOk = _mesAtivo == null || c['ref_mes_ano'] == _mesAtivo;
        final termo = _busca.toLowerCase();
        final busOk = termo.isEmpty ||
            (c['codigo_cliente'] ?? '').toString().contains(termo) ||
            (c['beneficiario_nome'] ?? '')
                .toString()
                .toLowerCase()
                .contains(termo) ||
            (c['nome_cliente'] ?? '').toString().toLowerCase().contains(termo);
        return mesOk && busOk;
      }).toList();
    });
  }

  double _toD(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _formatarData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty || dataStr.contains('%')) return '';
    final s = dataStr.trim();
    try {
      if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(s)) return s;
      if (s.contains('T'))
        return DateFormat('dd/MM/yyyy').format(DateTime.parse(s));
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s))
        return DateFormat('dd/MM/yyyy').format(DateTime.parse(s));
      return s;
    } catch (_) {
      return s;
    }
  }

  String _fullUrl(String url) =>
      url.startsWith('/') ? 'https://unienergyportal.com$url' : url;

  // ═══════════════════════════════════════════════════════════════════════════
  // MODAL DE VISUALIZAÇÃO DE DOCUMENTO
  // ═══════════════════════════════════════════════════════════════════════════

  void _abrirDocumento({
    required String label,
    required String url,
    required Color color,
    required IconData icon,
  }) {
    final fullUrl = _fullUrl(url);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.42,
        decoration: const BoxDecoration(
          color: _bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),

            // Ícone grande
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4), width: 2),
              ),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: 14),

            // Label do documento
            Text(
              label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 6),

            // URL resumida
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                fullUrl.length > 60
                    ? '...${fullUrl.substring(fullUrl.length - 60)}'
                    : fullUrl,
                style: const TextStyle(fontSize: 10, color: Color(0xFF7da5b5)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const Spacer(),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),

            // Botões
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Row(
                children: [
                  // Visualizar
                  Expanded(
                    child: _modalBtn(
                      icon: Icons.visibility_outlined,
                      label: 'Visualizar',
                      color: color,
                      filled: true,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _visualizarNoNavegador(fullUrl);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Baixar
                  Expanded(
                    child: _modalBtn(
                      icon: Icons.download_outlined,
                      label: 'Baixar PDF',
                      color: color,
                      filled: false,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final nome =
                            '${label.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
                        await _baixarArquivo(fullUrl, nome);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: filled ? 0 : 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? _bgDark : color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: filled ? _bgDark : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _visualizarNoNavegador(String url) async {
    // Para PDFs do Asaas (já são URLs diretas), abre direto.
    // Para PDFs internos, usa o Google Docs Viewer como fallback
    // caso o dispositivo não tenha app de PDF.
    String targetUrl = url;

    // Se for um PDF interno (não Asaas), tenta abrir via Google Docs Viewer
    if (!url.contains('asaas.com')) {
      targetUrl =
          'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}';
    }

    final uri = Uri.parse(targetUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: tenta URL original
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Não foi possível abrir: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── DOWNLOAD ─────────────────────────────────────────────────────────────────

  Future<void> _baixarArquivo(String url, String nomeArquivo) async {
    BuildContext? dialogCtx;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogCtx = ctx;
        return const Center(child: CircularProgressIndicator(color: _accent));
      },
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (dir == null) throw Exception('Diretório de downloads indisponível');

      String finalPath = '${dir.path}/$nomeArquivo.pdf';
      int counter = 1;
      while (await File(finalPath).exists()) {
        finalPath = '${dir.path}/$nomeArquivo($counter).pdf';
        counter++;
      }

      await Dio().download(
        url,
        finalPath,
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );

      if (!mounted) return;
      if (dialogCtx != null) Navigator.pop(dialogCtx!);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Platform.isAndroid
            ? 'Salvo na pasta Downloads'
            : 'Arquivo salvo com sucesso'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      if (dialogCtx != null) Navigator.pop(dialogCtx!);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao baixar: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
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
          : _erro != null
              ? _buildErro()
              : _filtradas.isEmpty
                  ? Column(
                      children: [
                        _buildFiltros(),
                        const Expanded(
                          child: Center(
                            child: Text('Nenhuma conta encontrada',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 13)),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(0),
                      itemCount: _filtradas.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) return _buildFiltros();
                        final isLast = i == _filtradas.length;
                        return Padding(
                          padding:
                              EdgeInsets.fromLTRB(12, 8, 12, isLast ? 24 : 0),
                          child: _buildContaCard(_filtradas[i - 1], i - 1),
                        );
                      },
                    ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_erro ?? 'Erro desconhecido',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _bgDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _loadContas,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  // ── FILTROS ──────────────────────────────────────────────────────────────────

  Widget _buildFiltros() {
    return Container(
      color: _bgMid,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _accent.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _buscaCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                hintText: 'Buscar por conta ou beneficiário...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: _accent, size: 18),
              ),
              onChanged: (v) {
                _busca = v;
                _aplicarFiltro();
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSeletorCalendario()),
              if (_mesAtivo != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _mesAtivo = null;
                      _dataSelecionada = null;
                    });
                    _aplicarFiltro();
                  },
                  child: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _accent.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.clear, color: _accent, size: 18),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeletorCalendario() {
    final ativo = _mesAtivo != null;
    return GestureDetector(
      onTap: _abrirCalendario,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ativo ? _accent.withOpacity(0.15) : _bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: ativo ? _accent : _accent.withOpacity(0.3),
              width: ativo ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month,
                color: ativo ? _accent : Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _mesAtivo ?? 'Selecionar mês',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: ativo ? FontWeight.w600 : FontWeight.normal,
                  color: ativo ? _accent : Colors.white70,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: ativo ? _accent : Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirCalendario() async {
    final resultado = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => _SeletorMesAno(dataSelecionada: _dataSelecionada),
    );
    if (resultado != null) {
      final mes = resultado['mes']!;
      final ano = resultado['ano']!;
      setState(() {
        _dataSelecionada = DateTime(ano, mes);
        _mesAtivo = '${mes.toString().padLeft(2, '0')}/$ano';
      });
      _aplicarFiltro();
    }
  }

  // ── CARD DE CONTA ────────────────────────────────────────────────────────────

  Widget _buildContaCard(Map<String, dynamic> conta, int index) {
    final temBoleto = conta['bank_slip_url'] != null;
    final temFatura = conta['fatura_url'] != null;
    final temNeo = conta['file_url'] != null;
    final temUni = conta['fatura_unienergy_url'] != null;
    final isExpanded = _expandidos.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _bgMid,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Cabeçalho
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded)
                  _expandidos.remove(index);
                else
                  _expandidos.add(index);
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(10),
              bottom: isExpanded ? Radius.zero : const Radius.circular(10),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: _bgCard,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(10),
                  bottom: isExpanded ? Radius.zero : const Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      color: _accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conta['beneficiario_nome'] ??
                              conta['nome_cliente'] ??
                              '—',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Conta: ${conta['codigo_cliente'] ?? '—'}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFFb0c4ce))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accent.withOpacity(0.5)),
                    ),
                    child: Text(conta['ref_mes_ano'] ?? '',
                        style: const TextStyle(
                            fontSize: 10,
                            color: _accent,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: _accent, size: 20),
                ],
              ),
            ),
          ),

          // Conteúdo expansível
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  _valorItem('Conta Neoenergia', _toD(conta['total_conta']),
                      conta['vencimento_conta']),
                  const SizedBox(width: 8),
                  _valorItem('Fatura Unienergy', _toD(conta['total_fatura']),
                      conta['vencimento_fatura']),
                ],
              ),
            ),

            // Botões de documento
            if (temBoleto || temFatura || temNeo || temUni)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    // Primeira linha: Conta Neo + Fatura Unienergy
                    if (temNeo || temFatura)
                      Row(
                        children: [
                          if (temNeo)
                            Expanded(
                                child: _docBtn(
                              icon: Icons.bolt_outlined,
                              label: 'Conta Neo',
                              url: conta['file_url'],
                              color: _accent,
                            )),
                          if (temNeo && temFatura) const SizedBox(width: 6),
                          if (temFatura)
                            Expanded(
                                child: _docBtn(
                              icon: Icons.description_outlined,
                              label: 'Fatura Uni',
                              url: conta['fatura_url'],
                              color: const Color(0xFFFF8C42),
                            )),
                          if (temNeo && !temFatura)
                            const Expanded(child: SizedBox()),
                          if (!temNeo && temFatura)
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    if ((temNeo || temFatura) && (temBoleto || temUni))
                      const SizedBox(height: 6),
                    // Segunda linha: Boleto + Asaas
                    if (temBoleto || temUni)
                      Row(
                        children: [
                          if (temBoleto)
                            Expanded(
                                child: _docBtn(
                              icon: Icons.qr_code_2_outlined,
                              label: 'Boleto',
                              url: conta['bank_slip_url'],
                              color: const Color(0xFF148bad),
                            )),
                          if (temBoleto && temUni) const SizedBox(width: 6),
                          if (temUni)
                            Expanded(
                                child: _docBtn(
                              icon: Icons.open_in_new,
                              label: 'Asaas',
                              url: conta['fatura_unienergy_url'],
                              color: const Color(0xFF10b981),
                            )),
                          if (temBoleto && !temUni)
                            const Expanded(child: SizedBox()),
                          if (!temBoleto && temUni)
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Botão que abre o modal de documento (substituiu o _downloadBtn direto)
  Widget _docBtn({
    required IconData icon,
    required String label,
    required String? url,
    required Color color,
  }) {
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _abrirDocumento(
        label: label,
        url: url,
        color: color,
        icon: icon,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valorItem(String label, double valor, String? vencimento) {
    final dataFormatada = _formatarData(vencimento);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: _bgCard, borderRadius: BorderRadius.circular(7)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: Color(0xFFb0c4ce))),
            const SizedBox(height: 3),
            Text(
              valor > 0
                  ? NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                      .format(valor)
                  : '—',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            if (dataFormatada.isNotEmpty)
              Text('Venc: $dataFormatada',
                  style:
                      const TextStyle(fontSize: 9, color: Color(0xFFb0c4ce))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SELETOR DE MÊS/ANO
// ═══════════════════════════════════════════════════════════════════════════

class _SeletorMesAno extends StatefulWidget {
  final DateTime? dataSelecionada;
  const _SeletorMesAno({this.dataSelecionada});

  @override
  State<_SeletorMesAno> createState() => _SeletorMesAnoState();
}

class _SeletorMesAnoState extends State<_SeletorMesAno> {
  late int _ano;
  late int _mes;

  static const _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.dataSelecionada ?? DateTime.now();
    _ano = d.year;
    _mes = d.month;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _accent.withOpacity(0.3)),
      ),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: _accent, size: 20),
                const SizedBox(width: 10),
                const Text('Selecionar Mês',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon:
                      const Icon(Icons.close, color: Colors.white54, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _bgMid,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _ano--),
                    icon: const Icon(Icons.chevron_left, color: _accent),
                  ),
                  Text('$_ano',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _accent)),
                  IconButton(
                    onPressed: () => setState(() => _ano++),
                    icon: const Icon(Icons.chevron_right, color: _accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: 12,
              itemBuilder: (_, i) {
                final sel = i + 1 == _mes;
                return GestureDetector(
                  onTap: () => setState(() => _mes = i + 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: sel ? _accent : _bgMid,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? _accent : _accent.withOpacity(0.2),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _meses[i].substring(0, 3),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? const Color(0xFF003E52) : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, {'mes': _mes, 'ano': _ano}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF003E52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirmar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

class ClienteFaturasTab extends StatelessWidget {
  const ClienteFaturasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: const SafeArea(child: ClienteContasTab()),
    );
  }
}
