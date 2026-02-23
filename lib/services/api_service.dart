import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/usina.dart';

class ApiService {
  static String get _baseUrl => kIsWeb
      ? 'https://cors-anywhere.herokuapp.com/https://unienergyportal.com'
      : 'https://unienergyportal.com';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null && !options.path.contains('/login')) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final data = error.response?.data;
          // Só tenta renovar se for TOKEN_EXPIRED (não REFRESH_EXPIRED)
          if (data?['code'] == 'TOKEN_EXPIRED') {
            final prefs = await SharedPreferences.getInstance();
            final refreshToken = prefs.getString('refresh_token');
            if (refreshToken != null) {
              try {
                final renewed = await _refreshToken(refreshToken);
                if (renewed) {
                  final token = prefs.getString('access_token');
                  error.requestOptions.headers['Authorization'] =
                      'Bearer $token';
                  final response = await _dio.fetch(error.requestOptions);
                  return handler.resolve(response);
                }
              } catch (_) {
                await logout();
              }
            }
          } else {
            // REFRESH_EXPIRED ou credenciais inválidas → logout
            await logout();
          }
        }
        handler.next(error);
      },
    ));

    _initialized = true;
  }

  static Future<bool> _refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '/api/mobile/refresh',
        data: {'refresh_token': refreshToken},
      );
      if (response.data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', response.data['access_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────
  // AUTH
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '/api/mobile/login',
        data: {'username': username, 'password': password},
      );

      if (response.data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', response.data['access_token']);
        await prefs.setString('refresh_token', response.data['refresh_token']);
        await prefs.setString('username', username);
        await prefs.setString('user_nome', response.data['user']['nome']);
        await prefs.setString('user_role', response.data['user']['role']);
      }

      return response.data;
    } on DioException catch (e) {
      if (e.response != null) return e.response!.data;
      return {'success': false, 'message': 'Erro de conexão: ${e.message}'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Remover todos os dados de autenticação salvos no login
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('username');
    await prefs.remove('user_nome');
    await prefs.remove('user_role');
    await prefs.remove('user');

    // Limpar qualquer outra chave de autenticação que possa existir
    await prefs.remove('token');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  static Future<String?> getUserNome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_nome');
  }

  // ─────────────────────────────────────────
  // ADMIN — Usinas gerais
  // ─────────────────────────────────────────

  static Future<List<Usina>> getUsinas() async {
    try {
      final response = await _dio.get('/api/mobile/usinas');
      if (response.data['success'] == true) {
        final List<dynamic> json = response.data['usinas'];
        return json.map((j) => Usina.fromJson(j)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar usinas: ${e.message}');
    }
  }

  static Future<Map<String, dynamic>> getDesempenho(
    int idPlanta, {
    String periodo = 'dia',
    String? data,
    String? mes,
    String? ano,
    String? dataInicio,
    String? dataFim,
  }) async {
    try {
      final params = <String, dynamic>{'periodo': periodo};
      if (data != null) params['data'] = data;
      if (mes != null) params['mes'] = mes;
      if (ano != null) params['ano'] = ano;
      if (dataInicio != null) params['data_inicio'] = dataInicio;
      if (dataFim != null) params['data_fim'] = dataFim;

      final response = await _dio.get(
        '/api/mobile/usinas/$idPlanta/desempenho',
        queryParameters: params,
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Erro ao buscar desempenho: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // INVESTIDOR — Geradores
  // Retorna: [{id, codigo_gerador, nome_gerador, cnpj_gerador}]
  // ─────────────────────────────────────────

  static Future<List<Gerador>> getGeradores() async {
    try {
      final response = await _dio.get('/api/mobile/investor/geradores');
      if (response.data['success'] == true) {
        final List<dynamic> json = response.data['geradores'];
        return json.map((j) => Gerador.fromJson(j)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar geradores: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // INVESTIDOR — Dashboard (6 cards)
  // Body: {geradores: ["51-JMD05"]}
  // Retorna: {credito_acumulado, total_beneficiarios, ticket_medio,
  //           performance_alvo, capacidade_total, disponivel_venda}
  // ─────────────────────────────────────────

  static Future<InvestorDashboardData> getDashboardInvestidor(
      List<String> geradores) async {
    try {
      final response = await _dio.post(
        '/api/mobile/investor/dashboard',
        data: {'geradores': geradores},
      );
      if (response.data['success'] == true) {
        return InvestorDashboardData.fromJson(response.data);
      }
      throw Exception('Erro ao buscar dashboard');
    } on DioException catch (e) {
      throw Exception('Erro ao buscar dashboard: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // INVESTIDOR — Gráfico de geração mensal
  // Body: {geradores: ["51-JMD05"], ano: 2026}
  // Retorna: {ano, dados: [{mes, mes_nome, prognostico,
  //   realizado_inversor, compensado, faturado}]}.
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>> getGraficoGeracao({
    required List<String> geradores,
    required int ano,
  }) async {
    try {
      final response = await _dio.post(
        '/api/mobile/investor/grafico',
        data: {'geradores': geradores, 'ano': ano},
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Erro ao buscar gráfico: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // INVESTIDOR — Usinas
  // Retorna: [{id_planta, nome_planta, status_online,
  //   latitude, longitude, potencia_instalada,
  //   potencia_atual, producao_hoje, codigo_gerador, nome_gerador}]
  // ─────────────────────────────────────────

  static Future<List<Usina>> getUsinasInvestidor() async {
    try {
      final response = await _dio.get('/api/mobile/investor/usinas');
      if (response.data['success'] == true) {
        final List<dynamic> json = response.data['usinas'];
        return json.map((j) => Usina.fromJson(j)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar usinas: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // INVESTIDOR — Desempenho de usina
  // Query: periodo=dia|mes|ano|periodo
  //        + data, mes, ano, data_inicio, data_fim
  // Retorna: {stats: {producao_total, potencia_maxima,
  //   horas_operacao}, chart: {labels, potencia/producao, prognostico?}}
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>> getDesempenhoInvestidor(
    int idPlanta, {
    String periodo = 'dia',
    String? data,
    String? mes,
    String? ano,
    String? dataInicio,
    String? dataFim,
  }) async {
    try {
      final params = <String, dynamic>{'periodo': periodo};
      if (data != null) params['data'] = data;
      if (mes != null) params['mes'] = mes;
      if (ano != null) params['ano'] = ano;
      if (dataInicio != null) params['data_inicio'] = dataInicio;
      if (dataFim != null) params['data_fim'] = dataFim;

      final response = await _dio.get(
        '/api/mobile/investor/usinas/$idPlanta/desempenho',
        queryParameters: params,
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Erro ao buscar desempenho: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // INVESTIDOR — Documentos
  // Retorna pastas: [{pasta, total_arquivos}]
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>> getDocumentosPastas() async {
    try {
      final response = await _dio.get('/api/mobile/investor/documentos/pastas');
      return response.data;
    } on DioException catch (e) {
      throw Exception('Erro ao buscar pastas: ${e.message}');
    }
  }

  // Retorna arquivos: [{id, titulo, file_name, file_size,
  //   extensao, uploaded_at}]
  // pasta = null → raiz | pasta = "Contratos" → pasta específica
  static Future<Map<String, dynamic>> getDocumentosArquivos({
    String? pasta,
  }) async {
    try {
      final params = pasta != null ? <String, dynamic>{'pasta': pasta} : null;
      final response = await _dio.get(
        '/api/mobile/investor/documentos/arquivos',
        queryParameters: params,
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Erro ao buscar arquivos: ${e.message}');
    }
  }

  // Download: retorna URL para abrir no browser
  static String getDocumentoDownloadUrl(int arquivoId) {
    return '$_baseUrl/api/mobile/investor/documentos/download/$arquivoId';
  }

  // ─────────────────────────────────────────
  // DRE — Lista usinas do investidor
  // ─────────────────────────────────────────
  static Future<List<dynamic>> getDreUsinas() async {
    try {
      final response = await _dio.get('/api/mobile/investor/dre/usinas');
      if (response.data['success'] == true) {
        return response.data['usinas'] as List;
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar usinas DRE: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // DRE — Dados completos de uma usina/ano
  // Retorna: {linhas, valores, meses_liberados, geracao}
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getDreDados({
    required int idPlanta,
    required int ano,
  }) async {
    try {
      final response = await _dio.get(
        '/api/mobile/investor/dre/dados',
        queryParameters: {'id_planta': idPlanta, 'ano': ano},
      );
      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception(response.data['message'] ?? 'Erro ao buscar DRE');
    } on DioException catch (e) {
      throw Exception('Erro ao buscar DRE: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // CLIENTE: Dashboard saldos
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>> clienteDashboardSaldos() async {
    try {
      final response = await _dio.get('/api/mobile/cliente/dashboard-saldos');
      return response.data;
    } on DioException catch (e) {
      throw Exception('Erro ao buscar dashboard saldos: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // CLIENTE: Último mês
  // ─────────────────────────────────────────
  static Future<Map<String, dynamic>> clienteDashboardUltimoMes({
    String? mes,
  }) async {
    try {
      final params = mes != null ? <String, String>{'mes': mes} : null;
      final response = await _dio.get(
        '/api/mobile/cliente/dashboard-ultimo-mes',
        queryParameters: params,
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Erro ao buscar último mês: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // CLIENTE: Gráfico 12 meses
  // ─────────────────────────────────────────
  static Future<List<dynamic>> clienteDashboardGrafico({
    List<String> contas = const [],
  }) async {
    try {
      final response = await _dio.post(
        '/api/mobile/cliente/dashboard-grafico',
        data: {'contas': contas},
      );
      return response.data['dados_por_mes'] as List? ?? [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar gráfico: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // CLIENTE: Contas disponíveis
  // ─────────────────────────────────────────
  static Future<List<dynamic>> clienteContasDisponiveis() async {
    try {
      final response = await _dio.get('/api/mobile/cliente/contas-disponiveis');
      return response.data['contas'] as List? ?? [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar contas: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // CLIENTE: Contas Neoenergia
  // ─────────────────────────────────────────
  static Future<List<dynamic>> clienteContasNeoenergia() async {
    try {
      final response = await _dio.get('/api/mobile/cliente/contas-neoenergia');
      return response.data['data'] as List? ?? [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar contas Neoenergia: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // CLIENTE: Documentos — pastas
  // ─────────────────────────────────────────
  static Future<List<dynamic>> clienteDocumentosPastas() async {
    try {
      final response = await _dio.get('/api/mobile/cliente/documentos/pastas');
      return response.data['pastas'] as List? ?? [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar pastas: ${e.message}');
    }
  }

  // ─────────────────────────────────────────
  // CLIENTE: Documentos — arquivos
  // ─────────────────────────────────────────
  static Future<List<dynamic>> clienteDocumentosArquivos({
    String? pasta,
  }) async {
    try {
      final params = pasta != null ? <String, String>{'pasta': pasta} : null;
      final response = await _dio.get(
        '/api/mobile/cliente/documentos/arquivos',
        queryParameters: params,
      );
      return response.data['arquivos'] as List? ?? [];
    } on DioException catch (e) {
      throw Exception('Erro ao buscar arquivos: ${e.message}');
    }
  }
}
