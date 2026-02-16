import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/usina.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';

// ═══════════════════════════════════════════════
// ABA USINAS — replica /investidor/usinas
// ═══════════════════════════════════════════════

class UsinasTab extends StatefulWidget {
  const UsinasTab({super.key});

  @override
  State<UsinasTab> createState() => UsinasTabState();
}

class UsinasTabState extends State<UsinasTab> {
  // ── Estado ──
  List<Gerador> _geradores = [];
  String? _geradorSelecionado;
  List<Usina> _usinas = [];

  // Período atual: dia | periodo | mes | ano
  String _periodo = 'dia';

  // Seletores de data
  DateTime _diaSelecionado = DateTime.now();
  DateTime _periodoInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _periodoFim = DateTime.now();
  String _mesSelecionado =
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
  int _anoSelecionado = DateTime.now().year;

  // Dados
  Map<String, dynamic>? _statsData;
  Map<String, dynamic>? _chartData;

  // Loading
  bool _loadingGeradores = true;
  bool _loadingDados = false;

  @override
  void initState() {
    super.initState();
    _loadGeradores();
  }

  Future<void> refresh() async {
    await _loadGeradores();
    if (_geradorSelecionado != null) {
      await _loadUsinas();
      await _loadDesempenho();
    }
  }

  // ── CARREGAR GERADORES ──
  Future<void> _loadGeradores() async {
    setState(() => _loadingGeradores = true);
    try {
      final geradores = await ApiService.getGeradores();
      setState(() {
        _geradores = geradores;
        _loadingGeradores = false;
      });
      // Auto-selecionar se só 1
      if (geradores.length == 1) {
        _selecionarGerador(geradores.first.codigoGerador);
      }
    } catch (e) {
      setState(() => _loadingGeradores = false);
      _showError('Erro ao carregar geradores: $e');
    }
  }

  // ── SELECIONAR GERADOR ──
  Future<void> _selecionarGerador(String codigo) async {
    setState(() {
      _geradorSelecionado = codigo;
      _statsData = null;
      _chartData = null;
    });
    await _loadUsinas();
    await _loadDesempenho();
  }

  // ── CARREGAR USINAS DO GERADOR ──
  Future<void> _loadUsinas() async {
    try {
      final all = await ApiService.getUsinasInvestidor();
      setState(() {
        _usinas =
            all.where((u) => u.codigoGerador == _geradorSelecionado).toList();
      });
    } catch (_) {}
  }

  // ── CARREGAR DESEMPENHO (agrega múltiplas usinas) ──
  Future<void> _loadDesempenho() async {
    if (_geradorSelecionado == null || _usinas.isEmpty) return;
    setState(() => _loadingDados = true);

    try {
      // Buscar desempenho de cada usina em paralelo
      final futures = _usinas.map((u) => ApiService.getDesempenhoInvestidor(
            u.idPlanta,
            periodo: _periodo,
            data: _periodo == 'dia'
                ? '${_diaSelecionado.year}-${_diaSelecionado.month.toString().padLeft(2, '0')}-${_diaSelecionado.day.toString().padLeft(2, '0')}'
                : null,
            mes: _periodo == 'mes' ? _mesSelecionado : null,
            ano: _periodo == 'ano' ? '$_anoSelecionado' : null,
            dataInicio: _periodo == 'periodo'
                ? '${_periodoInicio.year}-${_periodoInicio.month.toString().padLeft(2, '0')}-${_periodoInicio.day.toString().padLeft(2, '0')}'
                : null,
            dataFim: _periodo == 'periodo'
                ? '${_periodoFim.year}-${_periodoFim.month.toString().padLeft(2, '0')}-${_periodoFim.day.toString().padLeft(2, '0')}'
                : null,
          ));

      final results = await Future.wait(futures);
      final agregado = _agregarDados(results);

      setState(() {
        _statsData = agregado['stats'];
        _chartData = agregado['chart'];
        _loadingDados = false;
      });
    } catch (e) {
      setState(() => _loadingDados = false);
      _showError('Erro ao carregar dados: $e');
    }
  }

