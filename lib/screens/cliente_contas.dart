import 'package:flutter/material.dart';
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

  // Filtros
  String _busca = '';
  String? _mesAtivo; // ref_mes_ano no formato "MM/YYYY"
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

  // Meses únicos disponíveis
  List<String> get _mesesDisponiveis {
    final Set<String> s = {};
    for (final c in _contas) {
      if (c['ref_mes_ano'] != null) s.add(c['ref_mes_ano'] as String);
    }
    final l = s.toList()..sort((a, b) => b.compareTo(a));
    return l;
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
          // Chips de mês
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _mesChip(null, 'Todos'),
                ..._mesesDisponiveis.map((m) => _mesChip(m, m)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mesChip(String? valor, String label) {
    final active = _mesAtivo == valor;
    return GestureDetector(
      onTap: () {
        setState(() => _mesAtivo = valor);
        _aplicarFiltro();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _accent : _bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _accent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? const Color(0xFF003E52) : Colors.white70,
          ),
        ),
      ),
    );
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

          // Botões de download
          if (temBoleto || temFatura || temNeo || temUni)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (temBoleto)
                    _downloadBtn(
                      Icons.barcode_reader,
                      'Boleto',
                      conta['bank_slip_url'],
                      Colors.orange,
                    ),
                  if (temFatura)
                    _downloadBtn(
                      Icons.description_outlined,
                      'Fatura Uni',
                      conta['fatura_url'],
                      _accent,
                    ),
                  if (temNeo)
                    _downloadBtn(
                      Icons.bolt_outlined,
                      'Conta Neo',
                      conta['file_url'],
                      const Color(0xFF148bad),
                    ),
                  if (temUni)
                    _downloadBtn(
                      Icons.picture_as_pdf_outlined,
                      'PDF Uni',
                      conta['fatura_unienergy_url'] != null
                          ? 'https://unienergyportal.com${conta['fatura_unienergy_url']}'
                          : null,
                      const Color(0xFF10b981),
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

  Widget _downloadBtn(IconData icon, String label, String? url, Color color) {
    if (url == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
