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

class ClienteContasTab extends StatefulWidget {
  const ClienteContasTab({super.key});

  @override
  State<ClienteContasTab> createState() => ClienteContasTabState();
}

class ClienteContasTabState extends State<ClienteContasTab> {
  List<Map<String, dynamic>> _contas = [];
  List<Map<String, dynamic>> _filtradas = [];
  bool _loading = true;

  // Filtros
  String _busca = '';
  String? _mesAtivo; // ref_mes_ano no formato "MM/YYYY"
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
    setState(() => _loading = true);
    try {
      final r = await ApiService.clienteContasNeoenergia();
      if (!mounted) return;
      setState(() {
        _contas = List<Map<String, dynamic>>.from(r);
        _loading = false;
      });
      _aplicarFiltro();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _accent))
                : _filtradas.isEmpty
                    ? const Center(
                        child: Text('Nenhuma conta encontrada',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 13)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: _filtradas.length,
                        itemBuilder: (_, i) => _buildContaCard(_filtradas[i]),
                      ),
          ),
        ],
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
          // Barra de busca
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
          // Seletor de calendário
          Row(
            children: [
              Expanded(child: _buildSeletorCalendario()),
              const SizedBox(width: 8),
              if (_mesAtivo != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _mesAtivo = null;
                      _dataSelecionada = null;
                    });
                    _aplicarFiltro();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _accent.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.clear, color: _accent, size: 18),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeletorCalendario() {
    return GestureDetector(
      onTap: _abrirCalendario,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _mesAtivo != null ? _accent.withOpacity(0.15) : _bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _mesAtivo != null ? _accent : _accent.withOpacity(0.3),
            width: _mesAtivo != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month,
              color: _mesAtivo != null ? _accent : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _mesAtivo ?? 'Selecionar mês',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      _mesAtivo != null ? FontWeight.w600 : FontWeight.normal,
                  color: _mesAtivo != null ? _accent : Colors.white70,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: _mesAtivo != null ? _accent : Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirCalendario() async {
    final resultado = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => _SeletorMesAno(
        dataSelecionada: _dataSelecionada,
      ),
    );

    if (resultado != null) {
      final mes = resultado['mes']!;
      final ano = resultado['ano']!;
      final mesFormatado = '${mes.toString().padLeft(2, '0')}/$ano';

      setState(() {
        _dataSelecionada = DateTime(ano, mes);
        _mesAtivo = mesFormatado;
      });
      _aplicarFiltro();
    }
  }

  // ── CARD DE CONTA ────────────────────────────────────────────────────────────

  Widget _buildContaCard(Map<String, dynamic> conta) {
    final temBoleto = conta['bank_slip_url'] != null;
    final temFatura = conta['fatura_url'] != null;
    final temNeo = conta['file_url'] != null;
    final temUni = conta['fatura_unienergy_url'] != null;

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
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
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
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Conta: ${conta['codigo_cliente'] ?? '—'}',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFFb0c4ce)),
                      ),
                    ],
                  ),
                ),
                // Badge mês
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withOpacity(0.5)),
                  ),
                  child: Text(
                    conta['ref_mes_ano'] ?? '',
                    style: const TextStyle(
                        fontSize: 10,
                        color: _accent,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Valores
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

          // Botões de download em grid 2x2
          if (temBoleto || temFatura || temNeo || temUni)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: [
                  // Primeira linha (2 botões)
                  Row(
                    children: [
                      if (temBoleto)
                        Expanded(
                          child: _downloadBtn(
                            Icons.barcode_reader,
                            'Boleto',
                            conta['bank_slip_url'],
                            Colors.orange,
                          ),
                        ),
                      if (temBoleto && (temFatura || temNeo || temUni))
                        const SizedBox(width: 6),
                      if (temFatura)
                        Expanded(
                          child: _downloadBtn(
                            Icons.description_outlined,
                            'Fatura Uni',
                            conta['fatura_url'],
                            _accent,
                          ),
                        ),
                      // Se só tem Boleto, preenche o espaço
                      if (temBoleto && !temFatura && !temNeo && !temUni)
                        const Expanded(child: SizedBox()),
                      // Se não tem Boleto mas tem Fatura, e não tem Neo nem Uni
                      if (!temBoleto && temFatura && !temNeo && !temUni)
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                  // Espaçamento entre linhas
                  if ((temBoleto || temFatura) && (temNeo || temUni))
                    const SizedBox(height: 6),
                  // Segunda linha (2 botões)
                  if (temNeo || temUni)
                    Row(
                      children: [
                        if (temNeo)
                          Expanded(
                            child: _downloadBtn(
                              Icons.bolt_outlined,
                              'Conta Neo',
                              conta['file_url'],
                              const Color(0xFF148bad),
                            ),
                          ),
                        if (temNeo && temUni) const SizedBox(width: 6),
                        if (temUni)
                          Expanded(
                            child: _downloadBtn(
                              Icons.picture_as_pdf_outlined,
                              'PDF Uni',
                              conta['fatura_unienergy_url'] != null
                                  ? 'https://unienergyportal.com${conta['fatura_unienergy_url']}'
                                  : null,
                              const Color(0xFF10b981),
                            ),
                          ),
                        // Se só tem Neo, preenche o espaço
                        if (temNeo && !temUni)
                          const Expanded(child: SizedBox()),
                        // Se só tem Uni (sem Neo)
                        if (!temNeo && temUni)
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _valorItem(String label, double valor, String? vencimento) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: Color(0xFFb0c4ce))),
            const SizedBox(height: 3),
            Text(
              valor > 0 ? 'R\$ ${valor.toStringAsFixed(2)}' : '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (vencimento != null)
              Text(
                'Venc: $vencimento',
                style: const TextStyle(fontSize: 9, color: Color(0xFFb0c4ce)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _baixarArquivo(String url, String nomeArquivo) async {
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

      // Gerar nome único se o arquivo já existir
      String finalPath = '${downloadsDir.path}/$nomeArquivo.pdf';
      int counter = 1;
      while (await File(finalPath).exists()) {
        finalPath = '${downloadsDir.path}/$nomeArquivo($counter).pdf';
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
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint('Download: $progress%');
          }
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Fechar diálogo de loading

      // Mostrar sucesso com caminho simplificado
      final String mensagem = Platform.isAndroid
          ? 'Arquivo salvo na pasta Downloads'
          : 'Arquivo salvo com sucesso';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Fechar diálogo de loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao baixar arquivo: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _downloadBtn(IconData icon, String label, String? url, Color color) {
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        // Gerar nome do arquivo baseado no label e timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final nomeArquivo = '${label.replaceAll(' ', '_')}_$timestamp';
        await _baixarArquivo(url, nomeArquivo);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SELETOR DE MÊS/ANO CUSTOMIZADO
// ═══════════════════════════════════════════════════════════════════════════

class _SeletorMesAno extends StatefulWidget {
  final DateTime? dataSelecionada;

  const _SeletorMesAno({this.dataSelecionada});

  @override
  State<_SeletorMesAno> createState() => _SeletorMesAnoState();
}

class _SeletorMesAnoState extends State<_SeletorMesAno> {
  late int _anoSelecionado;
  late int _mesSelecionado;

  final List<String> _meses = [
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
    final data = widget.dataSelecionada ?? DateTime.now();
    _anoSelecionado = data.year;
    _mesSelecionado = data.month;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _accent.withOpacity(0.3), width: 1),
      ),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabeçalho
            Row(
              children: [
                const Icon(Icons.calendar_month, color: _accent, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Selecionar Mês',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
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

            // Seletor de Ano
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _bgMid,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _anoSelecionado--);
                    },
                    icon: const Icon(Icons.chevron_left, color: _accent),
                  ),
                  Text(
                    _anoSelecionado.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _anoSelecionado++);
                    },
                    icon: const Icon(Icons.chevron_right, color: _accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Grid de Meses
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
              itemBuilder: (context, index) {
                final mesNum = index + 1;
                final selecionado = mesNum == _mesSelecionado;

                return GestureDetector(
                  onTap: () {
                    setState(() => _mesSelecionado = mesNum);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selecionado ? _accent : _bgMid,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selecionado ? _accent : _accent.withOpacity(0.2),
                        width: selecionado ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _meses[index].substring(0, 3),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selecionado ? FontWeight.w700 : FontWeight.w500,
                          color: selecionado
                              ? const Color(0xFF003E52)
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'mes': _mesSelecionado,
                      'ano': _anoSelecionado,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF003E52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Confirmar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WRAPPER PARA ABA DE FATURAS
// ═══════════════════════════════════════════════════════════════════════════════

class ClienteFaturasTab extends StatelessWidget {
  const ClienteFaturasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: const SafeArea(
        child: ClienteContasTab(),
      ),
    );
  }
}
