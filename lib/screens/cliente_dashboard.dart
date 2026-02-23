import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta (idêntica ao restante do app)
// ─────────────────────────────────────────────────────────────────────────────
const _bgDark = Color(0xFF001f2e);
const _bgMid = Color(0xFF003a4d);
const _bgCard = Color(0xFF004D66);
const _accent = Color(0xFFEAC248);

// Cores das 3 barras do gráfico
const _barVS = Color(0xFF10b981); // VS → verde
const _barVE = Color(0xFFEAC248); // VE → dourado
const _barVU = Color(0xFF148bad); // VU → azul-água

const double _leftR = 48.0;
const double _rightR = 8.0;
const double _bottomR = 24.0;

// ─────────────────────────────────────────────────────────────────────────────

class ClienteDashboardTab extends StatefulWidget {
  const ClienteDashboardTab({super.key});

  @override
  State<ClienteDashboardTab> createState() => ClienteDashboardTabState();
}

class ClienteDashboardTabState extends State<ClienteDashboardTab> {
  // ── Estado ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _saldos;
  Map<String, dynamic>? _ultimoMes;
  List<Map<String, dynamic>> _grafico = [];
  List<Map<String, dynamic>> _contas = [];
  Set<String> _contasSelecionadas =
      {}; // MUDANÇA: agora é Set para multi-seleção

  bool _loadingSaldos = true;
  bool _loadingMes = true;
  bool _loadingGrafico = false;

  String? _mesSelecionado; // YYYY-MM

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> refresh() => _loadAll();

