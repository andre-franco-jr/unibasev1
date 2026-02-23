import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/usina.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta
// ─────────────────────────────────────────────────────────────────────────────
const _bgDark = Color(0xFF001f2e);
const _bgMid = Color(0xFF003a4d);
const _bgCard = Color(0xFF004D66);
const _accent = Color(0xFFEAC248);
const _barProd = Color(0xFFEAC248); // Produção  → dourado
const _barProg = Color(0xFF004D66); // Prognóstico → azul-escuro
const _lineDesemp = Color(0xFFef4444); // Desempenho → vermelho

// reservedSize compartilhados entre BarChart e LineChart overlay
// CRÍTICO: devem ser idênticos nos dois widgets para a área de plot alinhar
const double _leftR = 40.0;
const double _rightR = 38.0;
const double _bottomR = 20.0;

// ─────────────────────────────────────────────────────────────────────────────

// CustomPainter para desenhar a linha de desempenho sobre o BarChart
class DesempenhoLinePainter extends CustomPainter {
  final List<double> desempData; // valores de desempenho em %
  final double maxY; // escala Y máxima do gráfico
  final double maxDesemp; // 120.0
  final int nGroups; // número de grupos/barras
  final Color lineColor;
  final double leftReserved;
  final double rightReserved;
  final double bottomReserved;
  final BarChartAlignment alignment;
  final double groupsSpace;

