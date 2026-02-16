class Usina {
  final int idPlanta;
  final String nomePlanta;
  final String nomeGerador;
  final String codigoGerador;
  final String localizacaoPlanta;
  final double latitude;
  final double longitude;
  final double potenciaInstalada;
  final double potenciaAtual;
  final double producaoHoje;
  final int statusOnline;

  Usina({
    required this.idPlanta,
    required this.nomePlanta,
    required this.nomeGerador,
    required this.codigoGerador,
    required this.localizacaoPlanta,
    required this.latitude,
    required this.longitude,
    required this.potenciaInstalada,
    required this.potenciaAtual,
    required this.producaoHoje,
    required this.statusOnline,
  });

  factory Usina.fromJson(Map<String, dynamic> json) {
    return Usina(
      idPlanta: _parseInt(json['id_planta']),
      nomePlanta: json['nome_planta']?.toString() ?? '',
      nomeGerador: json['nome_gerador']?.toString() ?? '',
      codigoGerador: json['codigo_gerador']?.toString() ?? '',
      localizacaoPlanta: json['localizacao_planta']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      potenciaInstalada: _parseDouble(json['potencia_instalada']),
      potenciaAtual: _parseDouble(json['potencia_atual']),
      producaoHoje: _parseDouble(json['producao_hoje']),
      statusOnline: _parseInt(json['status_online']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool get isOnline => statusOnline == 1;

  double get percentualProducao {
    if (potenciaInstalada == 0) return 0;
    return (potenciaAtual / potenciaInstalada) * 100;
  }
}

// ─────────────────────────────────────────────────────────
// GERADOR
// API retorna: {id, codigo_gerador, nome_gerador, cnpj_gerador}
// ─────────────────────────────────────────────────────────
class Gerador {
  final int id;
  final String codigoGerador;
  final String nomeGerador;
  final String cnpjGerador;

  Gerador({
    required this.id,
    required this.codigoGerador,
    required this.nomeGerador,
    required this.cnpjGerador,
  });

  factory Gerador.fromJson(Map<String, dynamic> json) {
    return Gerador(
      id: _parseInt(json['id']),
      codigoGerador: json['codigo_gerador']?.toString() ?? '',
      nomeGerador: json['nome_gerador']?.toString() ?? '',
      cnpjGerador: json['cnpj_gerador']?.toString() ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

// ─────────────────────────────────────────────────────────
// INVESTOR DASHBOARD DATA
// API retorna: {credito_acumulado, total_beneficiarios,
//   ticket_medio, performance_alvo, capacidade_total,
//   disponivel_venda}
// ─────────────────────────────────────────────────────────
class InvestorDashboardData {
  final double creditoAcumulado;
  final int totalBeneficiarios;
  final double ticketMedio;
  final double performanceAlvo;
  final double capacidadeTotal;
  final double disponivelVenda;

  InvestorDashboardData({
    required this.creditoAcumulado,
    required this.totalBeneficiarios,
    required this.ticketMedio,
    required this.performanceAlvo,
    required this.capacidadeTotal,
    required this.disponivelVenda,
  });

  factory InvestorDashboardData.fromJson(Map<String, dynamic> json) {
    return InvestorDashboardData(
      creditoAcumulado: _parseDouble(json['credito_acumulado']),
      totalBeneficiarios: _parseInt(json['total_beneficiarios']),
      ticketMedio: _parseDouble(json['ticket_medio']),
      performanceAlvo: _parseDouble(json['performance_alvo']),
      capacidadeTotal: _parseDouble(json['capacidade_total']),
      disponivelVenda: _parseDouble(json['disponivel_venda']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}