  // ── AGREGAR DADOS DE MÚLTIPLAS USINAS ──
  Map<String, dynamic> _agregarDados(List<Map<String, dynamic>> results) {
    double producaoTotal = 0;
    double potenciaMaxima = 0;
    double horasOperacao = 0;

    List<String> labels = [];
    List<double> producao = [];
    List<double> prognostico = [];

    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      if (r['success'] != true) continue;

      final stats = r['stats'] as Map<String, dynamic>;
      producaoTotal += _toDouble(stats['producao_total']);
      final pm = _toDouble(stats['potencia_maxima']);
      if (pm > potenciaMaxima) potenciaMaxima = pm;
      horasOperacao += _toDouble(stats['horas_operacao']);

      final chart = r['chart'] as Map<String, dynamic>;
      if (i == 0) {
        labels = List<String>.from(chart['labels'] ?? []);
        final raw = chart['producao'] ?? chart['potencia'] ?? [];
        producao = List<double>.from((raw as List).map((v) => _toDouble(v)));
        if (chart['prognostico'] != null) {
          prognostico = List<double>.from(
              (chart['prognostico'] as List).map((v) => _toDouble(v)));
        }
      } else {
        final raw = chart['producao'] ?? chart['potencia'] ?? [];
        final extra = List<double>.from((raw as List).map((v) => _toDouble(v)));
        for (int j = 0; j < producao.length && j < extra.length; j++) {
          producao[j] += extra[j];
        }
        if (chart['prognostico'] != null && prognostico.isNotEmpty) {
          final extraProg = List<double>.from(
              (chart['prognostico'] as List).map((v) => _toDouble(v)));
          for (int j = 0; j < prognostico.length && j < extraProg.length; j++) {
            prognostico[j] += extraProg[j];
          }
        }
      }
    }

