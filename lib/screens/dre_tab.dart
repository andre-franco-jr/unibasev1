import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta fiel ao sistema web
// ─────────────────────────────────────────────────────────────────────────────
const _bgDark = Color(0xFF001f2e);
const _bgMid = Color(0xFF003a4d);
const _bgCard = Color(0xFF004D66);
const _accent = Color(0xFFEAC248); // dourado
const _green = Color(0xFF10b981); // verde
const _red = Color(0xFFef4444); // vermelho
const _muted = Color(0xFF7da5b5); // texto secundário

const _mesesNomes = [
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

// ─────────────────────────────────────────────────────────────────────────────

class DRETab extends StatefulWidget {
  const DRETab({super.key});

  @override
  State<DRETab> createState() => DRETabState();
}

class DRETabState extends State<DRETab>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  //── Estado ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _usinas = [];
  Map<String, dynamic>? _usinaAtual;
  int _anoSelecionado = DateTime.now().year;

  // null = acumulado (todos liberados); Set = seleção manual
  Set<int>? _mesesSelecionados;

  List<Map<String, dynamic>> _linhas = [];
  Map<String, dynamic> _valores = {};
  Map<String, bool> _mesesLiberados = {};

  bool _loadingUsinas = true;
  bool _loadingDados = false;
  String? _erro;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  AppLifecycleState? _lastLifecycleState;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addObserver(this);
    _loadUsinas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _lastLifecycleState != AppLifecycleState.resumed) {
      // App volta do background, recarregar dados
      _loadDados();
    }
    _lastLifecycleState = state;
  }

  Future<void> refresh() async {
    await _loadUsinas();
    if (_usinaAtual != null) {
      await _loadDados();
    }
  }

  // ── CARGA ────────────────────────────────────────────────────────────────────

  Future<void> _loadUsinas() async {
    setState(() {
      _loadingUsinas = true;
      _erro = null;
    });
    try {
      final r = await ApiService.getDreUsinas();
      if (!mounted) return;
      setState(() {
        _usinas = List<Map<String, dynamic>>.from(r);
        _loadingUsinas = false;
        if (_usinas.isNotEmpty && _usinaAtual == null) {
          _usinaAtual = _usinas.first;
          _loadDados();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingUsinas = false;
          _erro = e.toString();
        });
      }
    }
  }

  Future<void> _loadDados() async {
    if (_usinaAtual == null) return;
    setState(() {
      _loadingDados = true;
      _erro = null;
    });
    _fadeCtrl.reset();
    try {
      final idPlanta =
          int.tryParse(_usinaAtual!['id_planta']?.toString() ?? '0') ?? 0;

      final r = await ApiService.getDreDados(
        idPlanta: idPlanta,
        ano: _anoSelecionado,
      );
      if (!mounted) return;
      setState(() {
        _linhas = List<Map<String, dynamic>>.from(r['linhas'] ?? []);
        _valores = Map<String, dynamic>.from(r['valores'] ?? {});
        _mesesLiberados = (r['meses_liberados'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v == true || v == 1)) ??
            {};
        _mesesSelecionados = null; // reset para acumulado
        _loadingDados = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fadeCtrl.forward(from: 0.0);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingDados = false;
          _erro = e.toString();
        });
      }
    }
  }

  // ── HELPERS DE VALOR (Seguros) ───────────────────────────────────────────────

  List<int> get _mesesAtivos {
    if (_mesesSelecionados == null) {
      return List.generate(12, (i) => i + 1)
          .where((m) => _mesesLiberados[m.toString()] == true)
          .toList();
    }
    return _mesesSelecionados!.toList()..sort();
  }

  double _valorPorMes(int linhaId, int mes) {
    final mMap = _valores[linhaId.toString()] as Map?;
    if (mMap == null) return 0;
    final entry = mMap[mes.toString()];
    if (entry == null) return 0;
    if (entry is Map) {
      return double.tryParse(entry['valor']?.toString() ?? '0') ?? 0;
    }
    return double.tryParse(entry.toString()) ?? 0;
  }

  double _valorExibido(int linhaId) =>
      _mesesAtivos.fold(0.0, (s, m) => s + _valorPorMes(linhaId, m));

  double get _lucroLiquido {
    final id = _idLinha('LUCRO LÍQUIDO');
    return id == null ? 0 : _valorExibido(id);
  }

  int? _idLinha(String nomeMatch) {
    try {
      final match = _linhas.firstWhere((l) {
        final nome =
            (l['nome_linha']?.toString() ?? l['nome']?.toString() ?? '')
                .toUpperCase();
        return nome.contains(nomeMatch.toUpperCase());
      });
      return int.tryParse(match['id']?.toString() ?? '0');
    } catch (_) {
      return null;
    }
  }

  // ── SEMÂNTICA VISUAL ─────────────────────────────────────────────────────────

  bool _ehResultado(Map<String, dynamic> l) {
    final val = l['eh_calculo']?.toString() ?? '0';
    return val == '1' || val == 'true';
  }

  bool _ehDespesa(Map<String, dynamic> l, String nome) {
    final n = nome.toUpperCase();
    if (n.contains('CUSTO') ||
        n.contains('DESPESA') ||
        n.contains('DEDU') ||
        n.contains('IMPOSTO')) return true;
    final cat = (l['categoria']?.toString() ?? '').toLowerCase();
    return const {'deducoes', 'custos', 'despesas', 'outras', 'impostos'}
        .contains(cat);
  }

  Color _corLinha(Map<String, dynamic> l, String nome) {
    final n = nome.toUpperCase();
    if (n.contains('LUCRO') || n.contains('EBITDA')) return _accent;
    if (n.contains('RECEITA')) return _green;
    return Colors
        .white; // No card corporativo, branco destaca melhor as despesas
  }

  // ── FORMATAÇÃO ───────────────────────────────────────────────────────────────

  String _fmtR(double v) {
    final a = v.abs();
    final s = a.toStringAsFixed(2);
    final parts = s.split('.');
    final numStr = parts[0];
    final decimalStr = parts[1];

    final buf = StringBuffer();
    for (int i = 0; i < numStr.length; i++) {
      if (i > 0 && (numStr.length - i) % 3 == 0) buf.write('.');
      buf.write(numStr[i]);
    }
    return '${v < 0 ? '- ' : ''}R\$ ${buf.toString()},${decimalStr}';
  }

  String _fmtShort(double v) {
    final a = v.abs();
    if (a >= 1000000) return 'R\$ ${(a / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000) return 'R\$ ${(a / 1000).toStringAsFixed(1)}k';
    return _fmtR(v.abs());
  }

  String _labelAmigavel(String nome) => nome;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loadingUsinas) return const _FullLoading();
    if (_usinas.isEmpty) {
      return const _EmptyState(
          icon: Icons.analytics_outlined,
          msg: 'Nenhuma usina disponível para DRE');
    }

    if (_loadingDados) {
      return Container(
        color: _bgDark,
        child: const _FullLoading(),
      );
    }

    if (_erro != null) {
      return Container(
        color: _bgDark,
        child: _buildErro(),
      );
    }

    if (_linhas.isEmpty) {
      return Container(
        color: _bgDark,
        child: const _EmptyState(
            icon: Icons.bar_chart_outlined,
            msg: 'Sem dados para esta usina/ano'),
      );
    }

    return Container(
      color: _bgDark,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: _buildBody(),
      ),
    );
  }

  // ── HEADER E DROPDOWN (Mobile First + Cores Corporativas) ────────────────────

  Widget _buildHeader(bool isLandscape) {
    return Container(
      color: _bgDark,
      padding: EdgeInsets.fromLTRB(
        isLandscape ? 20 : 16,
        isLandscape ? 8 : 12,
        isLandscape ? 20 : 16,
        isLandscape ? 8 : 12,
      ),
      child: Row(
        children: [
          Expanded(child: _buildUsinaDropdown(isLandscape)),
          SizedBox(width: isLandscape ? 12 : 10),
          Expanded(child: _buildPeriodButton(isLandscape)),
        ],
      ),
    );
  }

  Widget _buildUsinaDropdown(bool isLandscape) {
    final nomeUsina =
        _usinaAtual?['nome_planta']?.toString() ?? 'Selecione usina';

    return PopupMenuButton<Map<String, dynamic>>(
      onSelected: (usina) {
        if (_usinaAtual?['id_planta'] != usina['id_planta']) {
          setState(() {
            _usinaAtual = usina;
            _linhas = [];
            _valores = {};
          });
          _loadDados();
        }
      },
      itemBuilder: (BuildContext context) {
        return _usinas.map((usina) {
          final isAtual = _usinaAtual?['id_planta'] == usina['id_planta'];
          final nome = usina['nome_planta']?.toString() ?? 'Usina';
          return PopupMenuItem<Map<String, dynamic>>(
            value: usina,
            child: Row(
              children: [
                Icon(
                  isAtual
                      ? Icons.solar_power_rounded
                      : Icons.solar_power_outlined,
                  color: isAtual ? _accent : _muted,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Text(
                  nome,
                  style: TextStyle(
                    color: isAtual ? Colors.white : Colors.white70,
                    fontWeight: isAtual ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: _bgMid,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isLandscape ? 8 : 10,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accent.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.solar_power_rounded, color: _accent, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                nomeUsina,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: _muted, size: 16),
          ],
        ),
      ),
    );
  }

  // ── BOTÃO DE PERÍODO ─────────────────────────────────────────────────────────

  Widget _buildPeriodButton(bool isLandscape) {
    final ativos = _mesesAtivos;
    String label;
    if (_mesesSelecionados == null) {
      label = '$_anoSelecionado · Acum.';
    } else if (ativos.isEmpty) {
      label = '$_anoSelecionado · —';
    } else if (ativos.length == 1) {
      label = '$_anoSelecionado · ${_mesesNomes[ativos.first - 1]}';
    } else {
      label = '$_anoSelecionado · ${ativos.length}m';
    }

    return GestureDetector(
      onTap: _openPeriodSheet,
      child: Tooltip(
        message: label,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isLandscape ? 8 : 10,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accent.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month_outlined,
                  color: _accent, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, color: _muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── SHEET DE PERÍODO (Calendário Web-Style) ──────────────────────────────────

  void _openPeriodSheet() {
    int tempAno = _anoSelecionado;
    Set<int>? tempMeses =
        _mesesSelecionados == null ? null : Set<int>.from(_mesesSelecionados!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.58,
            decoration: const BoxDecoration(
              color: _bgMid,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            color: _accent, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Período',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            final anoMudou = tempAno != _anoSelecionado;
                            Navigator.pop(ctx);
                            setState(() {
                              _anoSelecionado = tempAno;
                              _mesesSelecionados = tempMeses;
                            });
                            if (anoMudou) _loadDados();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: _bgDark,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Aplicar',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.white.withOpacity(0.06), height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        const Text(
                          'ANO',
                          style: TextStyle(
                              fontSize: 10,
                              color: _muted,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold),
                        ), // ← Adicionado este parêntese
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            DateTime.now().year,
                            DateTime.now().year - 1,
                            DateTime.now().year - 2,
                          ].map((a) {
                            final sel = tempAno == a;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setSheet(() => tempAno = a);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 10),
                                decoration: BoxDecoration(
                                  color:
                                      sel ? _accent.withOpacity(0.15) : _bgCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: sel ? _accent : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text('$a',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: sel ? _accent : Colors.white70,
                                    )),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            const Text(
                              'MESES',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _muted,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.bold),
                            ), // ← Adicionado parêntese aqui
                            const Spacer(),

                            GestureDetector(
                              onTap: () => setSheet(() {
                                tempMeses = tempMeses == null ? {} : null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _bgCard,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: _muted.withOpacity(0.2)),
                                ),
                                child: Text(
                                  tempMeses == null
                                      ? 'Desmarcar todos'
                                      : 'Marcar todos',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: _accent,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 1.7,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 12,
                          itemBuilder: (_, i) {
                            final mes = i + 1;
                            final liberado =
                                _mesesLiberados[mes.toString()] == true;
                            final checked = tempMeses == null
                                ? liberado
                                : tempMeses!.contains(mes);

                            return GestureDetector(
                              onTap: !liberado
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setSheet(() {
                                        if (tempMeses == null) {
                                          tempMeses = Set<int>.from(
                                              List.generate(12, (j) => j + 1)
                                                  .where((m) =>
                                                      _mesesLiberados[
                                                          m.toString()] ==
                                                      true));
                                          tempMeses!.remove(mes);
                                        } else {
                                          if (tempMeses!.contains(mes)) {
                                            tempMeses!.remove(mes);
                                          } else {
                                            tempMeses!.add(mes);
                                          }
                                        }
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: checked
                                      ? _accent.withOpacity(0.15)
                                      : _bgCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        checked ? _accent : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(_mesesNomes[i],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: !liberado
                                              ? Colors.white.withOpacity(0.2)
                                              : checked
                                                  ? _accent
                                                  : Colors.white70,
                                        )),
                                    if (!liberado)
                                      Positioned(
                                        top: 4,
                                        right: 6,
                                        child: Icon(Icons.lock_outline,
                                            size: 8,
                                            color:
                                                Colors.white.withOpacity(0.2)),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── BODY (Lista da DRE) ──────────────────────────────────────────────────────

  Widget _buildBody() {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final padding = isLandscape ? 20.0 : 16.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(padding, 0, padding, 40),
          children: [
            _buildHeader(isLandscape),
            const SizedBox(height: 8),
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildSectionLabel(),
            const SizedBox(height: 12),
            ..._buildDREList(),
          ],
        );
      },
    );
  }

  // ── HERO CARD CORPORATIVO ────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    final ll = _lucroLiquido;
    final pos = ll >= 0;

    return Container(
      decoration: BoxDecoration(
        color: _bgMid,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: _accent, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: _accent),
              const SizedBox(width: 8),
              const Text('Lucro Líquido Acumulado',
                  style: TextStyle(
                      fontSize: 12,
                      color: _muted,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_fmtR(ll),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: pos ? Colors.white : _red,
                letterSpacing: -1,
              )),
          const SizedBox(height: 4),
          Text('Refere-se ao total do período filtrado',
              style: TextStyle(fontSize: 10, color: _muted.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildSectionLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.list_alt_rounded, color: _accent, size: 16),
          const SizedBox(width: 8),
          const Text('Demonstrativo de Resultados',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  List<Widget> _buildDREList() {
    final widgets = <Widget>[];
    for (int i = 0; i < _linhas.length; i++) {
      final linha = _linhas[i];
      final id = int.tryParse(linha['id']?.toString() ?? '0') ?? 0;
      final nome = linha['nome_linha']?.toString() ??
          linha['nome']?.toString() ??
          'Linha sem nome';
      final valor = _valorExibido(id);
      final isResult = _ehResultado(linha);
      final isDespesa = _ehDespesa(linha, nome);
      final cor = _corLinha(linha, nome);

      widgets.add(_buildDREItem(
        nome: nome,
        linha: linha,
        valor: valor,
        isResult: isResult,
        isDespesa: isDespesa,
        cor: cor,
        linhaId: id,
      ));

      if (i < _linhas.length - 1) {
        widgets.add(_buildConnector());
      }
    }

    if (_linhas.isNotEmpty) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(_buildTotalFooter());
    }

    return widgets;
  }

  Widget _buildConnector() {
    return SizedBox(
      height: 16,
      child: Center(
        child: Container(
          width: 1,
          height: double.infinity,
          color: Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildDREItem({
    required String nome,
    required Map<String, dynamic> linha,
    required double valor,
    required bool isResult,
    required bool isDespesa,
    required Color cor,
    required int linhaId,
  }) {
    final valorStr = isDespesa && valor.abs() > 0
        ? '- ${_fmtShort(valor.abs())}'
        : _fmtShort(valor.abs());

    // Se for negativo e for despesa, fica vermelho. Senão, fica na cor da categoria.
    final colorValor = isDespesa && valor > 0
        ? _red
        : valor < 0
            ? _red
            : cor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openBottomSheet(nome, linhaId, isDespesa, cor);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isResult ? _bgMid : _bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: cor, width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _labelAmigavel(nome),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isResult ? FontWeight.bold : FontWeight.w600,
                  color: cor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valorStr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorValor,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: _muted, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalFooter() {
    final ll = _lucroLiquido;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bgMid,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('RESULTADO FINAL',
              style: TextStyle(
                  fontSize: 11,
                  color: _accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0)),
          Text(_fmtR(ll),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ll >= 0 ? Colors.white : _red)),
        ],
      ),
    );
  }

  // ── BOTTOM SHEET DE DETALHES (Estilo Corporativo) ────────────────────────────

  void _openBottomSheet(String nome, int linhaId, bool isDespesa, Color cor) {
    final mMap = (_valores[linhaId.toString()] as Map?) ?? {};

    final vals = List.generate(12, (i) {
      final mes = i + 1;
      final liberado = _mesesLiberados[mes.toString()] == true;
      final entry = mMap[mes.toString()];
      double v = 0;
      if (entry != null) {
        v = entry is Map
            ? double.tryParse(entry['valor']?.toString() ?? '0') ?? 0
            : double.tryParse(entry.toString()) ?? 0;
      }
      return _MesData(
          mes: mes, label: _mesesNomes[i], valor: v, liberado: liberado);
    });

    final total =
        vals.where((m) => m.liberado).fold(0.0, (s, m) => s + m.valor);
    final maxV =
        vals.map((m) => m.valor.abs()).fold(0.0, (a, b) => a > b ? a : b);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // ← Adicione isto
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.only(bottom: 16),
        child: SafeArea(
          child: SingleChildScrollView(
            // ← Envolva com scroll
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 32,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                            color: cor, borderRadius: BorderRadius.circular(2)),
                      ),
                      Expanded(
                        child: Text(_labelAmigavel(nome),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      Text(
                        isDespesa && total > 0
                            ? '- ${_fmtR(total.abs())}'
                            : _fmtR(total),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDespesa && total > 0 ? _red : cor),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniChart(vals, maxV, cor),
                      const SizedBox(height: 14),
                      _buildMonthGrid(vals, isDespesa, cor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChart(List<_MesData> vals, double maxV, Color cor) {
    if (maxV == 0) maxV = 1;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        height: 65,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: vals.asMap().entries.map((e) {
            final m = e.value;
            final h = m.liberado ? (m.valor.abs() / maxV) * 48 : 4.0;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 250 + e.key * 25),
                    height: h.clamp(4.0, 48.0),
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    decoration: BoxDecoration(
                      color: m.liberado ? cor : Colors.white10,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        topRight: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(m.label[0],
                      style: const TextStyle(
                          fontSize: 8,
                          color: _muted,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthGrid(List<_MesData> vals, bool isDespesa, Color cor) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 52,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final m = vals[i];
        return Container(
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(m.label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: m.liberado ? _muted : Colors.white24)),
              const SizedBox(height: 2),
              Text(
                m.liberado ? _fmtShort(m.valor) : '—',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: !m.liberado
                      ? Colors.white24
                      : isDespesa && m.valor > 0
                          ? _red
                          : cor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── ERRO & LOADING ───────────────────────────────────────────────────────────

  Widget _buildErro() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: _red, size: 48),
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
                onPressed: _loadDados,
                child: const Text('Tentar novamente',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
}

class _MesData {
  final int mes;
  final String label;
  final double valor;
  final bool liberado;
  const _MesData(
      {required this.mes,
      required this.label,
      required this.valor,
      required this.liberado});
}

class _FullLoading extends StatelessWidget {
  const _FullLoading();
  @override
  Widget build(BuildContext ctx) => const Center(
      child: CircularProgressIndicator(color: _accent, strokeWidth: 3));
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String msg;
  const _EmptyState({required this.icon, required this.msg});
  @override
  Widget build(BuildContext ctx) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white12, size: 52),
            const SizedBox(height: 14),
            Text(msg,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
}