  DesempenhoLinePainter({
    required this.desempData,
    required this.maxY,
    required this.maxDesemp,
    required this.nGroups,
    required this.lineColor,
    required this.leftReserved,
    required this.rightReserved,
    required this.bottomReserved,
    required this.alignment,
    required this.groupsSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (desempData.isEmpty) return;

    final plotWidth = size.width - leftReserved - rightReserved;
    final plotHeight = size.height - bottomReserved;
    final plotLeft = leftReserved;
    final plotTop = 0.0;

    // Calcular a largura de cada grupo e espaçamento
    final groupWidth = plotWidth / nGroups;

    // Converter dados de desempenho para pontos no canvas
    final points = <Offset>[];
    for (int i = 0; i < desempData.length; i++) {
      final desemp = desempData[i];

      // Posição X: centro de cada grupo
      final xInPlot = (i + 0.5) * groupWidth;
      final xPixel = plotLeft + xInPlot;

      // Posição Y: escalar de 0-120% para plotHeight
      final yValue = (desemp / maxDesemp) * maxY;
      final yInPlot = plotHeight - (yValue / maxY) * plotHeight;
      const yOffsetPx = 6.0;
      final shiftedY = plotTop + yInPlot + yOffsetPx;
      final yPixel = shiftedY
          .clamp(
            plotTop + 3.5,
            plotTop + plotHeight - 3.5,
          )
          .toDouble();

      points.add(Offset(xPixel, yPixel));
    }

    // Desenhar a linha conectando os pontos com suavização
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Desenhar linha com curvatura suave
    if (points.length >= 2) {
      final path = _createSmoothPath(points);
      canvas.drawPath(path, paint);
    }

    // Desenhar pontos nos dados
    final dotPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3.5, fillPaint);
      canvas.drawCircle(point, 3.5, dotPaint);
    }
  }

  // Criar um path suave usando interpolação cúbica de Hermite
  Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points[0].dx, points[0].dy);

    if (points.length == 1) {
      return path;
    }

    // Usar quadratic Bezier para suavidade
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      final controlY = (p0.dy + p1.dy) / 2;

      path.quadraticBezierTo(controlX, controlY, p1.dx, p1.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(DesempenhoLinePainter oldDelegate) {
    return oldDelegate.desempData != desempData ||
        oldDelegate.maxY != maxY ||
        oldDelegate.nGroups != nGroups;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class UsinasTab extends StatefulWidget {
  const UsinasTab({super.key});

  @override
  State<UsinasTab> createState() => UsinasTabState();
}

class UsinasTabState extends State<UsinasTab> {
  // ── Estado ──────────────────────────────────────────────────────────────────
  List<Gerador> _geradores = [];
  String? _geradorSelecionado;
  List<Usina> _usinas = [];

  String _periodo = 'dia';
  DateTime _diaSelecionado = DateTime.now();
  DateTime _periodoInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _periodoFim = DateTime.now();
  String _mesSelecionado =
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
  int _anoSelecionado = DateTime.now().year;

  Map<String, dynamic>? _statsData;
  Map<String, dynamic>? _chartData;

  bool _loadingGeradores = true;
  bool _loadingDados = false;
  int? _touchedBarGroupIndex;

  // ── INIT ────────────────────────────────────────────────────────────────────
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

  // ── CARREGAMENTO DE DADOS ───────────────────────────────────────────────────

  Future<void> _loadGeradores() async {
    setState(() => _loadingGeradores = true);
    try {
      final geradores = await ApiService.getGeradores();
      if (!mounted) return;
      setState(() {
        _geradores = geradores;
        _loadingGeradores = false;
      });
      if (geradores.length == 1) {
        _selecionarGerador(geradores.first.codigoGerador);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingGeradores = false);
      _showError('Erro ao carregar geradores: $e');
    }
  }

  Future<void> _selecionarGerador(String codigo) async {
    setState(() {
      _geradorSelecionado = codigo;
      _statsData = null;
      _chartData = null;
    });
    await _loadUsinas();
    await _loadDesempenho();
  }

  Future<void> _loadUsinas() async {
    try {
      final all = await ApiService.getUsinasInvestidor();
      if (!mounted) return;
      setState(() {
        _usinas =
            all.where((u) => u.codigoGerador == _geradorSelecionado).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadDesempenho() async {
    if (_geradorSelecionado == null || _usinas.isEmpty) return;
    setState(() {
      _loadingDados = true;
      _statsData = null;
      _chartData = null;
      _touchedBarGroupIndex = null;
    });

    try {
      final dataStr = _fmt(_diaSelecionado);
      final inicioStr = _fmt(_periodoInicio);
      final fimStr = _fmt(_periodoFim);

      final futures = _usinas.map(
        (u) => ApiService.getDesempenhoInvestidor(
          u.idPlanta,
          periodo: _periodo,
          data: _periodo == 'dia' ? dataStr : null,
          mes: _periodo == 'mes' ? _mesSelecionado : null,
          ano: _periodo == 'ano' ? '$_anoSelecionado' : null,
          dataInicio: _periodo == 'periodo' ? inicioStr : null,
          dataFim: _periodo == 'periodo' ? fimStr : null,
        ),
      );

      final results = await Future.wait(futures);
      final agregado = _agregarDados(results);

      if (!mounted) return;
      setState(() {
        _statsData = agregado['stats'];
        _chartData = agregado['chart'];
        _loadingDados = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDados = false);
      _showError('Erro ao carregar dados: $e');
    }
  }

  // ── AGREGAÇÃO ───────────────────────────────────────────────────────────────
  // Lógica espelhada do web (usinas.html: agregarDados + calcularDesempenho)
  // Prognóstico e desempenho: mostrados para todos os períodos EXCETO 'dia'
  // (igual à condição do web: currentPeriod !== 'dia')

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
        producao = List<double>.from((raw as List).map(_toDouble));
        if (chart['prognostico'] != null) {
          prognostico = List<double>.from(
            (chart['prognostico'] as List).map(_toDouble),
          );
        }
      } else {
        final raw = chart['producao'] ?? chart['potencia'] ?? [];
        final extra = List<double>.from((raw as List).map(_toDouble));
        for (int j = 0; j < producao.length && j < extra.length; j++) {
          producao[j] += extra[j];
        }
        if (chart['prognostico'] != null && prognostico.isNotEmpty) {
          final ep = List<double>.from(
            (chart['prognostico'] as List).map(_toDouble),
          );
          for (int j = 0; j < prognostico.length && j < ep.length; j++) {
            prognostico[j] += ep[j];
          }
        }
      }
    }

    // Média
    double media = 0;
    if (_periodo == 'dia') {
      media = producaoTotal / 24;
    } else if (_periodo == 'mes') {
      final p = _mesSelecionado.split('-');
      final dias = DateTime(
        int.parse(p[0]),
        int.parse(p[1]) + 1,
        0,
      ).day;
      media = producaoTotal / dias;
    } else if (_periodo == 'ano') {
      media = producaoTotal / 12;
    } else if (_periodo == 'periodo') {
      final diff = _periodoFim.difference(_periodoInicio).inDays + 1;
      media = producaoTotal / diff;
    }

    // Desempenho: idêntico ao web — se há prognóstico e período != 'dia'
    final temProg = prognostico.isNotEmpty && _periodo != 'dia';
    final desempenho = <double?>[];
    if (temProg) {
      for (int i = 0; i < producao.length; i++) {
        final prog = i < prognostico.length ? prognostico[i] : 0.0;
        desempenho.add(prog > 0 ? (producao[i] / prog) * 100 : null);
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
        'prognostico': temProg ? prognostico : null,
        'desempenho': desempenho.isNotEmpty ? desempenho : null,
      },
    };
  }

  // ── UTILS ───────────────────────────────────────────────────────────────────

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

  String _fmt(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  String _fmtNum(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    final str = abs.toStringAsFixed(1);
    final p = str.split('.');
    final buf = StringBuffer();
    for (int i = 0; i < p[0].length; i++) {
      if (i > 0 && (p[0].length - i) % 3 == 0) buf.write('.');
      buf.write(p[0][i]);
    }
    return '$sign${buf.toString()},${p[1]}';
  }

  String _shortNum(double v) {
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        return Container(
          color: _bgDark,
          child: _buildContent(isLandscape),
        );
      },
    );
  }

  Widget _buildContent(bool isLandscape) {
    return ListView(
      padding: EdgeInsets.fromLTRB(14, 10, 14, isLandscape ? 8 : 16),
      children: [
        _buildDropdownGerador(),
        const SizedBox(height: 12),
        if (_geradorSelecionado == null)
          const SizedBox(
            height: 450,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.area_chart_outlined,
                      color: Colors.white24, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'Selecione uma usina para ver as informações',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          _buildChartCard(isLandscape),
      ],
    );
  }

  // ── DROPDOWN GERADOR ────────────────────────────────────────────────────────

  Widget _buildDropdownGerador() {
    if (_loadingGeradores) {
      return const SizedBox(
        height: 46,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
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
          hint: const Row(
            children: [
              Icon(Icons.solar_power_rounded, color: _accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Selecione uma Usina',
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
  }

  // ── CARD PRINCIPAL ──────────────────────────────────────────────────────────

  Widget _buildChartCard(bool isLandscape) {
    return Container(
      decoration: BoxDecoration(
        color: _bgMid,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _accent, width: 2),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.show_chart, color: _accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _geradorSelecionado != null
                        ? 'Geração — $_geradorSelecionado'
                        : 'Geração de Energia',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildPeriodButtons(),
          _buildDateSelectors(),

          if (_loadingDados)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: _accent),
              ),
            )
          else if (_statsData != null) ...[
            _buildStatsRow(),
            _buildGrafico(isLandscape),
            const SizedBox(height: 6),
          ] else
            const SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.area_chart_outlined,
                        color: Colors.white24, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'Sem dados para o período',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── BOTÕES DE PERÍODO ───────────────────────────────────────────────────────

  Widget _buildPeriodButtons() {
    const periodos = [
      {'key': 'dia', 'label': 'Hoje'},
      {'key': 'periodo', 'label': 'Período'},
      {'key': 'mes', 'label': 'Mês'},
      {'key': 'ano', 'label': 'Ano'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _accent.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: periodos.map((p) {
          final active = _periodo == p['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_periodo == p['key']!) return;
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
                  color: active ? _accent : const Color(0xFF004D66),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? const Color(0xFF003E52) : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── SELETORES DE DATA ───────────────────────────────────────────────────────

  Widget _buildDateSelectors() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
              ),
            ),
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
              ),
            ),
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
              ),
            ),
          ],
          if (_periodo == 'mes')
            Expanded(
              child: _datePicker(
                label: _mesSelecionado,
                onTap: _pickMonth,
              ),
            ),
          if (_periodo == 'ano') Expanded(child: _anoSelector()),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 12, color: _accent),
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
    const years = [2026, 2025, 2024, 2023];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _anoSelecionado,
          isExpanded: true,
          isDense: true,
          dropdownColor: _bgMid,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          iconEnabledColor: _accent,
          iconSize: 18,
          selectedItemBuilder: (context) => years
              .map(
                (a) => Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: _accent),
                    const SizedBox(width: 6),
                    Text('$a'),
                  ],
                ),
              )
              .toList(),
          items: years
              .map((a) => DropdownMenuItem(
                    value: a,
                    child: Text('$a'),
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
      locale: const Locale('pt', 'BR'),
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
      'Dez',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _bgMid,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: Colors.white70, size: 22),
                onPressed: () => setLocal(() => year--),
              ),
              Text(
                '$year',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: Colors.white70, size: 22),
                onPressed: () {
                  if (year < DateTime.now().year) {
                    setLocal(() => year++);
                  }
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 280,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: List.generate(12, (i) {
                final sel = (i + 1) == month;
                return GestureDetector(
                  onTap: () {
                    final novo = '$year-${(i + 1).toString().padLeft(2, '0')}';
                    setState(() => _mesSelecionado = novo);
                    _loadDesempenho();
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: sel ? _accent : _bgCard,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        meses[i],
                        style: TextStyle(
                          color: sel ? const Color(0xFF003E52) : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // ── STATS ROW ───────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final s = _statsData!;
    final items = [
      {
        'label': 'PRODUÇÃO',
        'value': _fmtNum(_toDouble(s['producao_total'])),
        'unit': 'kWh',
      },
      {
        'label': 'POT. MÁX',
        'value': _fmtNum(_toDouble(s['potencia_maxima'])),
        'unit': 'kW',
      },
      {
        'label': 'HORAS OP.',
        'value': _fmtNum(_toDouble(s['horas_operacao'])),
        'unit': 'h',
      },
      {
        'label': 'MÉDIA',
        'value': _fmtNum(_toDouble(s['producao_media'])),
        'unit': 'kWh',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _accent.withOpacity(0.25)),
          bottom: BorderSide(color: _accent.withOpacity(0.25)),
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
                    fontSize: 8.5,
                    color: Color(0xFFb0c4ce),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  item['value']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  item['unit']!,
                  style: const TextStyle(fontSize: 9, color: Color(0xFFb0c4ce)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── GRÁFICO ─────────────────────────────────────────────────────────────────

  Widget _buildGrafico(bool isLandscape) {
    final chart = _chartData;
    if (chart == null) return const SizedBox.shrink();

    final labels = chart['labels'] as List<String>;
    final producao = chart['producao'] as List<double>;
    final prognostico = chart['prognostico'] as List<double>?;
    final desempenho = chart['desempenho'] as List<double?>?;

    final isDia = _periodo == 'dia';
    final hasPrognostico = prognostico != null && prognostico.isNotEmpty;
    final hasDesempenho = desempenho != null && desempenho.isNotEmpty;
    final chartH = isLandscape ? 200.0 : 270.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDia) ...[
            _buildLegenda(hasPrognostico, hasDesempenho),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: chartH,
            child: isDia
                ? _buildLineChart(labels, producao)
                : _buildBarChart(
                    labels,
                    producao,
                    prognostico,
                    desempenho,
                    isLandscape,
                  ),
          ),
        ],
      ),
    );
  }

  // ── LEGENDA (Wrap — nunca quebra feio) ──────────────────────────────────────

  Widget _buildLegenda(bool hasPrognostico, bool hasDesempenho) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        if (hasPrognostico) _legendItem(_barProg, 'Prognóstico'),
        _legendItem(_barProd, 'Produção'),
        if (hasDesempenho) _legendItem(_lineDesemp, 'Desempenho %'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFFb0c4ce)),
        ),
      ],
    );
  }

  // ── LINE CHART (dia) ────────────────────────────────────────────────────────

  Widget _buildLineChart(List<String> labels, List<double> producao) {
    double maxY =
        producao.isEmpty ? 10 : producao.reduce((a, b) => a > b ? a : b) * 1.25;
    if (maxY == 0) maxY = 10;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(4, 10, 8, 4),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          clipData: FlClipData.all(),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => _bgMid,
              tooltipBorder: BorderSide(color: _accent.withOpacity(0.3)),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${labels[s.x.toInt()]}\n'
                      '${_fmtNum(s.y)} kW',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          gridData: FlGridData(
            show: false,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length || i % 2 != 0) {
                    return const Text('');
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[i],
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF374151),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, m) => Text(
                  _shortNum(v),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6b7280),
                  ),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
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
              color: _bgCard,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3,
                  color: _bgCard,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _accent.withOpacity(0.30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BAR CHART (periodo / mes / ano) com CustomPainter para desempenho ─────

  Widget _buildBarChart(
    List<String> labels,
    List<double> producao,
    List<double>? prognostico,
    List<double?>? desempenho,
    bool isLandscape,
  ) {
    const double maxDesemp = 120.0;

    final hasDesempenho = desempenho != null && desempenho.isNotEmpty;
    final hasPrognostico = prognostico != null && prognostico.isNotEmpty;
    final isAno = _periodo == 'ano';
    final isMes = _periodo == 'mes';
    final nGroups = producao.length;

    if (nGroups == 0) return const SizedBox.shrink();

    // maxY
    double maxY = 0;
    for (final v in producao) {
      if (v > maxY) maxY = v;
    }
    if (hasPrognostico) {
      for (int i = 0; i < prognostico.length; i++) {
        final v = prognostico[i];
        if (v > maxY) maxY = v;
      }
    }
    if (maxY == 0) maxY = 1;
    maxY *= 1.25;

    // Dados de desempenho (valor real em %)
    final desempData = <double>[];
    if (hasDesempenho) {
      for (int i = 0; i < desempenho.length; i++) {
        final d = desempenho[i];
        desempData.add(d != null ? d.clamp(0.0, maxDesemp) : 0);
      }
    }

    // Largura das barras
    final barW = isAno
        ? (hasPrognostico ? 8.0 : 14.0)
        : isMes
            ? (isLandscape
                ? (hasPrognostico ? 8.0 : 12.0)
                : (hasPrognostico ? 6.0 : 10.0))
            : (hasPrognostico ? 6.0 : 10.0);

    // Passo de labels
    final isPeriodo = _periodo == 'periodo';
    final int step = isMes
        ? 1
        : isPeriodo
            ? (labels.length <= 15
                ? 1
                : (labels.length / 8).ceil().clamp(1, 999))
            : (labels.length / 6).ceil().clamp(1, 999);

    // No mês, usa scroll apenas no retrato para manter boa ocupação no horizontal
    final useScrollMes = isMes && !isLandscape && nGroups > 15;
    final pxPerGroup = hasPrognostico
        ? (isLandscape ? 24.0 : 26.0)
        : (isLandscape ? 20.0 : 22.0);

    // Grupos de barras
    final barsSpace = (isMes && hasPrognostico) ? 0.0 : 2.0;

    final groups = producao.asMap().entries.map((e) {
      final rods = <BarChartRodData>[];
      if (hasPrognostico && e.key < prognostico.length) {
        rods.add(BarChartRodData(
          toY: prognostico[e.key],
          color: _barProg,
          width: barW,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
        ));
      }
      rods.add(BarChartRodData(
        toY: e.value,
        color: _barProd,
        width: barW,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(3),
        ),
      ));
      return BarChartGroupData(
        x: e.key,
        barRods: rods,
        barsSpace: barsSpace,
        showingTooltipIndicators: _touchedBarGroupIndex == e.key
            ? List<int>.generate(rods.length, (i) => i)
            : const [],
      );
    }).toList();

    // BarChart base
    // Em horizontal, distribuir os grupos por toda área útil do plot.
    final groupsSpace = isMes
        ? (isLandscape
            ? (hasPrognostico ? 2.0 : 4.0)
            : (hasPrognostico ? 5.0 : 8.0))
        : (isLandscape
            ? (hasPrognostico ? 2.0 : 4.0)
            : (isAno
                ? (hasPrognostico ? 6.0 : 10.0)
                : (hasPrognostico ? 8.0 : 14.0)));

    final baseChart = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        groupsSpace: groupsSpace,
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            // Limpa o tooltip ao soltar
            if (event is FlTapUpEvent ||
                event is FlPanEndEvent ||
                event is FlLongPressEnd) {
              if (_touchedBarGroupIndex != null) {
                setState(() => _touchedBarGroupIndex = null);
              }
              return;
            }

            // Mostra tooltip apenas durante o toque/arrasto
            if (event is FlTapDownEvent ||
                event is FlPanStartEvent ||
                event is FlPanUpdateEvent ||
                event is FlLongPressStart ||
                event is FlLongPressMoveUpdate) {
              final spot = response?.spot;
              if (spot != null) {
                final touched = spot.touchedBarGroupIndex;
                if (_touchedBarGroupIndex != touched) {
                  setState(() => _touchedBarGroupIndex = touched);
                }
              }
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _bgMid,
            tooltipBorder: BorderSide(color: _accent.withOpacity(0.3)),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, gi, rod, ri) {
              if (ri != 0) return null;

              final idx = group.x.toInt();
              if (idx < 0 || idx >= labels.length) return null;

              final label = labels[idx];
              final hasProgRod = hasPrognostico && group.barRods.length > 1;
              final progValue = hasProgRod ? group.barRods[0].toY : null;
              final prodValue =
                  hasProgRod ? group.barRods[1].toY : group.barRods[0].toY;
              final desempValue = (hasDesempenho && idx < desempData.length)
                  ? desempData[idx]
                  : null;

              final desempFmt = desempValue == null
                  ? '-'
                  : desempValue.toStringAsFixed(1).replaceAll('.', ',');

              return BarTooltipItem(
                '$label\n',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  if (desempValue != null) ...[
                    TextSpan(
                      text: '■ ',
                      style: const TextStyle(color: _lineDesemp),
                    ),
                    TextSpan(
                      text: 'Desempenho (%): $desempFmt%\n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (progValue != null) ...[
                    TextSpan(
                      text: '■ ',
                      style: const TextStyle(color: _barProg),
                    ),
                    TextSpan(
                      text: 'Prognóstico: ${_fmtNum(progValue)} kWh\n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  TextSpan(
                    text: '■ ',
                    style: const TextStyle(color: _barProd),
                  ),
                  TextSpan(
                    text: 'Produção: ${_fmtNum(prodValue)} kWh',
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
              interval: 1,
              reservedSize: isPeriodo ? 24.0 : _bottomR,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) {
                  return const Text('');
                }
                if (!isAno && i % step != 0) {
                  return const Text('');
                }
                String lbl = labels[i];
                if (lbl.startsWith('Dia ')) {
                  lbl = lbl.replaceFirst('Dia ', '');
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    lbl,
                    style: TextStyle(
                      fontSize: isPeriodo ? 8.5 : 8,
                      color: const Color(0xFF374151),
                      fontWeight:
                          isPeriodo ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _leftR,
              getTitlesWidget: (v, m) => Text(
                _shortNum(v),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFF6b7280),
                ),
              ),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: hasDesempenho,
              reservedSize: _rightR,
              interval: maxY / 6,
              getTitlesWidget: (v, m) {
                final stepY = maxY / 6;
                final idx = (v / stepY).round();
                if (idx < 0 || idx > 6) {
                  return const Text('');
                }
                if ((v - (idx * stepY)).abs() > stepY * 0.08) {
                  return const Text('');
                }

                final pctRounded = idx * 20;

                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '$pctRounded%',
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: _lineDesemp,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: false,
        ),
        borderData: FlBorderData(show: false),
        barGroups: groups,
      ),
    );

    // CustomPainter para desenhar a linha de desempenho
    Widget chartWithDesempenho() {
      if (!hasDesempenho || desempData.isEmpty) {
        return baseChart;
      }

      final lineLayer = IgnorePointer(
        child: CustomPaint(
          painter: DesempenhoLinePainter(
            desempData: desempData,
            maxY: maxY,
            maxDesemp: maxDesemp,
            nGroups: nGroups,
            lineColor: _lineDesemp,
            leftReserved: _leftR,
            rightReserved: _rightR,
            bottomReserved: _bottomR,
            alignment: BarChartAlignment.center,
            groupsSpace: groupsSpace,
          ),
          size: Size.infinite,
        ),
      );

      final tooltipAtiva = _touchedBarGroupIndex != null;

      return Stack(
        children: [
          if (tooltipAtiva) ...[
            lineLayer,
            baseChart,
          ] else ...[
            baseChart,
            lineLayer,
          ],
        ],
      );
    }

    if (useScrollMes) {
      final totalW = nGroups * pxPerGroup + _leftR + _rightR + 20;
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          color: const Color(0xFFE0E0E0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              child: chartWithDesempenho(),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: chartWithDesempenho(),
      ),
    );
  }
}