    // Calcular média igual ao sistema web
    double media = 0;
    if (_periodo == 'dia') {
      media = producaoTotal / 24;
    } else if (_periodo == 'mes') {
      final parts = _mesSelecionado.split('-');
      final diasNoMes =
          DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 0).day;
      media = producaoTotal / diasNoMes;
    } else if (_periodo == 'ano') {
      media = producaoTotal / 12;
    } else if (_periodo == 'periodo') {
      final diff = _periodoFim.difference(_periodoInicio).inDays + 1;
      media = producaoTotal / diff;
    }

    // Calcular desempenho (%)
    List<double?> desempenho = [];
    if (prognostico.isNotEmpty && _periodo != 'dia') {
      for (int i = 0; i < producao.length; i++) {
        final prog = i < prognostico.length ? prognostico[i] : 0;
        final prod = producao[i];
        final percent = prog > 0 ? (prod / prog) * 100 : null;
        desempenho.add(percent);
      }
    }

    return {
      'stats': {
        'producao_total': producaoTotal,
        'potencia_maxima': potenciaMaxima,
        'horas_operacao': horasOperacao,
        'producao_media': media,
      },
      'chart': {
        'labels': labels,
        'producao': producao,
        'prognostico': prognostico.isNotEmpty ? prognostico : null,
        'desempenho': desempenho.isNotEmpty ? desempenho : null,
      }
    };
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _fmtNum(double v) {
    if (v >= 1000) {
      return v.toStringAsFixed(1).replaceAll('.', ',').replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          );
    }
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF001f2e),
      child: Column(
        children: [
          // ── TOPO FIXO: GERADORES ──
          _buildTopSection(),

          // ── CONTEÚDO SCROLLÁVEL ──
          Expanded(
            child: _geradorSelecionado == null
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                    children: [
                      // Card gráfico
                      _buildChartCard(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── TOPO FIXO ──
  Widget _buildTopSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF001f2e).withOpacity(0.95),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Geradores
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: _loadingGeradores
                ? const SizedBox(
                    height: 50,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : Container(
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
                        hint: const Text(
                          'Usinas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
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
        ],
      ),
    );
  }

  // ── EMPTY STATE ──
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.area_chart_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text(
            'Selecione uma usina para\nvisualizar os dados',
            style: TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── CARD PRINCIPAL (PERÍODO + STATS + GRÁFICO) ──
  Widget _buildChartCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
          )
        ],
      ),
      child: Column(
        children: [
          // Header do card
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF003a4d),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                    color: AppColors.accent.withOpacity(0.3), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.show_chart, color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  _geradorSelecionado != null
                      ? 'Geração - $_geradorSelecionado'
                      : 'Geração de Energia',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Botões de período
          _buildPeriodButtons(),

          // Seletores de data
          _buildDateSelectors(),

          // Stats row (4 cards)
          if (_loadingDados)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_statsData != null) ...[
            _buildStatsRow(),
            _buildGrafico(),
          ] else
            Container(
              height: 200,
              alignment: Alignment.center,
              child: const Text(
                'Carregando...',
                style: TextStyle(color: Color(0xFF6b7280)),
              ),
            ),
        ],
      ),
    );
  }

  // ── BOTÕES DE PERÍODO ──
  Widget _buildPeriodButtons() {
    final periodos = [
      {'key': 'dia', 'label': 'Hoje'},
      {'key': 'periodo', 'label': 'Período'},
      {'key': 'mes', 'label': 'Mês'},
      {'key': 'ano', 'label': 'Ano'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF003a4d),
        border: Border(
          bottom:
              BorderSide(color: AppColors.accent.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: periodos.map((p) {
          final active = _periodo == p['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _periodo = p['key']!;
                  _statsData = null;
                  _chartData = null;
                });
                _loadDesempenho();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : const Color(0xFF004D66),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: active ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  p['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: active ? const Color(0xFF004D66) : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── SELETORES DE DATA ──
  Widget _buildDateSelectors() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF003a4d),
      ),
      child: Row(
        children: [
          if (_periodo == 'dia')
            Expanded(
                child: _datePicker(
              label: _fmtDate(_diaSelecionado),
              onTap: () => _pickDate(
                initial: _diaSelecionado,
                onPicked: (d) {
                  setState(() => _diaSelecionado = d);
                  _loadDesempenho();
                },
              ),
            )),
          if (_periodo == 'periodo') ...[
            Expanded(
                child: _datePicker(
              label: _fmtDate(_periodoInicio),
              onTap: () => _pickDate(
                initial: _periodoInicio,
                onPicked: (d) {
                  setState(() => _periodoInicio = d);
                  _loadDesempenho();
                },
              ),
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _datePicker(
              label: _fmtDate(_periodoFim),
              onTap: () => _pickDate(
                initial: _periodoFim,
                onPicked: (d) {
                  setState(() => _periodoFim = d);
                  _loadDesempenho();
                },
              ),
            )),
          ],
          if (_periodo == 'mes')
            Expanded(
                child: _datePicker(
              label: _mesSelecionado,
              onTap: () => _pickMonth(),
            )),
          if (_periodo == 'ano')
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _anoSelector(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF004D66),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 12, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _anoSelector() {
    final years = [2026, 2025, 2024];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF004D66),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _anoSelecionado,
          isExpanded: true,
          isDense: true,
          dropdownColor: const Color(0xFF003a4d),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          iconEnabledColor: AppColors.accent,
          iconSize: 18,
          items: years
              .map((a) => DropdownMenuItem(
                    value: a,
                    child: Center(child: Text('$a')),
                  ))
              .toList(),
          selectedItemBuilder: (context) => years
              .map((a) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text('$a'),
                    ],
                  ))
              .toList(),
          onChanged: (a) {
            if (a == null) return;
            setState(() => _anoSelecionado = a);
            _loadDesempenho();
          },
        ),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF004D66),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickMonth() async {
    final parts = _mesSelecionado.split('-');
    int year = int.parse(parts[0]);
    int month = int.parse(parts[1]);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF003a4d),
        title: const Text('Selecionar Mês',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: SizedBox(
          width: 280,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2,
            children: List.generate(12, (i) {
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
              final isSelected = (i + 1) == month;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _mesSelecionado =
                        '$year-${(i + 1).toString().padLeft(2, '0')}';
                  });
                  _loadDesempenho();
                  Navigator.pop(ctx);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isSelected ? AppColors.accent : const Color(0xFF004D66),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    meses[i],
                    style: TextStyle(
                      color:
                          isSelected ? const Color(0xFF003E52) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: Colors.white70, size: 18),
                onPressed: () {
                  setState(() {
                    year--;
                    _mesSelecionado =
                        '$year-${month.toString().padLeft(2, '0')}';
                  });
                  Navigator.pop(ctx);
                  _pickMonth();
                },
              ),
              Text('$year',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.arrow_forward,
                    color: Colors.white70, size: 18),
                onPressed: () {
                  if (year < DateTime.now().year) {
                    setState(() {
                      year++;
                      _mesSelecionado =
                          '$year-${month.toString().padLeft(2, '0')}';
                    });
                    Navigator.pop(ctx);
                    _pickMonth();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── STATS ROW (4 métricas) ──
  Widget _buildStatsRow() {
    final s = _statsData!;
    final items = [
      {
        'label': 'PRODUÇÃO TOTAL',
        'value': _fmtNum(_toDouble(s['producao_total'])),
        'unit': 'kWh'
      },
      {
        'label': 'POTÊNCIA MÁX',
        'value': _fmtNum(_toDouble(s['potencia_maxima'])),
        'unit': 'kW'
      },
      {
        'label': 'HORAS OP.',
        'value': _fmtNum(_toDouble(s['horas_operacao'])),
        'unit': 'horas'
      },
      {
        'label': 'MÉDIA',
        'value': _fmtNum(_toDouble(s['producao_media'])),
        'unit': 'kWh'
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFe5e7eb)),
          bottom: BorderSide(color: Color(0xFFe5e7eb)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: Column(
              children: [
                Text(
                  item['label']!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6b7280),
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  item['value']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF004D66),
                  ),
                ),
                Text(
                  item['unit']!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9ca3af),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── GRÁFICO ──
  Widget _buildGrafico() {
    final chart = _chartData;
    if (chart == null) return const SizedBox.shrink();

    final labels = chart['labels'] as List<String>;
    final producao = chart['producao'] as List<double>;
    final prognostico = chart['prognostico'] as List<double>?;

    final isDia = _periodo == 'dia';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Legenda (quando há múltiplas séries)
          if (!isDia && prognostico != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendItem(const Color(0xFF004D66), 'Prognóstico'),
                  const SizedBox(width: 16),
                  _legendItem(AppColors.accent, 'Produção'),
                ],
              ),
            ),

          SizedBox(
            height: 280,
            child: isDia
                ? _buildLineChart(labels, producao)
                : _buildBarChart(labels, producao, prognostico),
          ),
        ],
      ),
    );
  }

  // ── GRÁFICO DE LINHA (período = dia) ──
  Widget _buildLineChart(List<String> labels, List<double> producao) {
    double maxY =
        producao.isEmpty ? 10 : producao.reduce((a, b) => a > b ? a : b) * 1.2;

    // Mostrar rótulos a cada 2 horas no eixo X
    final step = 2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xFF003a4d),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${labels[s.x.toInt()]}\n${_fmtNum(s.y)} kW',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ))
                .toList(),
          ),
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
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length || i % step != 0) {
                  return const Text('');
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(labels[i],
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF374151))),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, m) => Text(
                _fmtNum(v),
                style: const TextStyle(fontSize: 9, color: Color(0xFF6b7280)),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: producao
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            curveSmoothness: 0.4,
            color: const Color(0xFF004D66),
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFF004D66),
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }

  // ── GRÁFICO DE BARRAS (período = mes/ano/periodo) ──
  Widget _buildBarChart(
    List<String> labels,
    List<double> producao,
    List<double>? prognostico,
  ) {
    double maxY = 0;
    for (final v in producao) {
      if (v > maxY) maxY = v;
    }
    if (prognostico != null) {
      for (final v in prognostico) {
        if (v > maxY) maxY = v;
      }
    }

    // Arredondar maxY para evitar sobreposição de valores no eixo
    final isAno = _periodo == 'ano';
    if (isAno) {
      maxY = ((maxY / 1000).ceil() * 1000).toDouble() * 1.08;
    } else {
      maxY *= 1.2;
    }

    // Calcular maxY para porcentagem baseado no maior valor de produção
    double maxYPercentage = 100;
    if (prognostico != null && prognostico.isNotEmpty) {
      // Encontrar o maior valor de produção
      double maxProducao = 0;
      int maxProducaoIndex = 0;
      for (int i = 0; i < producao.length; i++) {
        if (producao[i] > maxProducao) {
          maxProducao = producao[i];
          maxProducaoIndex = i;
        }
      }
      // Calcular a porcentagem do maior valor de produção e aplicar o mesmo fator 1.2
      if (maxProducaoIndex < prognostico.length &&
          prognostico[maxProducaoIndex] > 0) {
        maxYPercentage =
            (maxProducao / prognostico[maxProducaoIndex]) * 100 * 1.2;
      }
      // Arredondar para cima para o próximo número terminando em 5 ou 0
      maxYPercentage = ((maxYPercentage / 5).ceil() * 5).toDouble();
      if (maxYPercentage > 120) maxYPercentage = 120;
    }

    final step = (labels.length / 6).ceil().clamp(1, 999);
    final isMes = _periodo == 'mes';
    final isPeriodo = _periodo == 'periodo';
    final splitMesGroups = isMes && prognostico != null;
    final barWidth = isMes ? 5.0 : (isAno ? 8.0 : 7.0);
    final singleBarWidth = isMes ? 6.5 : (isAno ? 14.0 : 14.0);
    final barsSpace = isMes ? 2.0 : (isAno ? 0.5 : 4.0);
    final groupsSpace = isMes ? 1.0 : (isAno ? 3.0 : 12.0);
    final hasPrognostico = prognostico != null && prognostico.isNotEmpty;

    return BarChart(
      BarChartData(
        alignment: isMes
            ? BarChartAlignment.spaceEvenly
            : (isAno
                ? BarChartAlignment.center
                : BarChartAlignment.spaceAround),
        maxY: maxY,
        groupsSpace: groupsSpace,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: const Color(0xFF003a4d),
            getTooltipItem: (group, gi, rod, ri) {
              final label = labels[gi];
              final name = ri == 0 ? 'Prognóstico' : 'Produção';
              return BarTooltipItem(
                '$label\n$name\n${_fmtNum(rod.toY)} kWh',
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
                if (splitMesGroups) {
                  if (i % 2 != 0) return const Text('');
                  final labelIndex = i ~/ 2;
                  if (labelIndex < 0 ||
                      labelIndex >= labels.length ||
                      labelIndex % 3 != 0) {
                    return const Text('');
                  }
                  String lbl = labels[labelIndex];
                  if (lbl.startsWith('Dia ')) {
                    lbl = lbl.replaceFirst('Dia ', '');
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(lbl,
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF374151))),
                  );
                }

                // Para o período anual, mostrar todos os meses
                if (isAno) {
                  if (i < 0 || i >= labels.length) {
                    return const Text('');
                  }
                  String lbl = labels[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(lbl,
                        style: const TextStyle(
                            fontSize: 8, color: Color(0xFF374151))),
                  );
                }

                if (isPeriodo) {
                  if (i < 0 || i >= labels.length) {
                    return const Text('');
                  }
                  String lbl = labels[i];
                  if (lbl.startsWith('Dia ')) {
                    lbl = lbl.replaceFirst('Dia ', '');
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(lbl,
                        style: const TextStyle(
                            fontSize: 8, color: Color(0xFF374151))),
                  );
                }

                if (i < 0 || i >= labels.length || i % step != 0) {
                  return const Text('');
                }
                String lbl = labels[i];
                if (lbl.startsWith('Dia ')) {
                  lbl = lbl.replaceFirst('Dia ', '');
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(lbl,
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF374151))),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, m) => Text(
                _shortNum(v),
                style: const TextStyle(fontSize: 9, color: Color(0xFF6b7280)),
              ),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: hasPrognostico,
              reservedSize: 36,
              getTitlesWidget: (v, m) {
                // Converter do eixo esquerdo (kWh) para porcentagem
                final percentage = (v / maxY) * maxYPercentage;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFFef4444),
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
        barGroups: splitMesGroups
            ? labels.asMap().entries.expand((e) {
                final prod = e.key < producao.length ? producao[e.key] : 0.0;
                final prog =
                    e.key < prognostico.length ? prognostico[e.key] : 0.0;
                return [
                  BarChartGroupData(
                    x: e.key * 2,
                    barRods: [
                      BarChartRodData(
                        toY: prog,
                        color: const Color(0xFF004D66),
                        width: barWidth,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: e.key * 2 + 1,
                    barRods: [
                      BarChartRodData(
                        toY: prod,
                        color: AppColors.accent,
                        width: barWidth,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ];
              }).toList()
            : producao.asMap().entries.map((e) {
                final rods = <BarChartRodData>[];
                if (prognostico != null && e.key < prognostico.length) {
                  rods.add(BarChartRodData(
                    toY: prognostico[e.key],
                    color: const Color(0xFF004D66),
                    width: barWidth,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(3),
                    ),
                  ));
                }
                rods.add(BarChartRodData(
                  toY: e.value,
                  color: AppColors.accent,
                  width: prognostico != null ? barWidth : singleBarWidth,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ));
                return BarChartGroupData(
                  x: e.key,
                  barRods: rods,
                  barsSpace: barsSpace,
                );
              }).toList(),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
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

  String _shortNum(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}