  // ── CARGA ────────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([
      _loadSaldos(),
      _loadContas(),
      _loadUltimoMes(),
    ]);
  }

  Future<void> _loadSaldos() async {
    setState(() => _loadingSaldos = true);
    try {
      final r = await ApiService.clienteDashboardSaldos();
      if (!mounted) return;
      setState(() {
        _saldos = r;
        _loadingSaldos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSaldos = false);
    }
  }

  Future<void> _loadContas() async {
    try {
      final r = await ApiService.clienteContasDisponiveis();
      if (!mounted) return;
      setState(() => _contas = List<Map<String, dynamic>>.from(r));
      await _loadGrafico();
    } catch (_) {}
  }

  Future<void> _loadGrafico() async {
    setState(() => _loadingGrafico = true);
    try {
      final contas = _contasSelecionadas.isEmpty
          ? _contas.map((c) => c['conta_contrato'] as String).toList()
          : _contasSelecionadas.toList();
      final r = await ApiService.clienteDashboardGrafico(contas: contas);
      if (!mounted) return;
      setState(() {
        _grafico = List<Map<String, dynamic>>.from(r);
        _loadingGrafico = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingGrafico = false);
    }
  }

  Future<void> _loadUltimoMes() async {
    setState(() => _loadingMes = true);
    try {
      final r =
          await ApiService.clienteDashboardUltimoMes(mes: _mesSelecionado);
      if (!mounted) return;
      setState(() {
        _ultimoMes = r;
        _loadingMes = false;
        if (_mesSelecionado == null && r['mes'] != null) {
          _mesSelecionado = r['mes'] as String;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMes = false);
    }
  }

  // ── UTILS ────────────────────────────────────────────────────────────────────

  String _fmtR(double v) {
    final s = v.toStringAsFixed(2);
    final p = s.split('.');
    final buf = StringBuffer();
    for (int i = 0; i < p[0].length; i++) {
      if (i > 0 && (p[0].length - i) % 3 == 0) buf.write('.');
      buf.write(p[0][i]);
    }
    return 'R\$ ${buf.toString()},${p[1]}';
  }

  String _shortR(double v) {
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(1)}k';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  double _toD(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Mantém os widgets em memória com suas próprias keys
    final graficoWidget = Container(
      key: const ValueKey('grafico'),
      child: _buildGraficoCard(),
    );

    final mesWidget = Container(
      key: const ValueKey('mes'),
      child: _buildMesCard(),
    );

    final saldosWidget = Container(
      key: const ValueKey('saldos'),
      child: _buildSaldosCard(),
    );

    return Container(
      color: _bgDark,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          graficoWidget,
          const SizedBox(height: 12),
          mesWidget,
          const SizedBox(height: 12),
          saldosWidget,
        ],
      ),
    );
  }

  // ── CARD SALDOS ACUMULADOS ───────────────────────────────────────────────────

  Widget _buildSaldosCard() {
    return _card(
      title: 'Acumulado 12 meses',
      icon: Icons.savings_outlined,
      child: _loadingSaldos
          ? const _Loading()
          : _saldos == null
              ? const _Empty('Sem dados')
              : Column(
                  children: [
                    Row(
                      children: [
                        _saldoItem('Valor sem Solar',
                            _toD(_saldos!['vs_total']), _barVS),
                        _saldoItem(
                            'Sua Economia', _toD(_saldos!['ve_total']), _barVE),
                        _saldoItem('Valor Unienergy',
                            _toD(_saldos!['vu_total']), _barVU),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _bgCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ecoItem(
                            Icons.park_outlined,
                            '${_toD(_saldos!['arvores_salvas']).toStringAsFixed(1)}',
                            'Árvores salvas',
                            Colors.green,
                          ),
                          Container(
                              width: 1, height: 36, color: Colors.white12),
                          _ecoItem(
                            Icons.cloud_outlined,
                            '${(_toD(_saldos!['co2_evitado_kg']) / 1000).toStringAsFixed(2)} t',
                            'CO₂ evitado',
                            Colors.lightBlue,
                          ),
                          Container(
                              width: 1, height: 36, color: Colors.white12),
                          _ecoItem(
                            Icons.people_outline,
                            '${_saldos!['total_beneficiarios'] ?? 0}',
                            'Beneficiários',
                            _accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _saldoItem(String label, double valor, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 4,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
                fontSize: 8.5, color: Color(0xFFb0c4ce), letterSpacing: 0.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _fmtR(valor),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _ecoItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 9, color: Color(0xFFb0c4ce))),
      ],
    );
  }

  // ── CARD ÚLTIMO MÊS ─────────────────────────────────────────────────────────

  Widget _buildMesCard() {
    return _card(
      title: _ultimoMes != null && _ultimoMes!['mes_exibicao'] != null
          ? 'Resumo — ${_ultimoMes!['mes_exibicao']}'
          : 'Resumo do Mês',
      icon: Icons.receipt_long_outlined,
      trailing: _buildMesPicker(),
      child: _loadingMes
          ? const _Loading()
          : (_ultimoMes == null || _ultimoMes!['tem_dados'] == false)
              ? const _Empty('Sem dados para este mês')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _mesItem('Sem Solar', _toD(_ultimoMes!['vs']), _barVS),
                        _mesItem('Economia', _toD(_ultimoMes!['ve']), _barVE),
                        _mesItem('Unienergy', _toD(_ultimoMes!['vu']), _barVU),
                      ],
                    ),
                    if (_ultimoMes!['documentos'] != null &&
                        (_ultimoMes!['documentos'] as List).isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Documentos do mês',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFb0c4ce),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...(_ultimoMes!['documentos'] as List)
                          .map((d) => _docRow(d as Map<String, dynamic>))
                          .toList(),
                    ],
                  ],
                ),
    );
  }

  Widget _mesItem(String label, double valor, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: Color(0xFFb0c4ce))),
            const SizedBox(height: 4),
            Text(_fmtR(valor),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _docRow(Map<String, dynamic> doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_outlined, color: _accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['conta_contrato'] ?? '',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'R\$ ${_toD(doc['valor_fatura']).toStringAsFixed(2)}',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFFb0c4ce)),
                ),
              ],
            ),
          ),
          if (doc['bank_slip_url'] != null)
            _linkBtn(Icons.barcode_reader, doc['bank_slip_url']),
          if (doc['fatura_url'] != null)
            _linkBtn(Icons.description_outlined, doc['fatura_url']),
          if (doc['file_url'] != null)
            _downloadBtn(Icons.bolt_outlined, doc['file_url'],
                doc['conta_contrato'] ?? 'ContaNeo'),
        ],
      ),
    );
  }

  Widget _linkBtn(IconData icon, String? url) {
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        // Completar URL se for caminho relativo
        String fullUrl = url;
        if (url.startsWith('/')) {
          fullUrl = 'https://unienergyportal.com$url';
        }
        if (await canLaunchUrl(Uri.parse(fullUrl))) {
          await launchUrl(Uri.parse(fullUrl),
              mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _bgMid,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: _accent, size: 14),
      ),
    );
  }

  Widget _downloadBtn(IconData icon, String? url, String nomeArquivo) {
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _baixarArquivo(url, nomeArquivo),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _bgMid,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: _accent, size: 14),
      ),
    );
  }

  Future<void> _baixarArquivo(String url, String nomeArquivo) async {
    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );

      // Completar URL se for caminho relativo
      String fullUrl = url;
      if (url.startsWith('/')) {
        fullUrl = 'https://unienergyportal.com$url';
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

      // Gerar nome único
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String finalPath = '${downloadsDir.path}/${nomeArquivo}_$timestamp.pdf';
      int counter = 1;
      while (await File(finalPath).exists()) {
        finalPath =
            '${downloadsDir.path}/${nomeArquivo}_${timestamp}_($counter).pdf';
        counter++;
      }

      // Fazer download com autenticação
      final dio = Dio();
      await dio.download(
        fullUrl,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao baixar arquivo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMesPicker() {
    return GestureDetector(
      onTap: _pickMes,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 10, color: _accent),
            const SizedBox(width: 4),
            Text(
              _mesSelecionado ?? 'Mês',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMes() async {
    // Gerar últimos 12 meses
    final agora = DateTime.now();
    final opcoes = List.generate(12, (i) {
      final d = DateTime(agora.year, agora.month - i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    final escolhido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _bgMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Selecione o mês',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          ...opcoes.map((m) {
            final parts = m.split('-');
            const meses = [
              'Jan',
              'Fev',
              'Mar',
              'Abr',
              'Mai',
              'Jun',
              'Jul',
              'Ago',
              'Set',
              'Out',
              'Nov',
              'Dez'
            ];
            final label = '${meses[int.parse(parts[1]) - 1]}/${parts[0]}';
            final selected = m == _mesSelecionado;
            return ListTile(
              dense: true,
              title: Text(label,
                  style: TextStyle(
                    color: selected ? _accent : Colors.white,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  )),
              trailing: selected
                  ? const Icon(Icons.check, color: _accent, size: 16)
                  : null,
              onTap: () => Navigator.pop(ctx, m),
            );
          }),
        ],
      ),
    );

    if (escolhido != null && escolhido != _mesSelecionado) {
      setState(() => _mesSelecionado = escolhido);
      _loadUltimoMes();
    }
  }

  // ── CARD GRÁFICO ─────────────────────────────────────────────────────────────

  Widget _buildGraficoCard() {
    return _card(
      title: 'Evolução mensal',
      icon: Icons.bar_chart_rounded,
      trailing: _buildContaFiltro(),
      child: Column(
        children: [
          _buildLegenda(),
          const SizedBox(height: 10),
          _loadingGrafico
              ? const _Loading()
              : _grafico.isEmpty
                  ? const _Empty('Sem dados')
                  : _buildBarChart(),
        ],
      ),
    );
  }

  Widget _buildContaFiltro() {
    if (_contas.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<void>(
      color: _bgMid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      offset: const Offset(0, 40),
      onCanceled: () {
        // Recarrega apenas quando o menu fecha
        _loadGrafico();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 12, color: _accent),
            const SizedBox(width: 4),
            Text(
              _contasSelecionadas.isEmpty
                  ? 'Todas'
                  : _contasSelecionadas.length == _contas.length
                      ? 'Todas'
                      : '${_contasSelecionadas.length} conta${_contasSelecionadas.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 14, color: _accent),
          ],
        ),
      ),
      itemBuilder: (ctx) {
        return [
          // Lista de contas individuais
          ..._contas.map((c) {
            final conta = c['conta_contrato'] as String;
            final label = c['label'] as String;

            return PopupMenuItem<void>(
              padding: EdgeInsets.zero,
              child: StatefulBuilder(
                builder: (context, setMenuState) {
                  final selected = _contasSelecionadas.contains(conta);

                  return CheckboxListTile(
                    value: selected,
                    activeColor: _accent,
                    checkColor: _bgDark,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: selected ? _accent : Colors.white,
                        fontSize: 11,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    dense: true,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _contasSelecionadas.add(conta);
                        } else {
                          _contasSelecionadas.remove(conta);
                        }
                      });
                      setMenuState(() {});
                    },
                  );
                },
              ),
            );
          }),
        ];
      },
    );
  }

  Widget _buildLegenda() {
    // Legenda em linha única fixa (3 itens distribuídos)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legItem(_barVS, 'Sem Solar (VS)'),
        const SizedBox(width: 14),
        _legItem(_barVE, 'Economia (VE)'),
        const SizedBox(width: 14),
        _legItem(_barVU, 'Unienergy (VU)'),
      ],
    );
  }

  Widget _legItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFb0c4ce),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBarChart() {
    // Agregar dados por mês quando múltiplas contas selecionadas
    Map<String, Map<String, double>> dadosAgregados = {};

    for (final d in _grafico) {
      final mes = d['mes'] as String;
      if (!dadosAgregados.containsKey(mes)) {
        dadosAgregados[mes] = {'vs': 0.0, 've': 0.0, 'vu': 0.0};
      }
      dadosAgregados[mes]!['vs'] = dadosAgregados[mes]!['vs']! + _toD(d['vs']);
      dadosAgregados[mes]!['ve'] = dadosAgregados[mes]!['ve']! + _toD(d['ve']);
      dadosAgregados[mes]!['vu'] = dadosAgregados[mes]!['vu']! + _toD(d['vu']);
    }

    final mesesOrdenados = dadosAgregados.keys.toList()..sort();

    // Calcular maxY considerando todas as barras (VS, VE, VU)
    double maxY = 0;
    for (final dados in dadosAgregados.values) {
      final vs = dados['vs']!;
      final ve = dados['ve']!;
      final vu = dados['vu']!;
      if (vs > maxY) maxY = vs;
      if (ve > maxY) maxY = ve;
      if (vu > maxY) maxY = vu;
    }
    if (maxY == 0) maxY = 1;

    // Altura dinâmica baseada em orientação
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final chartH = isLandscape ? 200.0 : 260.0;

    // Largura de barra dinâmica para evitar sobreposição
    final screenW = MediaQuery.of(context).size.width;
    final pad = 14.0; // padding estimado
    final chartW = screenW - (pad * 2) - 20;
    final barW = ((chartW / 12) / 6.5).clamp(2.5, 6.5);

    final groups = mesesOrdenados.asMap().entries.map((e) {
      final dados = dadosAgregados[e.value]!;
      return BarChartGroupData(
        x: e.key,
        barsSpace: 1,
        barRods: [
          BarChartRodData(
            toY: dados['vs']!,
            color: _barVS,
            width: barW,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
          BarChartRodData(
            toY: dados['ve']!,
            color: _barVE,
            width: barW,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
          BarChartRodData(
            toY: dados['vu']!,
            color: _barVU,
            width: barW,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
        ],
      );
    }).toList();

    List<String> labels = mesesOrdenados.map((m) {
      final p = m.split('-');
      const mn = [
        'Jan',
        'Fev',
        'Mar',
        'Abr',
        'Mai',
        'Jun',
        'Jul',
        'Ago',
        'Set',
        'Out',
        'Nov',
        'Dez'
      ];
      return mn[int.parse(p[1]) - 1];
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        height: chartH,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.fromLTRB(4, 10, 8, 4),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            groupsSpace: 6,
            maxY: maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => _bgMid.withValues(alpha: 0.95),
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                tooltipMargin: 8,
                tooltipBorderRadius: BorderRadius.circular(6),
                getTooltipItem: (group, gi, rod, ri) {
                  final mes = labels[group.x.toInt()];
                  final dados =
                      dadosAgregados[mesesOrdenados[group.x.toInt()]]!;
                  final vs = dados['vs']!;
                  final ve = dados['ve']!;
                  final vu = dados['vu']!;

                  // Calcula percentual de economia (VE em relação a VS)
                  final economiaPerc = vs > 0 ? ((ve / vs) * 100) : 0.0;

                  return BarTooltipItem(
                    '$mes\n',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1.4,
                        fontWeight: FontWeight.w600),
                    children: [
                      const TextSpan(
                        text: '● ',
                        style: TextStyle(
                            color: _barVS,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      const TextSpan(text: 'Sem Solar: '),
                      TextSpan(text: '${_fmtR(vs)}\n'),
                      const TextSpan(
                        text: '● ',
                        style: TextStyle(
                            color: _barVE,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      const TextSpan(text: 'Economia: '),
                      TextSpan(text: '${_fmtR(ve)}\n'),
                      const TextSpan(
                        text: '● ',
                        style: TextStyle(
                            color: _barVU,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      const TextSpan(text: 'Unienergy: '),
                      TextSpan(text: '${_fmtR(vu)}\n'),
                      const TextSpan(
                        text: 'Economia: ',
                        style: TextStyle(color: Color(0xFFb0c4ce)),
                      ),
                      TextSpan(
                        text: '${economiaPerc.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            color: _accent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: _bottomR,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) return const Text('');
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(labels[i],
                          style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w500)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: _leftR,
                  interval: maxY / 5,
                  getTitlesWidget: (v, m) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _shortR(v),
                      style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF6b7280),
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 5,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFFd1d5db).withValues(alpha: 0.5),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: groups,
          ),
        ),
      ),
    );
  }

  // ── HELPER CARD ──────────────────────────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _bgMid,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _accent, width: 2)),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: _accent, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      )),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
        ),
      );
}

class _Empty extends StatelessWidget {
  final String msg;
  const _Empty(this.msg);
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 60,
        child: Center(
          child: Text(msg,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      );
}
