import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/usina.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta fiel ao sistema web
// ─────────────────────────────────────────────────────────────────────────────
const _bgDark = Color(0xFF001f2e);
const _bgMid = Color(0xFF003a4d);
const _bgCard = Color(0xFF004D66);
const _accent = Color(0xFFEAC248); // dourado
const _barProg = Color(0xFF004D66); // azul-escuro  → Prognóstico
const _barReal = Color(0xFFEAC248); // dourado      → Realizado Inversor
const _barComp = Color(0xFF148bad); // azul-água    → Compensado
const _barFat = Color(0xFF10b981); // verde        → Faturado
const _cardBg = Color(0xFF003a4d); // azul-escuro dos cards
const _cardText = Colors.white; // texto principal dos cards

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<Gerador> _geradores = [];
  String? _geradorSelecionado;
  InvestorDashboardData? _dashboardData;
  List<dynamic> _graficoData = [];
  bool _isLoadingGeradores = true;
  bool _isLoadingDashboard = false;
  int _anoSelecionado = DateTime.now().year;
  int? _touchedDashboardGroupIndex;

  @override
  void initState() {
    super.initState();
    _loadGeradores();
  }

  // ── DADOS ──────────────────────────────────────────────────────────────────

  Future<void> _loadGeradores() async {
    setState(() => _isLoadingGeradores = true);
    try {
      final geradores = await ApiService.getGeradores();
      if (mounted) {
        setState(() {
          _geradores = geradores;
          _isLoadingGeradores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGeradores = false);
        _showError('Erro ao carregar geradores: $e');
      }
    }
  }

  Future<void> _loadDashboard() async {
    if (_geradorSelecionado == null) return;
    setState(() {
      _isLoadingDashboard = true;
      _touchedDashboardGroupIndex = null;
    });
    try {
      final dash =
          await ApiService.getDashboardInvestidor([_geradorSelecionado!]);
      final grafico = await ApiService.getGraficoGeracao(
        geradores: [_geradorSelecionado!],
        ano: _anoSelecionado,
      );
      if (mounted) {
        setState(() {
          _dashboardData = dash;
          _graficoData = (grafico['dados'] as List<dynamic>?) ?? [];
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDashboard = false);
        _showError('Erro ao carregar dashboard: $e');
      }
    }
  }

  Future<void> refresh() async {
    await _loadGeradores();
    if (_geradorSelecionado != null) await _loadDashboard();
  }

  void _selecionarGerador(String codigo) {
    setState(() {
      if (_geradorSelecionado == codigo) {
        _geradorSelecionado = null;
        _dashboardData = null;
        _graficoData = [];
      } else {
        _geradorSelecionado = codigo;
      }
    });
    if (_geradorSelecionado != null) _loadDashboard();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── BUILD PRINCIPAL ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoadingGeradores) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final pad = _padding(context);

        return Container(
          color: _bgDark,
          child: _isLoadingDashboard
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : _buildContent(pad, isLandscape),
        );
      },
    );
  }

  // ── FILTRO DE GERADOR ──────────────────────────────────────────────────────

  Widget _buildGeradorFilter(double pad, {bool insideList = false}) {
    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _geradorSelecionado != null ? _accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _geradorSelecionado,
          isExpanded: true,
          hint: Row(
            children: const [
              Icon(Icons.solar_power_rounded, color: _accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Selecione o Gerador',
                style: TextStyle(
                  color: Color.fromARGB(255, 255, 255, 255),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          icon: const Icon(Icons.expand_more, color: _accent, size: 22),
          dropdownColor: _bgMid,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          items: _geradores.map((g) {
            return DropdownMenuItem<String>(
              value: g.codigoGerador,
              child: Row(
                children: [
                  const Icon(Icons.solar_power_outlined,
                      color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Text(g.codigoGerador),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) _selecionarGerador(v);
          },
        ),
      ),
    );
    return insideList
        ? widget
        : Padding(
            padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
            child: widget,
          );
  }

  // ── CONTEÚDO (portrait / landscape) ───────────────────────────────────────

  Widget _buildContent(double pad, bool isLandscape) {
    // O dropdown de gerador entra DENTRO do ListView para sumir no scroll
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 10, pad, pad),
      children: [
        // ── Dropdown (some ao scrollar) ──
        _buildGeradorFilter(pad, insideList: true),
        const SizedBox(height: 12),

        if (_isLoadingDashboard)
          const SizedBox(
            height: 450,
            child: Center(child: CircularProgressIndicator(color: _accent)),
          )
        else if (_dashboardData == null)
          const SizedBox(
            height: 450,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_outlined,
                      color: Colors.white24, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'Selecione um gerador para ver os dados',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Nome do gerador
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.solar_power_rounded, color: _accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  _geradores
                      .firstWhere((g) => g.codigoGerador == _geradorSelecionado,
                          orElse: () => _geradores.first)
                      .codigoGerador,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // 6 Cards  —  2 col portrait / 3 col landscape
          _buildCards(isLandscape),
          const SizedBox(height: 14),

          // Cabeçalho do gráfico
          _sectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Geração Mensal  •  kWh',
            trailing: _anoDropdown(),
          ),
          const SizedBox(height: 10),

          // Gráfico
          _buildGrafico(),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // ── CARDS ──────────────────────────────────────────────────────────────────

  Widget _buildCards(bool isLandscape) {
    final d = _dashboardData!;

    // Ticket Médio: sem o "R$ " duplicado, só o número formatado
    final ticketFmt = 'R\$ ${_fmtBR(d.ticketMedio)}';

    final items = [
      _CardData(
        icon: Icons.savings_outlined,
        label: 'Crédito Acumulado',
        value: _fmtBR(d.creditoAcumulado),
        unit: 'kWh',
        sub: 'Mês vigente',
      ),
      _CardData(
        icon: Icons.people_outline,
        label: 'Beneficiários',
        value: '${d.totalBeneficiarios}',
        unit: 'ligados',
        sub: 'Ligados no período',
      ),
      _CardData(
        icon: Icons.receipt_long_outlined,
        label: 'Ticket Médio',
        value: ticketFmt,
        unit: '',
        sub: 'Por beneficiário',
      ),
      _CardData(
        icon: Icons.bolt_outlined,
        label: 'Capacidade Total',
        value: _fmtBR(d.capacidadeTotal),
        unit: 'kWh',
        sub: 'Média anual',
      ),
      _CardData(
        icon: Icons.track_changes_outlined,
        label: 'Performance Alvo',
        value: _fmtBR(d.performanceAlvo),
        unit: 'kWh',
        sub: 'Soma dos PAs',
      ),
      _CardData(
        icon: Icons.sell_outlined,
        label: 'Disponível p/ Venda',
        value: d.disponivelVenda < 0
            ? '-${_fmtBR(d.disponivelVenda.abs())}'
            : _fmtBR(d.disponivelVenda),
        unit: 'kWh',
        sub: 'Capacidade - Alvo',
        negative: d.disponivelVenda < 0,
        valueColor: d.disponivelVenda > 0
            ? const Color(0xFF10b981)
            : d.disponivelVenda == 0
                ? _cardText
                : null,
      ),
    ];

    final cols = isLandscape ? 3 : 2;

    // childAspectRatio dinâmico para não quebrar em telas pequenas
    final screenW = MediaQuery.of(context).size.width;
    final cardW =
        (screenW - (_padding(context) * 2) - (9.0 * (cols - 1))) / cols;
    final ratio = cardW / 90.0; // altura alvo ~90px

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: ratio.clamp(1.3, 2.4),
      children: items.map(_cardWidget).toList(),
    );
  }

  Widget _cardWidget(_CardData c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // Fundo claro igual ao web (rgba ~branco)
        color: _cardBg,
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: _accent, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Ícone + Label
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(c.icon, size: 14, color: _accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFFb0c4ce),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          // Valor + Subtexto
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.valueColor ??
                      (c.negative ? const Color(0xFFdc2626) : _cardText),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (c.sub != null || c.unit.isNotEmpty)
                Text(
                  c.sub ?? c.unit,
                  style: const TextStyle(
                    fontSize: 9,
                    color: const Color(0xFFb0c4ce),
                  ),
                  maxLines: 1,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── GRÁFICO ────────────────────────────────────────────────────────────────

  Widget _buildGrafico() {
    if (_graficoData.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Sem dados para o período',
              style: TextStyle(color: Color(0xFFb0c4ce), fontSize: 13)),
        ),
      );
    }

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

    double maxY = 0;
    for (final d in _graficoData) {
      for (final key in [
        'prognostico',
        'realizado_inversor',
        'compensado',
        'faturado'
      ]) {
        final v = _toDouble(d[key]);
        if (v > maxY) maxY = v;
      }
    }
    if (maxY == 0) maxY = 1;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final chartH = isLandscape ? 200.0 : 260.0;

    // Barras mais finas para não se engolir no portrait
    final screenW = MediaQuery.of(context).size.width;
    final chartW = screenW - (_padding(context) * 2) - 20;
    final barW = ((chartW / 12) / 6.5).clamp(2.5, 6.5);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Legenda 2×2 fixa (não rola) ──
          Row(
            children: [
              Expanded(child: _legendWidget(_barProg, 'Prognóstico')),
              Expanded(child: _legendWidget(_barReal, 'Realizado')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _legendWidget(_barComp, 'Compensado')),
              Expanded(child: _legendWidget(_barFat, 'Faturado')),
            ],
          ),
          const SizedBox(height: 12),

          // ── Fundo branco só na área do gráfico ──
          Container(
            height: chartH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.fromLTRB(4, 10, 8, 4),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.25,
                groupsSpace: isLandscape ? 14 : 8,
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchCallback: (event, response) {
                    // Limpa o tooltip ao soltar (tap up, pan end, long press end)
                    if (event is FlTapUpEvent ||
                        event is FlPanEndEvent ||
                        event is FlLongPressEnd) {
                      if (_touchedDashboardGroupIndex != null) {
                        setState(() => _touchedDashboardGroupIndex = null);
                      }
                      return;
                    }

                    final spot = response?.spot;
                    if (!event.isInterestedForInteractions || spot == null) {
                      if (_touchedDashboardGroupIndex != null) {
                        setState(() => _touchedDashboardGroupIndex = null);
                      }
                      return;
                    }

                    final touched = spot.touchedBarGroupIndex;
                    if (_touchedDashboardGroupIndex != touched) {
                      setState(() => _touchedDashboardGroupIndex = touched);
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => _bgMid,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, gi, rod, ri) {
                      final idx = group.x.toInt();
                      if (idx < 0 || idx >= meses.length) return null;

                      final prog =
                          group.barRods.isNotEmpty ? group.barRods[0].toY : 0.0;
                      final real =
                          group.barRods.length > 1 ? group.barRods[1].toY : 0.0;
                      final comp =
                          group.barRods.length > 2 ? group.barRods[2].toY : 0.0;
                      final fat =
                          group.barRods.length > 3 ? group.barRods[3].toY : 0.0;

                      return BarTooltipItem(
                        '${meses[idx]}\n',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: '■ ',
                            style: const TextStyle(color: _barProg),
                          ),
                          TextSpan(
                            text: 'Prognóstico: ${_fmtBR(prog)} kWh\n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '■ ',
                            style: const TextStyle(color: _barReal),
                          ),
                          TextSpan(
                            text: 'Realizado: ${_fmtBR(real)} kWh\n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '■ ',
                            style: const TextStyle(color: _barComp),
                          ),
                          TextSpan(
                            text: 'Compensado: ${_fmtBR(comp)} kWh\n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: '■ ',
                            style: const TextStyle(color: _barFat),
                          ),
                          TextSpan(
                            text: 'Faturado: ${_fmtBR(fat)} kWh',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
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
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= meses.length) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            meses[i],
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: (maxY * 1.25) / 5,
                      getTitlesWidget: (v, m) => Text(
                        _short(v),
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF6b7280)),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFe5e7eb),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _graficoData.asMap().entries.map((e) {
                  final d = e.value;
                  final rods = [
                    _rod(_toDouble(d['prognostico']), _barProg, barW),
                    _rod(_toDouble(d['realizado_inversor']), _barReal, barW),
                    _rod(_toDouble(d['compensado']), _barComp, barW),
                    _rod(_toDouble(d['faturado']), _barFat, barW),
                  ];
                  return BarChartGroupData(
                    x: e.key,
                    groupVertically: false,
                    barRods: rods,
                    barsSpace: 0,
                    showingTooltipIndicators:
                        _touchedDashboardGroupIndex == e.key
                            ? List<int>.generate(rods.length, (i) => i)
                            : const [],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartRodData _rod(double value, Color color, double width) =>
      BarChartRodData(
        toY: value,
        color: color,
        width: width,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(3),
        ),
      );

  Widget _legendWidget(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
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

  // ── SECTION HEADER ─────────────────────────────────────────────────────────

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgMid,
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: _accent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _accent, size: 13),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              )),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  // ── ANO DROPDOWN ───────────────────────────────────────────────────────────

  Widget _anoDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _anoSelecionado,
          dropdownColor: _bgMid,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          iconEnabledColor: _accent,
          iconSize: 14,
          items: [2026, 2025]
              .map((a) => DropdownMenuItem(
                    value: a,
                    child: Text('$a'),
                  ))
              .toList(),
          onChanged: (a) {
            if (a == null) return;
            setState(() => _anoSelecionado = a);
            _loadDashboard();
          },
        ),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  double _padding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 12;
    if (w < 600) return 14;
    if (w < 900) return 16;
    return 20;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Formato brasileiro com 2 casas decimais: 1.234,56
  String _fmtBR(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final dec = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
    }
    return '${buffer.toString()},$dec';
  }

  String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

// ── MODELOS AUXILIARES ────────────────────────────────────────────────────────

class _CardData {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String? sub;
  final bool negative;
  final Color? valueColor;

  const _CardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.sub,
    this.negative = false,
    this.valueColor,
  });
}
