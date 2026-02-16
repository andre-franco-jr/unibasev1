import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/usina.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Usina> _usinas = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _chartType =
      'potencia_atual'; // potencia_atual, producao_hoje, potencia_instalada

  @override
  void initState() {
    super.initState();
    _loadUsinas();
  }

  Future<void> _loadUsinas() async {
    setState(() => _isLoading = true);

    try {
      final usinas = await ApiService.getUsinas();

      // Validação segura (sem throw)
      final validUsinas = usinas
          .where((u) => u.codigoGerador.isNotEmpty)
          .toList();

      if (validUsinas.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Nenhuma usina ativa encontrada.';
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _usinas = validUsinas;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Log apenas (não mostra erro)
      debugPrint('Erro ao carregar usinas: $e');

      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível carregar os dados.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return _usinas.asMap().entries.map((entry) {
      final index = entry.key;
      final usina = entry.value;

      double value;
      Color color;

      switch (_chartType) {
        case 'producao_hoje':
          value = usina.producaoHoje;
          color = Colors.green;
          break;
        case 'potencia_instalada':
          value = usina.potenciaInstalada;
          color = Colors.blue;
          break;
        case 'potencia_atual':
        default:
          value = usina.potenciaAtual;
          color = usina.isOnline ? AppColors.primary : Colors.grey;
      }

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: color,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  double _getMaxY() {
    if (_usinas.isEmpty) return 100;

    double max;
    switch (_chartType) {
      case 'producao_hoje':
        max =
            _usinas.map((u) => u.producaoHoje).reduce((a, b) => a > b ? a : b);
        break;
      case 'potencia_instalada':
        max = _usinas
            .map((u) => u.potenciaInstalada)
            .reduce((a, b) => a > b ? a : b);
        break;
      case 'potencia_atual':
      default:
        max =
            _usinas.map((u) => u.potenciaAtual).reduce((a, b) => a > b ? a : b);
    }

    return max * 1.2; // 20% a mais para margem
  }

  String _getChartTitle() {
    switch (_chartType) {
      case 'producao_hoje':
        return 'Produção de Hoje (kWh)';
      case 'potencia_instalada':
        return 'Potência Instalada (kW)';
      case 'potencia_atual':
      default:
        return 'Potência Atual (kW)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Unienergy'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsinas,
            tooltip: 'Atualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUsinas,
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                )
              : _usinas.isEmpty
                  ? const Center(child: Text('Nenhuma usina encontrada'))
                  : Column(
                      children: [
                        // Cards de resumo
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.grey.shade100,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total de Usinas',
                                  '${_usinas.length}',
                                  Icons.solar_power,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Online',
                                  '${_usinas.where((u) => u.isOnline).length}',
                                  Icons.online_prediction,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Potência Total',
                                  '${_usinas.map((u) => u.potenciaAtual).reduce((a, b) => a + b).toStringAsFixed(1)} kW',
                                  Icons.flash_on,
                                  AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Seletor de tipo de gráfico
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'potencia_atual',
                                label: Text('Potência Atual'),
                                icon: Icon(Icons.flash_on),
                              ),
                              ButtonSegment(
                                value: 'producao_hoje',
                                label: Text('Produção Hoje'),
                                icon: Icon(Icons.wb_sunny),
                              ),
                              ButtonSegment(
                                value: 'potencia_instalada',
                                label: Text('Instalada'),
                                icon: Icon(Icons.settings_input_antenna),
                              ),
                            ],
                            selected: {_chartType},
                            onSelectionChanged: (Set<String> selection) {
                              setState(() {
                                _chartType = selection.first;
                              });
                            },
                          ),
                        ),

                        // Gráfico de barras
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getChartTitle(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: BarChart(
                                        BarChartData(
                                          maxY: _getMaxY(),
                                          barGroups: _buildBarGroups(),
                                          titlesData: FlTitlesData(
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 50,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toStringAsFixed(0),
                                                    style: const TextStyle(
                                                        fontSize: 10),
                                                  );
                                                },
                                              ),
                                            ),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 30,
                                                getTitlesWidget: (value, meta) {
                                                  if (value.toInt() >= 0 &&
                                                      value.toInt() <
                                                          _usinas.length) {
                                                    final codigo =
                                                        _usinas[value.toInt()]
                                                            .codigoGerador;
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 8),
                                                      child: Transform.rotate(
                                                        angle: -0.5,
                                                        child: Text(
                                                          codigo,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 8),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  return const Text('');
                                                },
                                              ),
                                            ),
                                            topTitles: const AxisTitles(
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                            rightTitles: const AxisTitles(
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                          ),
                                          borderData: FlBorderData(
                                            show: true,
                                            border: Border(
                                              left: BorderSide(
                                                  color: Colors.grey.shade300),
                                              bottom: BorderSide(
                                                  color: Colors.grey.shade300),
                                            ),
                                          ),
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: false,
                                            horizontalInterval: _getMaxY() / 5,
                                            getDrawingHorizontalLine: (value) {
                                              return FlLine(
                                                color: Colors.grey.shade200,
                                                strokeWidth: 1,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Lista de usinas
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Detalhes das Usinas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _usinas.length,
                            itemBuilder: (context, index) {
                              final usina = _usinas[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: usina.isOnline
                                        ? Colors.green
                                        : Colors.grey,
                                    child: Icon(
                                      usina.isOnline
                                          ? Icons.check
                                          : Icons.close,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    usina.codigoGerador,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(usina.localizacaoPlanta),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${usina.potenciaAtual.toStringAsFixed(2)} kW',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${usina.producaoHoje.toStringAsFixed(1)} kWh hoje',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
