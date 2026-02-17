import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/usina.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _loadGeradores();
  }

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
    setState(() => _isLoadingDashboard = true);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingGeradores) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    return Container(
      color: const Color(0xFF001f2e),
      child: Column(
        children: [
          // ── SELECIONE O GERADOR ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              _getResponsivePadding(context),
              8,
              _getResponsivePadding(context),
              0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF004D66),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _geradorSelecionado != null
                      ? AppColors.accent
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _geradorSelecionado,
                  isExpanded: true,
                  hint: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.solar_power_rounded,
                          color: Color(0xFFFFB800), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Geradores',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.expand_more,
                      color: AppColors.accent, size: 24),
                  dropdownColor: const Color(0xFF003a4d),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  items: _geradores.map((gerador) {
                    return DropdownMenuItem<String>(
                      value: gerador.codigoGerador,
                      child: Row(
                        children: [
                          const Icon(Icons.solar_power_outlined,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(gerador.codigoGerador),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _selecionarGerador(value);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── CARDS / GRÁFICO ──
          Expanded(
            child: _isLoadingDashboard
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  )
                : _dashboardData == null
                    ? _emptyState()
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          _getResponsivePadding(context),
                          0,
                          _getResponsivePadding(context),
                          _getResponsivePadding(context),
                        ),
                        children: [
                          _buildCards(),
                          const SizedBox(height: 12),
                          _sectionHeader(
                            icon: Icons.bar_chart_rounded,
                            title: 'Geração Mensal  •  kWh',
                            trailing: _anoDropdown(),
                          ),
                          const SizedBox(height: 12),
                          _buildGrafico(),
                          const SizedBox(height: 16),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ── RESPONSIVIDADE ──
  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 12;
    if (width < 600) return 14;
    if (width < 900) return 16;
    return 20;
  }

  // ── SECTION HEADER ──
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF003a4d),
        borderRadius: BorderRadius.circular(6),
        border:
            const Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 12),
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

  // ── EMPTY STATE ──
  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, color: Colors.white24, size: 40),
          SizedBox(height: 10),
          Text('Selecione um gerador para ver os dados',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── 6 CARDS ──
  Widget _buildCards() {
    final d = _dashboardData!;
    final items = [
      _Card(
        icon: Icons.savings_outlined,
        label: 'Crédito Acumulado',
        value: _fmtCard(d.creditoAcumulado),
        unit: 'kWh',
        sub: 'Mês vigente',
      ),
      _Card(
        icon: Icons.people_outline,
        label: 'Beneficiários',
        value: '${d.totalBeneficiarios}',
        unit: 'ativos',
      ),
      _Card(
        icon: Icons.receipt_long_outlined,
        label: 'Ticket Médio',
        value: 'R\$ ${_fmtCard(d.ticketMedio)}',
        unit: 'por beneficiário',
      ),
      _Card(
        icon: Icons.bolt_outlined,
        label: 'Capacidade Total',
        value: _fmtCard(d.capacidadeTotal),
        unit: 'kWh',
      ),
      _Card(
        icon: Icons.track_changes_outlined,
        label: 'Performance Alvo',
        value: _fmtCard(d.performanceAlvo),
        unit: 'kWh',
      ),
      _Card(
        icon: Icons.sell_outlined,
        label: 'Disponível p/ Venda',
        value: _fmtCard(d.disponivelVenda.abs()),
        unit: 'kWh',
        negative: d.disponivelVenda < 0,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 1.8,
      children: items.map(_cardWidget).toList(),
    );
  }

  Widget _cardWidget(_Card c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF003a4d),
        borderRadius: BorderRadius.circular(6),
        border:
            const Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(c.icon, size: 14, color: AppColors.accent),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.negative ? const Color(0xFFe53935) : Colors.white,
                ),
              ),
              Text(
                c.sub ?? c.unit,
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ANO DROPDOWN ──
  Widget _anoDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF004D66),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _anoSelecionado,
          dropdownColor: const Color(0xFF003a4d),
          style: const TextStyle(color: Colors.white, fontSize: 11),
          iconEnabledColor: AppColors.accent,
          iconSize: 12,
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

  // ── GRÁFICO ──
  Widget _buildGrafico() {
    if (_graficoData.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Sem dados para o período',
              style: TextStyle(color: Color(0xFF9ca3af))),
        ),
      );
    }

    final meses = [
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
      final r = _toDouble(d['realizado_inversor']);
      final p = _toDouble(d['prognostico']);
      final c = _toDouble(d['compensado']);
      final f = _toDouble(d['faturado']);
      if (r > maxY) maxY = r;
      if (p > maxY) maxY = p;
      if (c > maxY) maxY = c;
      if (f > maxY) maxY = f;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Legenda
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legend(const Color(0xFF004D66), 'Prognóstico'),
                  const SizedBox(width: 28),
                  _legend(AppColors.accent, 'Realizado'),
                  const SizedBox(width: 28),
                  _legend(const Color(0xFF10b981), 'Faturado'),
                  const SizedBox(width: 28),
                  _legend(const Color(0xFFef4444), 'Compensado'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 380,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _graficoData.length < 8
                    ? null
                    : MediaQuery.of(context).size.width *
                        (_graficoData.length / 6),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceBetween,
                    maxY: maxY * 1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: const Color(0xFF003a4d),
                        getTooltipItem: (group, gi, rod, ri) {
                          final labels = [
                            'Prognóstico',
                            'Realizado',
                            'Faturado',
                            'Compensado'
                          ];
                          final label =
                              ri < labels.length ? labels[ri] : 'Desconhecido';
                          return BarTooltipItem(
                            '${meses[gi]}\n$label\n${_fmt(rod.toY)} kWh',
                            const TextStyle(color: Colors.white, fontSize: 11),
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
                            if (i < 0 || i >= meses.length) {
                              return const Text('');
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(meses[i],
                                  style: const TextStyle(
                                      fontSize: 9, color: Color(0xFF6b7280))),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: maxY * 1.2 / 5,
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
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: _toDouble(d['prognostico']),
                            color: const Color(0xFF004D66),
                            width: 7,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: _toDouble(d['realizado_inversor']),
                            color: AppColors.accent,
                            width: 7,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: _toDouble(d['faturado']),
                            color: const Color(0xFF10b981),
                            width: 7,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                          BarChartRodData(
                            toY: _toDouble(d['compensado']),
                            color: const Color(0xFFef4444),
                            width: 7,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6b7280))),
      ],
    );
  }

  // ── HELPERS ──
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _fmt(double v) {
    if (v >= 1000) {
      return '${'${(v / 1000).toStringAsFixed(1)}'.replaceAll('.', ',')}k';
    }
    return v.toStringAsFixed(v % 1 == 0 ? 0 : 2).replaceAll('.', ',');
  }

  String _fmtCard(double v) {
    // Formata número para o padrão brasileiro com separador de milhar
    final formatted = v.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decimalPart = parts[1];

    // Adiciona ponto como separador de milhar
    String result = '';
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        result += '.';
      }
      result += intPart[i];
    }

    return '$result,$decimalPart';
  }

  String _short(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

// Helper para os cards
class _Card {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String? sub;
  final bool negative;
  _Card({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.sub,
    this.negative = false,
  });
}
