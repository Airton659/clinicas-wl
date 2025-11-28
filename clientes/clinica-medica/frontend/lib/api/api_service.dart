// lib/api/api_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:analicegrubert/models/anamnese.dart';
import 'package:analicegrubert/models/consulta.dart';
import 'package:analicegrubert/models/diario.dart';
import 'package:analicegrubert/models/exame.dart';
import 'package:analicegrubert/models/ficha_completa.dart';
import 'package:analicegrubert/models/orientacao.dart';
import 'package:analicegrubert/models/checklist_item.dart';
import 'package:analicegrubert/models/prontuario.dart';
import 'package:analicegrubert/models/paciente.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/models/suporte_psicologico.dart';
import 'package:analicegrubert/models/relatorio_medico.dart';
import 'package:analicegrubert/models/relatorio_detalhado.dart';
import 'package:analicegrubert/models/notificacao.dart';
import 'package:analicegrubert/services/auth_service.dart';
import 'package:analicegrubert/models/tarefa_agendada.dart';
import 'package:analicegrubert/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:analicegrubert/models/registro_diario.dart';
import 'package:analicegrubert/utils/error_handler.dart';
import 'package:analicegrubert/services/cache_manager.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// Estrutura de cache com TTL
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry(this.data, this.ttl) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

class ApiService {
  // URL do backend vem do AppConfig (configurado por cliente)
  final String _baseUrl = AppConfig.apiBaseUrl;
  final AuthService _authService;

  // Função estática para construir URLs de imagem
  static String buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';

    // Se já é uma URL completa, retorna como está
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Se é um caminho relativo, adiciona a URL base do AppConfig
    if (imagePath.startsWith('/')) {
      return '${AppConfig.apiBaseUrl}$imagePath';
    }

    // Se não tem '/' no início, adiciona
    return '${AppConfig.apiBaseUrl}/$imagePath';
  }

  // Cache interno com TTL de 5 minutos por padrão
  final Map<String, CacheEntry> _cache = {};
  final Duration _defaultTtl = const Duration(minutes: 5);
  final CacheManager _cacheManager = CacheManager.instance;

  // Controle de cache por usuário
  DateTime? _lastUserLogin;

  ApiService({required AuthService authService}) : _authService = authService;

  // Métodos de cache
  String _getCacheKey(String endpoint, [Map<String, dynamic>? params]) {
    final userId = _authService.currentUser?.id ?? 'anonymous';
    final negocioId = _authService.getNegocioId() ?? 'default';
    final paramString =
        params?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? '';
    return '${userId}_${negocioId}_${endpoint}_$paramString';
  }

  T? _getFromCache<T>(String cacheKey) {
    final entry = _cache[cacheKey] as CacheEntry<T>?;
    if (entry != null && !entry.isExpired) {
      return entry.data;
    }
    if (entry != null && entry.isExpired) {
      _cache.remove(cacheKey);
    }
    return null;
  }

  void _setCache<T>(String cacheKey, T data, {Duration? ttl}) {
    _cache[cacheKey] = CacheEntry<T>(data, ttl ?? _defaultTtl);
  }

  void clearCache([String? pattern]) async {
    final userId = _authService.currentUser?.id;
    final negocioId = await _authService.getNegocioId();

    // Limpa cache em memória (legacy) - MAIS AGRESSIVO
    if (pattern != null) {
      final keysToRemove =
          _cache.keys.where((key) => key.contains(pattern)).toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    } else {
      _cache.clear();
    }

    // Limpa cache persistente - FORÇADO
    try {
      if (userId != null && negocioId != null) {
        await _cacheManager.clear(
          pattern: pattern,
          userId: userId,
          negocioId: negocioId,
        );
      } else {
        await _cacheManager.clear(pattern: pattern);
      }
    } catch (e) {}

    // FORÇA limpeza adicional para padrões específicos problemáticos
    if (pattern == 'getPacientes') {
      try {
        await _cacheManager.clear(); // Limpa TUDO relacionado a pacientes
      } catch (e) {}
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getIdToken();
    final negocioId = await _authService.getNegocioId();

    if (token != null) {}

    if (token == null || negocioId == null) {
      throw Exception('User not authenticated or negocioId not found.');
    }

    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
      'negocio-id': negocioId,
    };

    return headers;
  }

  // --- ANAMNESE ---

  Future<Anamnese> createAnamnese(
      String pacienteId, Map<String, dynamic> data) async {
    final negocioId = await _authService.getNegocioId();
    final url =
        '$_baseUrl/pacientes/$pacienteId/anamnese?negocio_id=$negocioId';
    final uri = Uri.parse(url);

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return Anamnese.fromJson(json.decode(response.body));
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<List<Anamnese>> getAnamneseHistory(String pacienteId) async {
    final negocioId = await _authService.getNegocioId();
    final url =
        '$_baseUrl/pacientes/$pacienteId/anamnese?negocio_id=$negocioId';
    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((json) => Anamnese.fromJson(json)).toList();
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<Anamnese> updateAnamnese(
      String anamneseId, Map<String, dynamic> data) async {
    final url = '$_baseUrl/anamnese/$anamneseId';
    final uri = Uri.parse(url);

    final response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return Anamnese.fromJson(json.decode(response.body));
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  // --- TESTE DE PROFILE ---

  Future<void> testProfileEndpoint() async {
    try {
      final uri = Uri.parse('$_baseUrl/me/profile');
      final headers = await _getHeaders();

      headers.forEach((key, value) {});

      final response = await http.get(uri, headers: headers);
    } catch (e) {}
  }

  // Método para obter dados atualizados do perfil do usuário
  Future<Usuario?> getCurrentUserProfile() async {
    try {
      final uri = Uri.parse('$_baseUrl/me/profile');
      final headers = await _getHeaders();

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        return Usuario.fromJson(responseBody);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // --- FCM TOKEN (NOTIFICAÇÕES) ---

  Future<void> registerFcmToken(String token) async {
    final uri = Uri.parse('$_baseUrl/me/register-fcm-token');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode({'token': token}),
    );
    if (response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  // --- UPLOAD DE ARQUIVOS ---

  Future<Map<String, dynamic>> uploadFoto(String filePath) async {
    final uri = Uri.parse('$_baseUrl/upload-foto');
    final request = http.MultipartRequest('POST', uri);

    final headers = await _getHeaders();
    request.headers.addAll(headers);

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final uri = Uri.parse('$_baseUrl/upload-file');
    final request = http.MultipartRequest('POST', uri);

    final headers = await _getHeaders();
    request.headers.addAll(headers);

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  // --- MÉTODOS DE CRIAÇÃO DO PLANO DE CUIDADO ---

  // *** MÉTODO CORRIGIDO ***
  Future<Orientacao> createOrientacao(
    String pacienteId,
    String consultaId, // Recebe o ID da consulta separado
    Map<String, dynamic> data,
  ) async {
    // Adiciona o consulta_id como query parameter na URL
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/orientacoes?consulta_id=$consultaId');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data), // O body não contém mais o consulta_id
    );

    if (response.statusCode == 201) {
      final orientacao = Orientacao.fromJson(json.decode(response.body));
      await invalidateRelatedCache('patient_updated', pacienteId: pacienteId);
      return orientacao;
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  // *** MÉTODO CORRIGIDO ***
  Future<ChecklistItem> createChecklistItem(
    String pacienteId,
    String consultaId, // Recebe o ID da consulta separado
    Map<String, dynamic> data,
  ) async {
    // Adiciona o consulta_id como query parameter na URL
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/checklist-itens?consulta_id=$consultaId');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data), // O body não contém mais o consulta_id
    );

    if (response.statusCode == 201) {
      return ChecklistItem.fromJson(json.decode(response.body));
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  // *** MÉTODO CORRIGIDO ***
  Future<void> createMedicacao(
    String pacienteId,
    String consultaId, // Recebe o ID da consulta separado
    Map<String, dynamic> data,
  ) async {
    // Adiciona o consulta_id como query parameter na URL
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/medicacoes?consulta_id=$consultaId');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data), // O body não contém mais o consulta_id
    );

    if (response.statusCode != 201) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> createExame(String pacienteId, Map<String, dynamic> data) async {
    final negocioId = await _authService.getNegocioId();
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/exames?negocio_id=$negocioId');

    final bodyData = Map<String, dynamic>.from(data);

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(bodyData),
    );

    if (response.statusCode != 201) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    // Agendar notificação 24h antes do exame - TEMPORARIAMENTE DESABILITADO
    // print('📝 CRIANDO EXAME - Chamando agendamento de lembrete');
    // await _agendarLembreteExame(pacienteId, data);
  }

  Future<List<Exame>> getExames(String pacienteId,
      {bool forceRefresh = false}) async {
    final cacheKey = _getCacheKey('getExames', {'pacienteId': pacienteId});

    if (!forceRefresh) {
      final cached = _getFromCache<List<Exame>>(cacheKey);
      if (cached != null) return cached;
    }

    final uri = Uri.parse('$_baseUrl/pacientes/$pacienteId/exames');

    try {
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final List<Exame> exames = jsonList
            .map((json) => Exame.fromJson(json as Map<String, dynamic>))
            .toList();

        _setCache(cacheKey, exames, ttl: const Duration(minutes: 5));
        return exames;
      } else if (response.statusCode == 404) {
        _setCache(cacheKey, <Exame>[], ttl: const Duration(minutes: 5));
        return <Exame>[];
      } else {
        throw Exception(ErrorHandler.getApiErrorMessage(response));
      }
    } catch (e) {
      throw Exception(
          'Falha ao carregar exames. Verifique sua conexão ou tente novamente mais tarde.');
    }
  }

  Future<void> updateExame(
      String pacienteId, String exameId, Map<String, dynamic> data) async {
    final negocioId = await _authService.getNegocioId();
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/exames/$exameId?negocio_id=$negocioId');

    final bodyData = Map<String, dynamic>.from(data);

    final response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: json.encode(bodyData),
    );

    if (response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    final cacheKey = _getCacheKey('getExames', {'pacienteId': pacienteId});
    _cache.remove(cacheKey);

    // Agendar notificação 24h antes do exame (com ID do exame) - TEMPORARIAMENTE DESABILITADO
    // print('✏️  ATUALIZANDO EXAME - Chamando agendamento de lembrete');
    // final dataWithId = Map<String, dynamic>.from(data);
    // dataWithId['id'] = exameId;
    // await _agendarLembreteExame(pacienteId, dataWithId);
  }

  Future<void> deleteExame(String pacienteId, String exameId) async {
    final negocioId = await _authService.getNegocioId();
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/exames/$exameId?negocio_id=$negocioId');

    final response = await http.delete(
      uri,
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    final cacheKey = _getCacheKey('getExames', {'pacienteId': pacienteId});
    _cache.remove(cacheKey);
  }

  Future<List<Prontuario>> getProntuarios(String pacienteId,
      {bool forceRefresh = false}) async {
    final cacheKey = _getCacheKey('getProntuarios', {'pacienteId': pacienteId});

    if (!forceRefresh) {
      final cached = _getFromCache<List<Prontuario>>(cacheKey);
      if (cached != null) return cached;
    }

    debugPrint('🔍 BUSCANDO PRONTUÁRIOS - Novo endpoint:');
    debugPrint('📝 Paciente ID: $pacienteId');

    final uri = Uri.parse('$_baseUrl/pacientes/$pacienteId/registros');
    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    debugPrint('📝 Response status: ${response.statusCode}');
    debugPrint('📝 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      final prontuarios =
          jsonData.map((item) => Prontuario.fromJson(item)).toList();

      debugPrint('📝 Prontuários encontrados: ${prontuarios.length}');
      for (int i = 0; i < prontuarios.length; i++) {
        final p = prontuarios[i];
        debugPrint(
            '📝 Prontuário $i: ${p.titulo} - ${p.conteudo.substring(0, p.conteudo.length < 50 ? p.conteudo.length : 50)}...');
      }

      _setCache(cacheKey, prontuarios, ttl: const Duration(minutes: 3));
      return prontuarios;
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> createProntuario(
      String pacienteId, Map<String, dynamic> data) async {
    debugPrint('🔍 CRIANDO PRONTUÁRIO - Novo endpoint:');
    debugPrint('📝 Paciente ID: $pacienteId');
    debugPrint('📝 Dados: $data');

    try {
      final headers = await _getHeaders();
      debugPrint('📝 Headers: $headers');

      final uri = Uri.parse('$_baseUrl/pacientes/$pacienteId/registros');
      debugPrint('📝 URL final: $uri');

      final negocioId = await _authService.getNegocioId();
      final completeData = {
        ...data,
        'paciente_id': pacienteId,
        'negocio_id': negocioId,
      };
      debugPrint('📝 JSON body que será enviado: ${json.encode(completeData)}');

      debugPrint('📝 Fazendo POST request...');
      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(completeData),
      );

      debugPrint('📝 Response status: ${response.statusCode}');
      debugPrint('📝 Response headers: ${response.headers}');
      debugPrint('📝 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ PRONTUÁRIO CRIADO COM SUCESSO!');
      } else {
        debugPrint(
            '❌ ERRO AO CRIAR PRONTUÁRIO - Status: ${response.statusCode}');
        debugPrint('📝 Erro detalhado: ${response.body}');
        throw Exception(ErrorHandler.getApiErrorMessage(response));
      }

      // Limpar cache para forçar reload
      final cacheKey =
          _getCacheKey('getProntuarios', {'pacienteId': pacienteId});
      _cache.remove(cacheKey);
      debugPrint('📝 Cache limpo para chave: $cacheKey');
    } catch (e, stackTrace) {
      debugPrint('❌ EXCEPTION ao criar prontuário: $e');
      debugPrint('📝 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // --- FICHA COMPLETA ---

  Future<FichaCompleta> getFichaCompleta(
    String pacienteId, {
    String? consultaId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey('getFichaCompleta', {
      'pacienteId': pacienteId,
      'consultaId': consultaId ?? 'null',
    });

    if (!forceRefresh) {
      final cached = _getFromCache<FichaCompleta>(cacheKey);
      if (cached != null) return cached;
    }

    String url = '$_baseUrl/pacientes/$pacienteId/ficha-completa';

    if (consultaId != null && consultaId.isNotEmpty) {
      url += '?consulta_id=$consultaId';
    } else {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      url += '?t=$timestamp';
    }

    final uri = Uri.parse(url);

    try {
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);

        // DEBUG: Log do JSON recebido do backend
        debugPrint('🔍 FICHA COMPLETA DEBUG - consultaId: $consultaId');
        debugPrint(
            '📝 Medicações no JSON: ${jsonData['medicacoes']?.length ?? 0}');
        debugPrint(
            '📝 Checklist no JSON: ${jsonData['checklist']?.length ?? 0}');
        debugPrint(
            '📝 Orientações no JSON: ${jsonData['orientacoes']?.length ?? 0}');
        debugPrint(
            '📝 Prontuários no JSON: ${jsonData['prontuarios']?.length ?? 0}');

        final fichaCompleta = FichaCompleta.fromJson(jsonData);

        debugPrint('🔍 FICHA COMPLETA após fromJson:');
        debugPrint('📝 Medicações: ${fichaCompleta.medicacoes.length}');
        debugPrint('📝 Checklist: ${fichaCompleta.checklist.length}');
        debugPrint('📝 Orientações: ${fichaCompleta.orientacoes.length}');

        _setCache(cacheKey, fichaCompleta, ttl: const Duration(minutes: 3));
        return fichaCompleta;
      } else {
        throw Exception(ErrorHandler.getApiErrorMessage(response));
      }
    } catch (e) {
      throw Exception(
          'Falha ao carregar os dados do paciente. Verifique sua conexão ou tente novamente mais tarde.');
    }
  }

  // --- PACIENTES ---

  Future<void> updatePatientPersonalData(
      String pacienteId, Map<String, dynamic> data) async {
    try {
      final userId = _authService.currentUser?.id;
      final negocioId = await _authService.getNegocioId();
      final token = await _authService.getIdToken();

      if (userId == null || negocioId == null || token == null) {
        throw Exception(
            'Usuário não autenticado ou dados de negócio indisponíveis');
      }

      final url =
          '$_baseUrl/pacientes/$pacienteId/dados-pessoais?negocio_id=$negocioId';

      final headers = <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      };

      final response = await http
          .put(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        _invalidatePatientCache(userId, negocioId);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['detail'] ?? 'Erro ao atualizar dados pessoais');
      }
    } catch (e) {
      rethrow;
    }
  }

  void _invalidatePatientCache(String userId, String negocioId) {
    final keys =
        _cache.keys.where((key) => key.contains('getPacientes')).toList();
    for (final key in keys) {
      _cache.remove(key);
    }
  }

  Future<List<Paciente>> getPacientes({bool forceRefresh = false}) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';
    final userRole = _authService.currentUser
            ?.roles?[await _authService.getNegocioId() ?? 'default'] ??
        'unknown';
    final negocioId = await _authService.getNegocioId() ?? 'default';

    final currentTime = DateTime.now();
    if (_lastUserLogin == null ||
        currentTime.difference(_lastUserLogin!) > const Duration(minutes: 2)) {
      _lastUserLogin = currentTime;
      forceRefresh = true;
    }

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(
        'getPacientes',
        userId,
        negocioId,
      );
      if (cached != null) {
        final pacientes =
            cached.map((json) => Paciente.fromJson(json)).toList();

        _preloadPatientDetails(pacientes.take(3).toList());

        return pacientes;
      }
    }

    final uri = Uri.parse('$_baseUrl/me/pacientes');

    try {
      final headers = await _getHeaders();
      headers.forEach((key, value) {});

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);

        for (int i = 0; i < jsonData.length && i < 3; i++) {
          final patientData = jsonData[i];
        }

        final pacientes =
            jsonData.map((json) => Paciente.fromJson(json)).toList();

        await _cacheManager.set(
          'getPacientes',
          jsonData,
          userId,
          negocioId,
          ttl: const Duration(minutes: 5),
        );

        _preloadPatientDetails(pacientes.take(3).toList());

        return pacientes;
      } else {
        throw Exception(
          'Failed to load patients. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      final cached = await _cacheManager.get<List<dynamic>>(
        'getPacientes',
        userId,
        negocioId,
      );
      if (cached != null) {
        final pacientes =
            cached.map((json) => Paciente.fromJson(json)).toList();

        _preloadPatientDetails(pacientes.take(3).toList());

        return pacientes;
      }

      rethrow;
    }
  }

  // --- CONSULTAS ---

  Future<Consulta> createConsulta(
    String pacienteId,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$_baseUrl/pacientes/$pacienteId/consultas');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 201) {
      return Consulta.fromJson(json.decode(response.body));
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  // --- DIÁRIO SIMPLES (MANTIDO PARA COMPATIBILIDADE) ---

  Future<List<Diario>> getDiario(String pacienteId) async {
    final uri = Uri.parse('$_baseUrl/pacientes/$pacienteId/diario');
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((json) => Diario.fromJson(json)).toList();
    } else {
      throw Exception(
        'Failed to load diario. Status code: ${response.statusCode}',
      );
    }
  }

  Future<Diario> createDiario(
    String pacienteId,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$_baseUrl/pacientes/$pacienteId/diario');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 201) {
      return Diario.fromJson(json.decode(response.body));
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<Diario> updateDiario(
    String diarioId,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$_baseUrl/diario/$diarioId');
    final response = await http.patch(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return Diario.fromJson(json.decode(response.body));
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> deleteDiario(String diarioId) async {
    final uri = Uri.parse('$_baseUrl/diario/$diarioId');
    final response = await http.delete(uri, headers: await _getHeaders());

    if (response.statusCode != 204) {
      throw Exception(
        'Failed to delete diario entry. Status code: ${response.statusCode}',
      );
    }
  }

  // --- USUÁRIOS E PATIENTS ---

  Future<Usuario> createPatient(Map<String, dynamic> data) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) {
      throw Exception('Negocio ID não encontrado.');
    }

    final uri = Uri.parse('$_baseUrl/negocios/$negocioId/pacientes');

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      clearCache('getAllUsersInBusiness');
      clearCache('getAllPatients');

      return Usuario.fromJson(json.decode(response.body));
    } else {
      throw Exception('Falha ao criar paciente.');
    }
  }

  Future<void> updatePatientAddress(
      String patientId, Map<String, dynamic> addressData) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) {
      throw Exception("Negocio ID não encontrado para adicionar à URL.");
    }

    final url = '$_baseUrl/pacientes/$patientId/endereco?negocio_id=$negocioId';
    final uri = Uri.parse(url);

    final response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: json.encode(addressData),
    );

    if (response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    // Invalidar cache após atualização bem-sucedida
    await invalidateRelatedCache('patient_updated', pacienteId: patientId);
  }

  Future<Usuario> syncProfile(Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/users/sync-profile');

    final headers = await _getHeaders();
    final body = json.encode(data);

    final response = await http
        .post(
          uri,
          headers: headers,
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic jsonData = json.decode(response.body);
      if (jsonData is Map<String, dynamic>) {
        jsonData.forEach((k, v) {});
      }

      return Usuario.fromJson(jsonData);
    } else {
      if (response.statusCode == 500) {
        throw Exception(
            'Erro interno do servidor (500). O backend pode estar temporariamente indisponível.');
      } else if (response.statusCode == 404) {
        throw Exception(
            'Endpoint não encontrado (404). Verifique se o backend está rodando a versão correta.');
      } else if (response.statusCode == 403) {
        throw Exception(
            'Acesso negado (403). O usuário pode não ter permissão para este negócio.');
      } else {
        throw Exception(
            'Falha ao sincronizar o perfil do usuário. Status: ${response.statusCode}');
      }
    }
  }

  Future<Usuario?> updateUserProfile(Map<String, dynamic> data,
      {Uint8List? imageBytes}) async {
    final uri = Uri.parse('$_baseUrl/me/profile');

    final headers = await _getHeaders();

    final updateData = <String, dynamic>{
      'nome': data['nome'],
      'telefone': data['telefone'],
    };

    if (data.containsKey('endereco') && data['endereco'] != null) {
      updateData['endereco'] = data['endereco'];
    }

    if (imageBytes != null) {
      final base64Image = base64Encode(imageBytes);
      updateData['profile_image'] = 'data:image/jpeg;base64,$base64Image';
    }

    updateData.removeWhere((key, value) => value == null || value == '');

    final safeLogData = Map.from(updateData);
    if (safeLogData.containsKey('profile_image')) {
      safeLogData['profile_image'] = '...base64_data...';
    }

    final response = await http.put(
      uri,
      headers: headers,
      body: json.encode(updateData),
    );

    if (response.statusCode == 200) {
      clearCache('getAllUsersInBusiness');
      clearCache('syncProfile');

      try {
        final responseData = json.decode(response.body);
        if (responseData['user'] != null) {
          return Usuario.fromJson(responseData['user']);
        }
      } catch (e) {}

      return null;
    } else if (response.statusCode == 204) {
      clearCache('getAllUsersInBusiness');
      clearCache('syncProfile');

      return null;
    } else {
      throw Exception(
          'Erro ao atualizar perfil: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    final uri = Uri.parse('$_baseUrl/me/register-fcm-token');

    final headers = await _getHeaders();

    final updateData = {'fcm_token': fcmToken};

    debugPrint('🔗 FCM_DEBUG: Enviando para: ${uri.toString()}');
    debugPrint('🔗 FCM_DEBUG: Payload: ${json.encode(updateData)}');

    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode(updateData),
    );

    debugPrint('🔗 FCM_DEBUG: Status: ${response.statusCode}');
    debugPrint('🔗 FCM_DEBUG: Response: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      debugPrint('✅ FCM_DEBUG: Token registrado com sucesso!');
    } else {
      throw Exception(
          'Erro ao enviar token FCM: ${response.statusCode} - ${response.body}');
    }
  }

  /// Registra token APNs (Safari Web Push) no backend
  Future<void> registerApnsToken(String apnsToken) async {
    final uri = Uri.parse('$_baseUrl/me/register-apns-token');

    final headers = await _getHeaders();

    final updateData = {'apns_token': apnsToken};

    debugPrint('🍎 APNS_DEBUG: Enviando para: ${uri.toString()}');
    debugPrint(
        '🍎 APNS_DEBUG: Token (preview): ${apnsToken.substring(0, 50)}...');

    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode(updateData),
    );

    debugPrint('🍎 APNS_DEBUG: Status: ${response.statusCode}');
    debugPrint('🍎 APNS_DEBUG: Response: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      debugPrint('✅ APNS_DEBUG: Token APNs registrado com sucesso!');
    } else {
      throw Exception(
          'Erro ao enviar token APNs: ${response.statusCode} - ${response.body}');
    }
  }

  /// Remove token APNs do backend
  Future<void> removeApnsToken(String apnsToken) async {
    final uri = Uri.parse('$_baseUrl/me/remove-apns-token');

    final headers = await _getHeaders();

    final updateData = {'apns_token': apnsToken};

    debugPrint('🍎 APNS_DEBUG: Removendo token APNs...');

    final response = await http.delete(
      uri,
      headers: headers,
      body: json.encode(updateData),
    );

    debugPrint('🍎 APNS_DEBUG: Status: ${response.statusCode}');
    debugPrint('🍎 APNS_DEBUG: Response: ${response.body}');

    if (response.statusCode == 200) {
      debugPrint('✅ APNS_DEBUG: Token APNs removido com sucesso!');
    } else {
      throw Exception(
          'Erro ao remover token APNs: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Map<String, dynamic>> debugTechnicianNotifications() async {
    final uri = Uri.parse('$_baseUrl/tasks/debug-technician-notifications');

    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
          '🔍 Debug Technician Notifications Response: ${response.statusCode}');
      debugPrint('🔍 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erro ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erro ao testar notificações de técnico: $e');
      rethrow;
    }
  }

  Future<List<Usuario>> getAllUsersInBusiness(
      {String status = 'ativo', bool forceRefresh = false}) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';
    final negocioId = await _authService.getNegocioId() ?? 'default';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(
        'getAllUsersInBusiness',
        userId,
        negocioId,
        params: {'status': status},
      );
      if (cached != null) {
        return cached.map((json) => Usuario.fromJson(json)).toList();
      }
    }

    if (negocioId == 'default') throw Exception('Negocio ID não encontrado.');

    String url = '$_baseUrl/negocios/$negocioId/usuarios';
    if (status == 'all') {
      url += '?status=all';
    }

    final uri = Uri.parse(url);

    try {
      final headers = await _getHeaders();
      headers.forEach((key, value) {});

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final usuarios =
            jsonData.map((json) => Usuario.fromJson(json)).toList();

        await _cacheManager.set(
          'getAllUsersInBusiness',
          jsonData,
          userId,
          negocioId,
          params: {'status': status},
          ttl: const Duration(minutes: 5),
        );
        return usuarios;
      } else if (response.statusCode == 403) {
        final emptyList = <Usuario>[];
        await _cacheManager.set(
          'getAllUsersInBusiness',
          [],
          userId,
          negocioId,
          params: {'status': status},
          ttl: const Duration(minutes: 5),
        );
        return emptyList;
      } else {
        throw Exception('Falha ao carregar a lista de usuários.');
      }
    } catch (e) {
      final cached = await _cacheManager.get<List<dynamic>>(
        'getAllUsersInBusiness',
        userId,
        negocioId,
        params: {'status': status},
      );
      if (cached != null) {
        return cached.map((json) => Usuario.fromJson(json)).toList();
      }

      rethrow;
    }
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri = Uri.parse(
      '$_baseUrl/negocios/$negocioId/usuarios/$userId/role',
    );

    final response = await http.patch(
      uri,
      headers: await _getHeaders(),
      body: json.encode({'role': newRole}),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar o papel do usuário.');
    }

    clearCache('getAllUsersInBusiness');
  }

  Future<void> updateUserStatus(String userId, String status) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri =
        Uri.parse('$_baseUrl/negocios/$negocioId/usuarios/$userId/status');

    final response = await http.patch(
      uri,
      headers: await _getHeaders(),
      body: json.encode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar o status do usuário.');
    }

    clearCache('getAllUsersInBusiness');
  }

  Future<void> updateUserConsent(String userId, bool consentimentoLgpd,
      DateTime dataConsentimento, String tipoConsentimento) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri =
        Uri.parse('$_baseUrl/negocios/$negocioId/usuarios/$userId/consent');

    final response = await http.patch(
      uri,
      headers: await _getHeaders(),
      body: json.encode({
        'consentimento_lgpd': consentimentoLgpd,
        'data_consentimento_lgpd': dataConsentimento.toIso8601String(),
        'tipo_consentimento': tipoConsentimento,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar o consentimento do usuário.');
    }

    clearCache('getAllUsersInBusiness');
  }

  Future<void> updateMyConsent(bool consentimentoLgpd,
      DateTime dataConsentimento, String tipoConsentimento) async {
    final uri = Uri.parse('$_baseUrl/me/consent');

    final headers = await _getHeaders();

    final body = json.encode({
      'consentimento_lgpd': consentimentoLgpd,
      'data_consentimento_lgpd': dataConsentimento.toIso8601String(),
      'tipo_consentimento': tipoConsentimento,
    });

    final response = await http.patch(
      uri,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar o consentimento.');
    }
  }

  Future<Usuario?> getPatientById(String patienteId) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    // TENTATIVA 1
    final uri = Uri.parse('$_baseUrl/negocios/$negocioId/usuarios/$patienteId');

    try {
      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        // ==========================================================
        // PRINT ADICIONADO AQUI
        print('>>> TENTATIVA 1 (/usuarios) JSON CRU: ${response.body}');
        // ==========================================================
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return Usuario.fromJson(jsonData);
      } else if (response.statusCode == 403) {
        // Apenas log, vai tentar o próximo
      } else if (response.statusCode == 404) {
        // Apenas log, vai tentar o próximo
      } else {
        // Apenas log, vai tentar o próximo
      }
    } catch (e) {
      // Apenas log, vai tentar o próximo
    }

    // TENTATIVA 2 (FALLBACK)
    final pacienteUri =
        Uri.parse('$_baseUrl/pacientes/$patienteId/dados-completos');

    try {
      final response =
          await http.get(pacienteUri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        // ==========================================================
        // PRINT ADICIONADO AQUI
        print('>>> TENTATIVA 2 (/dados-completos) JSON CRU: ${response.body}');
        // ==========================================================
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return Usuario.fromJson(jsonData);
      }
    } catch (e) {
      // Apenas log, vai tentar o próximo
    }

    // TENTATIVA 3 (FALLBACK FINAL)
    try {
      final List<Paciente> pacientes = await getPacientes();

      final paciente = pacientes.where((p) => p.id == patienteId).firstOrNull;
      if (paciente != null) {
        final usuario = Usuario(
          id: paciente.id,
          nome: paciente.nome,
          email: paciente.email,
          firebaseUid: '',
          roles: {},
          telefone: paciente.telefone,
          endereco: paciente.endereco,
        );

        return usuario;
      } else {}
    } catch (e) {}

    return null;
  }

// --- VINCULAÇÕES ---

  Future<void> linkPatientToNurse(
    String patientId,
    String? nurseProfileId,
  ) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri = Uri.parse('$_baseUrl/negocios/$negocioId/vincular-paciente');

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode({
        'paciente_id': patientId,
        'enfermeiro_id': nurseProfileId, // CORREÇÃO APLICADA AQUI
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao vincular/desvincular paciente ao enfermeiro.');
    }

    clearCache('getAllUsersInBusiness');
    clearCache('getPacientes');
  }

  Future<void> linkTechniciansToPatient(
    String patientId,
    List<String> technicianIds,
  ) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri = Uri.parse(
      '$_baseUrl/negocios/$negocioId/pacientes/$patientId/vincular-tecnicos',
    );

    final response = await http.patch(
      uri,
      headers: await _getHeaders(),
      body: json
          .encode({'tecnicos_ids': technicianIds}), // CORREÇÃO APLICADA AQUI
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao vincular técnicos ao paciente.');
    }

    clearCache('getAllUsersInBusiness');
    clearCache('getPacientes');
  }

  Future<void> linkSupervisorToTechnician(
    String technicianId,
    String? supervisorId,
  ) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri = Uri.parse(
      '$_baseUrl/negocios/$negocioId/usuarios/$technicianId/vincular-supervisor',
    );

    final response = await http.patch(
      uri,
      headers: await _getHeaders(),
      body: json.encode({'supervisor_id': supervisorId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao vincular/desvincular supervisor ao técnico.');
    }

    clearCache('getAllUsersInBusiness');
    clearCache('getPacientes');
  }

  Future<void> linkPatientToDoctor(
    String patientId,
    String? doctorId,
  ) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri = Uri.parse(
      '$_baseUrl/negocios/$negocioId/pacientes/$patientId/vincular-medico',
    );

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body:
          json.encode({'medico_id': doctorId}), // Chave confirmada pelo backend
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao vincular/desvincular médico ao paciente.');
    }

    clearCache('getAllUsersInBusiness');
    clearCache('getPacientes');
  }

  // --- NOVOS MÉTODOS: CONFIRMAÇÃO DE LEITURA ---

  Future<void> confirmPlanReading(
      String patientId, String consultaId, String usuarioId) async {
    final uri = Uri.parse('$_baseUrl/pacientes/$patientId/confirmar-leitura');

    final body = {
      'plano_version_id': consultaId,
      'usuario_id': usuarioId,
    };

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao confirmar leitura do plano.');
    }
  }

  Future<Map<String, dynamic>> getPlanReadingStatus(String patientId) async {
    final uri =
        Uri.parse('$_baseUrl/pacientes/$patientId/confirmar-leitura/status');
    http.Response response;

    try {
      final headers = await _getHeaders();

      response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Código: ${response.statusCode}, Resposta: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  @deprecated
  Future<bool> checkPlanReading(String patientId, String date) async {
    try {
      final status = await getPlanReadingStatus(patientId);
      return status['leitura_confirmada'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // --- CHECKLIST DIÁRIO COM SUPORTE A FILTROS ---

  Future<List<ChecklistItem>> getDailyChecklist(
    String patientId, {
    String? date,
    bool forceRefresh = false,
  }) async {
    try {
      final queryDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final userId = _authService.currentUser?.id ?? 'anonymous';
      final negocioId = await _authService.getNegocioId() ?? 'default';

      if (!forceRefresh) {
        final cached = await _cacheManager.get<List<dynamic>>(
          'getDailyChecklist_$queryDate',
          userId,
          negocioId,
          params: {'pacienteId': patientId},
        );
        if (cached != null) {
          return cached.map((json) => ChecklistItem.fromJson(json)).toList();
        }
      }

      String url =
          '$_baseUrl/pacientes/$patientId/checklist-diario?data=$queryDate';
      final uri = Uri.parse(url);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final items =
            jsonData.map((json) => ChecklistItem.fromJson(json)).toList();

        await _cacheManager.set(
          'getDailyChecklist_$queryDate',
          jsonData,
          userId,
          negocioId,
          params: {'pacienteId': patientId},
          ttl: const Duration(minutes: 2),
        );

        return items;
      } else if (response.statusCode == 404) {
        return [];
      } else if (response.statusCode == 401) {
        throw Exception(
            'Sem autorização para acessar checklist diário. Verifique seu login.');
      } else if (response.statusCode == 403) {
        throw Exception(
            'Sem permissão para acessar checklist diário deste paciente.');
      } else {
        throw Exception(
            'Falha ao buscar checklist diário (Status: ${response.statusCode}).');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Status:')) {
        rethrow;
      }
      return [];
    }
  }

  Future<void> updateChecklistItem(
    String patientId,
    String itemId,
    bool isCompleted, {
    String? date,
  }) async {
    final queryDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    String url =
        '$_baseUrl/pacientes/$patientId/checklist-diario/$itemId?data=$queryDate';

    final uri = Uri.parse(url);

    try {
      final response = await http
          .patch(
            uri,
            headers: await _getHeaders(),
            body: json.encode({'concluido': isCompleted}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(ErrorHandler.getApiErrorMessage(response));
      }

      await invalidateRelatedCache('checklist_updated', pacienteId: patientId);
    } catch (e) {
      throw Exception(
          'Falha ao atualizar o item do checklist. Verifique sua conexão ou tente novamente mais tarde.');
    }
  }

  Future<List<Usuario>> getTecnicosSupervisionados(String pacienteId) async {
    final negocioId = await _authService.getNegocioId() ?? 'default';
    final userRole = _authService.currentUser?.roles?[negocioId] ?? 'unknown';
    final userId = _authService.currentUser?.id ?? 'anonymous';

    final uri = Uri.parse(
      '$_baseUrl/pacientes/$pacienteId/tecnicos-supervisionados',
    );

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);

      for (int i = 0; i < jsonData.length && i < 5; i++) {
        final tecnicoData = jsonData[i];
      }

      return jsonData.map((json) => Usuario.fromJson(json)).toList();
    } else {
      throw Exception(
        'Falha ao buscar técnicos supervisionados. Status code: ${response.statusCode}',
      );
    }
  }

  // --- REGISTROS DIÁRIOS COM FILTROS ATUALIZADOS ---

  Future<List<RegistroDiario>> getRegistrosDiario(
    String pacienteId, {
    String? date,
    String? tipo,
    bool forceRefresh = false,
  }) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';
    final negocioId = await _authService.getNegocioId() ?? 'default';
    final queryDate = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(
        'getRegistrosDiario_$queryDate',
        userId,
        negocioId,
        params: {'pacienteId': pacienteId, 'tipo': tipo ?? 'all'},
      );
      if (cached != null) {
        return cached.map((json) => RegistroDiario.fromJson(json)).toList();
      }
    }

    String url = '$_baseUrl/pacientes/$pacienteId/registros';

    final queryParams = <String>[];
    if (date != null) queryParams.add('data=$date');
    if (tipo != null) queryParams.add('tipo=$tipo');

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final uri = Uri.parse(url);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      final registros =
          jsonData.map((json) => RegistroDiario.fromJson(json)).toList();

      await _cacheManager.set(
        'getRegistrosDiario_$queryDate',
        jsonData,
        userId,
        negocioId,
        params: {'pacienteId': pacienteId, 'tipo': tipo ?? 'all'},
        ttl: const Duration(minutes: 2),
      );

      return registros;
    } else {
      throw Exception(
        'Failed to load registros diario. Status code: ${response.statusCode}',
      );
    }
  }

  Future<RegistroDiario> createRegistroDiario(
    String pacienteId,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$_baseUrl/pacientes/$pacienteId/registros');

    final negocioId = await _authService.getNegocioId();
    final completeData = {
      ...data,
      'paciente_id': pacienteId,
      'negocio_id': negocioId,
    };

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(completeData),
    );

    if (response.statusCode == 201) {
      final registro = RegistroDiario.fromJson(json.decode(response.body));

      await invalidateRelatedCache('registry_created', pacienteId: pacienteId);

      return registro;
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<RegistroDiario> updateRegistroDiario(
    String pacienteId,
    String registroId,
    Map<String, dynamic> data,
  ) async {
    final uri =
        Uri.parse('$_baseUrl/pacientes/$pacienteId/registros/$registroId');

    final response = await http.patch(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return RegistroDiario.fromJson(json.decode(response.body));
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> deleteRegistroDiario(
      String pacienteId, String registroId) async {
    final uri =
        Uri.parse('$_baseUrl/pacientes/$pacienteId/registros/$registroId');

    final response = await http.delete(uri, headers: await _getHeaders());

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(
        'Failed to delete registro diario. Status code: ${response.statusCode}',
      );
    }
  }

  Future<List<RegistroDiario>> getRegistrosDiarioByDate(
    String pacienteId,
    String date,
  ) async {
    return getRegistrosDiario(pacienteId, date: date);
  }

  Future<List<RegistroDiario>> getRegistrosDiarioByType(
    String pacienteId,
    String tipo,
  ) async {
    return getRegistrosDiario(pacienteId, tipo: tipo);
  }

  Future<void> addStructuredDiaryEntry(
    String patientId,
    Map<String, dynamic> entryData,
  ) async {
    await createRegistroDiario(patientId, entryData);
  }

  // --- CACHE PREDICTIVO ---

  void _preloadPatientDetails(List<Paciente> pacientes) {
    if (pacientes.isEmpty) return;

    Future.delayed(const Duration(milliseconds: 500), () async {
      for (final paciente in pacientes) {
        try {
          final userId = _authService.currentUser?.id ?? 'anonymous';
          final negocioId = await _authService.getNegocioId() ?? 'default';

          final cached = await _cacheManager.get<Map<String, dynamic>>(
            'getFichaCompleta',
            userId,
            negocioId,
            params: {
              'pacienteId': paciente.id,
              'consultaId': 'null',
            },
          );

          if (cached == null) {
            await getFichaCompleta(paciente.id, forceRefresh: false);

            await Future.delayed(const Duration(milliseconds: 200));
          } else {}
        } catch (e) {}
      }
    });
  }

  Future<void> preloadRelatedData(String context,
      {String? pacienteId, String? userRole}) async {
    try {
      final userId = _authService.currentUser?.id ?? 'anonymous';
      final negocioId = await _authService.getNegocioId() ?? 'default';

      switch (context) {
        case 'patient_details':
          if (pacienteId != null) {
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final checklistCached = await _cacheManager.get<List<dynamic>>(
              'getDailyChecklist_$today',
              userId,
              negocioId,
              params: {'pacienteId': pacienteId},
            );

            if (checklistCached == null) {
              Future.delayed(const Duration(milliseconds: 300), () async {
                try {
                  await getDailyChecklist(pacienteId, date: today);
                } catch (e) {}
              });
            }

            final registrosCached = await _cacheManager.get<List<dynamic>>(
              'getRegistrosDiario_$today',
              userId,
              negocioId,
              params: {'pacienteId': pacienteId},
            );

            if (registrosCached == null) {
              Future.delayed(const Duration(milliseconds: 600), () async {
                try {
                  await getRegistrosDiario(pacienteId, date: today);
                } catch (e) {}
              });
            }
          }
          break;

        case 'home_screen':
          if (userRole == 'admin') {
            final usersCached = await _cacheManager.get<List<dynamic>>(
              'getAllUsersInBusiness',
              userId,
              negocioId,
              params: {'status': 'ativo'},
            );

            if (usersCached == null) {
              Future.delayed(const Duration(milliseconds: 800), () async {
                try {
                  await getAllUsersInBusiness(
                      status: 'ativo', forceRefresh: false);
                } catch (e) {}
              });
            }
          }
          break;

        case 'supervisor_diary':
          if (pacienteId != null) {
            Future.delayed(const Duration(milliseconds: 400), () async {
              try {
                await getTecnicosSupervisionados(pacienteId);
              } catch (e) {}
            });
          }
          break;
      }
    } catch (e) {}
  }

  Future<void> invalidateRelatedCache(String action,
      {String? pacienteId}) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';
    final negocioId = await _authService.getNegocioId() ?? 'default';

    try {
      switch (action) {
        case 'patient_updated':
          if (pacienteId != null) {
            await _cacheManager.clear(
              pattern: 'getFichaCompleta',
              userId: userId,
              negocioId: negocioId,
            );

            await _cacheManager.clear(
              pattern: 'getPacientes',
              userId: userId,
              negocioId: negocioId,
            );
          }
          break;

        case 'checklist_updated':
          if (pacienteId != null) {
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            await _cacheManager.clear(
              pattern: 'getDailyChecklist_$today',
              userId: userId,
              negocioId: negocioId,
            );

            await _cacheManager.clear(
              pattern: 'getFichaCompleta',
              userId: userId,
              negocioId: negocioId,
            );

            await _cacheManager.clear(
              pattern: 'getFichaCompleta_pacienteId=$pacienteId',
              userId: userId,
              negocioId: negocioId,
            );

            _cache.clear();
          }
          break;

        case 'registry_created':
          if (pacienteId != null) {
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            await _cacheManager.clear(
              pattern: 'getRegistrosDiario_$today',
              userId: userId,
              negocioId: negocioId,
            );
          }
          break;

        case 'user_role_updated':
          await _cacheManager.clear(
            pattern: 'getAllUsersInBusiness',
            userId: userId,
            negocioId: negocioId,
          );

          break;
      }
    } catch (e) {}
  }

  // --- SUPORTE PSICOLÓGICO ---

  Future<List<SuportePsicologico>> getSuportePsicologico(String pacienteId,
      {bool forceRefresh = false}) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';
    final negocioId = await _authService.getNegocioId() ?? 'default';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(
        'getSuportePsicologico',
        userId,
        negocioId,
        params: {'pacienteId': pacienteId},
      );
      if (cached != null) {
        return cached.map((json) => SuportePsicologico.fromJson(json)).toList();
      }
    }

    final negocioIdQuery = await _authService.getNegocioId();
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/suporte-psicologico?negocio_id=$negocioIdQuery');

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      final suportes =
          jsonData.map((json) => SuportePsicologico.fromJson(json)).toList();

      await _cacheManager.set(
        'getSuportePsicologico',
        jsonData,
        userId,
        negocioId,
        params: {'pacienteId': pacienteId},
        ttl: const Duration(minutes: 5),
      );

      return suportes;
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<SuportePsicologico> createSuportePsicologico(
    String pacienteId,
    Map<String, dynamic> data,
  ) async {
    final negocioId = await _authService.getNegocioId();
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/suporte-psicologico?negocio_id=$negocioId');

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 201) {
      final suporte = SuportePsicologico.fromJson(json.decode(response.body));

      await invalidateSuportePsicologicoCache(pacienteId);

      return suporte;
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<SuportePsicologico> updateSuportePsicologico(
    String pacienteId,
    String suporteId,
    Map<String, dynamic> data,
  ) async {
    final negocioId = await _authService.getNegocioId();
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/suporte-psicologico/$suporteId?negocio_id=$negocioId');

    final response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      final suporte = SuportePsicologico.fromJson(json.decode(response.body));

      await invalidateSuportePsicologicoCache(pacienteId);

      return suporte;
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> deleteSuportePsicologico(
      String pacienteId, String suporteId) async {
    final negocioId = await _authService.getNegocioId();
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/suporte-psicologico/$suporteId?negocio_id=$negocioId');

    final response = await http.delete(uri, headers: await _getHeaders());

    if (response.statusCode == 200 || response.statusCode == 204) {
      await invalidateSuportePsicologicoCache(pacienteId);
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> invalidateSuportePsicologicoCache(String pacienteId) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';
    final negocioId = await _authService.getNegocioId() ?? 'default';

    try {
      await _cacheManager.clear(
        pattern: 'getSuportePsicologico',
        userId: userId,
        negocioId: negocioId,
      );
    } catch (e) {}
  }

  // ================== RELATÓRIOS MÉDICOS ==================

  Future<RelatorioMedico> createRelatorio(String pacienteId, String medicoId,
      {String? conteudo}) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/relatorios?negocio_id=$negocioId');

    final bodyMap = {
      'medico_id': medicoId,
      'negocio_id': negocioId,
    };

    if (conteudo != null && conteudo.trim().isNotEmpty) {
      bodyMap['conteudo'] = conteudo.trim();
    }

    final body = json.encode(bodyMap);

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: body,
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return RelatorioMedico.fromJson(jsonData);
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<List<RelatorioMedico>> getRelatoriosPaciente(String pacienteId) async {
    try {
      final negocioId = await _authService.getNegocioId();
      final uri = Uri.parse(
          '$_baseUrl/pacientes/$pacienteId/relatorios?negocio_id=$negocioId');

      final headers = await _getHeaders();

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        for (int i = 0; i < jsonList.length; i++) {
          final fotosCount =
              (jsonList[i]['fotos'] as List<dynamic>?)?.length ?? 0;
        }
        return jsonList.map((json) => RelatorioMedico.fromJson(json)).toList();
      } else {
        if (response.statusCode == 500) {
          throw Exception(
              'Erro interno do servidor ao buscar relatórios. Tente novamente em alguns instantes.');
        }
        throw Exception(ErrorHandler.getApiErrorMessage(response));
      }
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  Future<void> addRelatorioFotos(String relatorioId, List<XFile> fotos) async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    debugPrint(
        '[FOTO_DEBUG] 📸 Iniciando upload de ${fotos.length} fotos para relatório $relatorioId');
    final uri = Uri.parse('$_baseUrl/relatorios/$relatorioId/fotos');

    final request = http.MultipartRequest('POST', uri);
    final headers = await _getHeaders();
    // Limpa o content-type padrão para que o http.MultipartRequest defina o boundary correto
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    request.fields['negocio_id'] = negocioId;
    debugPrint('[FOTO_DEBUG] ✅ negocio_id adicionado: $negocioId');

    for (int i = 0; i < fotos.length; i++) {
      final foto = fotos[i];
      try {
        debugPrint('[FOTO_DEBUG] 📁 Adicionando foto ${i + 1}: ${foto.name}');
        final bytes = await foto.readAsBytes();
        final file = http.MultipartFile.fromBytes(
          'files', // Nome do campo esperado pelo backend
          bytes,
          filename: foto.name,
          contentType: MediaType(
              'image', 'jpeg'), // Ajuste o tipo se for o caso (png, etc)
        );
        request.files.add(file);
        debugPrint(
            '[FOTO_DEBUG] ✅ Foto ${i + 1} adicionada com sucesso (${file.length} bytes)');
      } catch (e) {
        debugPrint('[FOTO_DEBUG] ❌ Erro ao adicionar foto ${i + 1}: $e');
      }
    }

    if (request.files.isEmpty) {
      debugPrint(
          '[FOTO_DEBUG] ⚠️ Nenhuma foto foi adicionada. Abortando upload.');
      // Opcional: Lançar um erro ou retornar informando que não há fotos
      // throw Exception('Nenhuma foto selecionada ou válida para upload.');
      return;
    }

    debugPrint('[FOTO_DEBUG] 🚀 Enviando requisição...');
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    debugPrint('[FOTO_DEBUG] 📥 Status: ${response.statusCode}');
    debugPrint('[FOTO_DEBUG] 📥 Response: $responseBody');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Erro ao adicionar fotos: ${response.statusCode} - $responseBody');
    }

    debugPrint('[FOTO_DEBUG] ✅ Upload concluído com sucesso!');
  }

  Future<List<RelatorioMedico>> getRelatoriosPendentes() async {
    final uri = Uri.parse('$_baseUrl/medico/relatorios/pendentes');
    final headers = await _getHeaders();

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      for (int i = 0; i < jsonList.length; i++) {}
      return jsonList.map((json) => RelatorioMedico.fromJson(json)).toList();
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<List<RelatorioMedico>> getRelatoriosMedico({String? status}) async {
    String endpoint = '$_baseUrl/medico/relatorios';
    if (status != null && status.isNotEmpty) {
      endpoint += '?status=$status';
    }

    final uri = Uri.parse(endpoint);
    final headers = await _getHeaders();

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);

      for (int i = 0; i < jsonList.length; i++) {
        final relatorio = jsonList[i];
      }

      // Converter JSON para objetos e ordenar por data (mais recente primeiro)
      final relatorios =
          jsonList.map((json) => RelatorioMedico.fromJson(json)).toList();
      relatorios.sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
      return relatorios;
    } else {
      throw Exception('Erro ao buscar relatórios: ${response.statusCode}');
    }
  }

  Future<RelatorioDetalhado> getRelatorioDetalhado(String relatorioId) async {
    final uri = Uri.parse('$_baseUrl/relatorios/$relatorioId');

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return RelatorioDetalhado.fromJson(jsonData);
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> aprovarRelatorio(String relatorioId) async {
    final uri = Uri.parse('$_baseUrl/relatorios/$relatorioId/aprovar');

    final response = await http.post(uri, headers: await _getHeaders());

    if (response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    // Notificar enfermeiro sobre aprovação do relatório
    try {
      await _notificarEnfermeiroAvaliacaoRelatorio(relatorioId, 'aprovado');
    } catch (e) {
      debugPrint('⚠️ Erro ao notificar enfermeiro sobre aprovação: $e');
      // Falha silenciosa - não deve impedir a aprovação
    }
  }

  Future<void> recusarRelatorio(String relatorioId, String motivo) async {
    final uri = Uri.parse('$_baseUrl/relatorios/$relatorioId/recusar');

    final body = json.encode({'motivo': motivo});

    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    // Notificar enfermeiro sobre recusa do relatório
    try {
      await _notificarEnfermeiroAvaliacaoRelatorio(
          relatorioId, 'recusado', motivo);
    } catch (e) {
      debugPrint('⚠️ Erro ao notificar enfermeiro sobre recusa: $e');
      // Falha silenciosa - não deve impedir a recusa
    }
  }

  Future<void> _notificarEnfermeiroAvaliacaoRelatorio(
      String relatorioId, String status,
      [String? motivo]) async {
    debugPrint('🔔 Notificando enfermeiro sobre avaliação de relatório');
    debugPrint('   Relatório ID: $relatorioId');
    debugPrint('   Status: $status');
    if (motivo != null) debugPrint('   Motivo: $motivo');

    try {
      // Buscar dados do relatório para obter paciente e enfermeiro
      final relatorioUri = Uri.parse('$_baseUrl/relatorios/$relatorioId');
      final relatorioResponse =
          await http.get(relatorioUri, headers: await _getHeaders());

      if (relatorioResponse.statusCode != 200) {
        debugPrint(
            '❌ Erro ao buscar dados do relatório: ${relatorioResponse.statusCode}');
        return;
      }

      final relatorioData = json.decode(relatorioResponse.body);
      final pacienteId = relatorioData['paciente_id'] as String?;
      final pacienteNome =
          relatorioData['paciente_nome'] as String? ?? 'Paciente';

      if (pacienteId == null) {
        debugPrint('❌ Paciente ID não encontrado no relatório');
        return;
      }

      // Buscar dados do paciente para obter enfermeiro
      final negocioId = await _authService.getNegocioId();
      final pacienteUri =
          Uri.parse('$_baseUrl/usuarios/$pacienteId?negocio_id=$negocioId');
      final pacienteResponse =
          await http.get(pacienteUri, headers: await _getHeaders());

      if (pacienteResponse.statusCode != 200) {
        debugPrint(
            '❌ Erro ao buscar dados do paciente: ${pacienteResponse.statusCode}');
        return;
      }

      final pacienteData = json.decode(pacienteResponse.body);
      final enfermeiroId = pacienteData['enfermeiro_id'] as String?;

      if (enfermeiroId == null || enfermeiroId.isEmpty) {
        debugPrint(
            '⚠️ Paciente não possui enfermeiro vinculado - pulando notificação');
        return;
      }

      debugPrint('   Enfermeiro ID: $enfermeiroId');
      debugPrint('   Paciente: $pacienteNome');

      // Criar notificação
      String titulo;
      String mensagem;

      if (status == 'aprovado') {
        titulo = 'Relatório Aprovado';
        mensagem =
            'Seu relatório do paciente $pacienteNome foi aprovado pelo médico';
      } else {
        titulo = 'Relatório Recusado';
        mensagem =
            'Seu relatório do paciente $pacienteNome foi recusado pelo médico';
        if (motivo != null && motivo.isNotEmpty) {
          mensagem += '. Motivo: $motivo';
        }
      }

      final notificacaoUri = Uri.parse('$_baseUrl/notificacoes');
      final notificacaoPayload = {
        'titulo': titulo,
        'mensagem': mensagem,
        'tipo': 'avaliacao_relatorio',
        'destinatario_id': enfermeiroId,
        'relacionado': {
          'tipo': 'relatorio',
          'id': relatorioId,
          'paciente_id': pacienteId,
          'status': status,
        },
        'negocio_id': negocioId,
      };

      debugPrint('   Enviando notificação: $notificacaoPayload');

      final notificacaoResponse = await http.post(
        notificacaoUri,
        headers: await _getHeaders(),
        body: json.encode(notificacaoPayload),
      );

      if (notificacaoResponse.statusCode == 201 ||
          notificacaoResponse.statusCode == 200) {
        debugPrint('✅ Notificação enviada com sucesso para enfermeiro');
      } else {
        debugPrint(
            '❌ Erro ao criar notificação: ${notificacaoResponse.statusCode}');
        debugPrint('   Response body: ${notificacaoResponse.body}');
      }
    } catch (e) {
      debugPrint('❌ Erro ao notificar enfermeiro sobre avaliação: $e');
      // Não fazer rethrow para não quebrar o fluxo principal
    }
  }

  Future<List<Usuario>> getMedicos() async {
    final negocioId = await _authService.getNegocioId();
    if (negocioId == null) throw Exception('Negocio ID não encontrado.');

    final uri = Uri.parse('$_baseUrl/negocios/$negocioId/usuarios?role=medico');

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      final usuarios = jsonList.map((json) => Usuario.fromJson(json)).toList();

      final medicos = usuarios.where((usuario) {
        final userRoles = usuario.roles;
        if (userRoles != null && userRoles.containsKey(negocioId)) {
          final role = userRoles[negocioId];
          return role == 'medico';
        }
        return false;
      }).toList();

      for (var medico in medicos) {
        final role = medico.roles?[negocioId] ?? 'N/A';
      }

      return medicos;
    } else if (response.statusCode == 404 || response.statusCode == 422) {
      return <Usuario>[];
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  // --- NOTIFICAÇÕES ---

  Future<List<Notificacao>> getNotificacoes({bool forceRefresh = false}) async {
    final userId = _authService.currentUser?.id ?? 'anonymous';
    final negocioId = await _authService.getNegocioId() ?? 'default';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(
        'getNotificacoes',
        userId,
        negocioId,
      );
      if (cached != null) {
        return cached.map((json) => Notificacao.fromJson(json)).toList();
      }
    }

    final uri = Uri.parse('$_baseUrl/notificacoes');
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      debugPrint('📦 [API] Recebido ${jsonList.length} notificações');

      final notificacoes =
          jsonList.map((json) => Notificacao.fromJson(json)).toList();

      await _cacheManager.set(
        'getNotificacoes',
        jsonList,
        userId,
        negocioId,
      );

      return notificacoes;
    } else {
      debugPrint('❌ [API] Erro ao buscar notificações: ${response.statusCode}');
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<int> getNotificacoesNaoLidasContagem() async {
    final uri = Uri.parse('$_baseUrl/notificacoes/nao-lidas/contagem');
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData['count'] as int? ?? 0;
    } else {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> marcarNotificacaoComoLida(String notificacaoId) async {
    final uri = Uri.parse('$_baseUrl/notificacoes/marcar-como-lida');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: json.encode({'notificacao_id': notificacaoId}),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    // Limpar cache
    clearCache('getNotificacoes');
  }

  Future<void> marcarTodasNotificacoesComoLidas() async {
    final uri = Uri.parse('$_baseUrl/notificacoes/ler-todas');
    final response = await http.post(uri, headers: await _getHeaders());

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    // Limpar cache
    clearCache('getNotificacoes');
  }

  Future<Map<String, dynamic>> agendarNotificacao({
    required String pacienteId,
    required String titulo,
    required String mensagem,
    required DateTime dataAgendamento,
  }) async {
    print('🌐 CHAMADA PARA API - agendarNotificacao');
    print('   Paciente: $pacienteId');
    print('   Título: $titulo');
    print('   Mensagem: $mensagem');
    print('   Data: $dataAgendamento');

    final negocioId = await _authService.getNegocioId();
    print('   Negócio ID: $negocioId');

    if (negocioId == null) {
      print('❌ Negócio ID não encontrado');
      throw Exception('Negócio ID não encontrado');
    }

    final uri = Uri.parse('$_baseUrl/notificacoes/agendar');
    print('   URL: $uri');

    final payload = {
      'paciente_id': pacienteId,
      'titulo': titulo,
      'mensagem': mensagem,
      'data_agendamento': dataAgendamento.toIso8601String(),
      'negocio_id': negocioId,
    };
    print('   Payload: $payload');

    final headers = {
      ...await _getHeaders(),
      'negocio-id': negocioId,
    };
    print('   Headers: $headers');

    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode(payload),
    );

    print('   Status Code: ${response.statusCode}');
    print('   Response Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ SUCESSO - Notificação agendada via API');
      return json.decode(response.body);
    } else {
      print('❌ ERRO - Falha ao agendar notificação');
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  Future<void> _agendarLembreteExame(
      String pacienteId, Map<String, dynamic> examData) async {
    try {
      print('🔔 INICIANDO AGENDAMENTO DE NOTIFICAÇÃO DE EXAME');
      print('   Paciente ID: $pacienteId');
      print('   Dados do exame: $examData');

      final dataExameStr = examData['data_exame'] as String?;
      final horarioExame = examData['horario_exame'] as String?;
      final nomeExame = examData['nome_exame'] as String? ?? 'Exame';

      print('   Data exame string: $dataExameStr');
      print('   Horário: $horarioExame');
      print('   Nome: $nomeExame');

      if (dataExameStr == null || dataExameStr.isEmpty) {
        print('❌ Data do exame vazia - abortando');
        return;
      }

      // Parse da data do exame
      final dataExame = DateTime.tryParse(dataExameStr);
      print('   Data parseada: $dataExame');
      if (dataExame == null) {
        print('❌ Erro ao parsear data - abortando');
        return;
      }

      // Calcular data/hora 24h antes
      DateTime dataNotificacao;
      if (horarioExame != null && horarioExame.isNotEmpty) {
        print('   Processando com horário específico');
        // Se tem horário específico, agendar 24h antes do horário
        final partesHorario = horarioExame.split(':');
        print('   Partes do horário: $partesHorario');
        if (partesHorario.length >= 2) {
          final hora = int.tryParse(partesHorario[0]) ?? 9;
          final minuto = int.tryParse(partesHorario[1]) ?? 0;

          final dataHoraExame = DateTime(
            dataExame.year,
            dataExame.month,
            dataExame.day,
            hora,
            minuto,
          );
          print('   Data/hora do exame: $dataHoraExame');

          dataNotificacao = dataHoraExame.subtract(const Duration(hours: 24));
          print('   Notificação agendada para: $dataNotificacao (24h antes)');
        } else {
          print('   Horário inválido, usando 9h do dia anterior');
          // Horário inválido, usar 24h antes às 9h
          dataNotificacao = dataExame.subtract(const Duration(days: 1));
          dataNotificacao = DateTime(
            dataNotificacao.year,
            dataNotificacao.month,
            dataNotificacao.day,
            9,
            0,
          );
          print('   Notificação agendada para: $dataNotificacao');
        }
      } else {
        print('   Sem horário específico, usando 9h do dia anterior');
        // Sem horário específico, agendar para 9h do dia anterior
        dataNotificacao = dataExame.subtract(const Duration(days: 1));
        dataNotificacao = DateTime(
          dataNotificacao.year,
          dataNotificacao.month,
          dataNotificacao.day,
          9,
          0,
        );
        print('   Notificação agendada para: $dataNotificacao');
      }

      // Só agendar se a data da notificação for no futuro
      final agora = DateTime.now();
      print('   Data atual: $agora');
      print('   Notificação no futuro? ${dataNotificacao.isAfter(agora)}');

      if (dataNotificacao.isAfter(agora)) {
        final horarioFormatado =
            horarioExame?.isNotEmpty == true ? ' às $horarioExame' : '';

        final mensagem =
            'Lembrete: Você tem o exame "$nomeExame" agendado para amanhã$horarioFormatado. Não se esqueça!';

        print('   Enviando para API...');
        print('   Título: Lembrete de Exame');
        print('   Mensagem: $mensagem');
        print('   Data agendamento: $dataNotificacao');

        await agendarNotificacao(
          pacienteId: pacienteId,
          titulo: 'Lembrete de Exame',
          mensagem: mensagem,
          dataAgendamento: dataNotificacao,
        );

        print('✅ NOTIFICAÇÃO AGENDADA COM SUCESSO!');
      } else {
        print('⚠️  NOTIFICAÇÃO NÃO AGENDADA - Data da notificação já passou');
      }
    } catch (e) {
      print('❌ ERRO AO AGENDAR LEMBRETE DE EXAME: $e');
      print('   Stack trace: ${StackTrace.current}');
      // Falha silenciosa para não atrapalhar a criação do exame
    }
  }

  Future<TarefaAgendada> createTarefa(
      String pacienteId, Map<String, dynamic> data) async {
    final negocioId = await _authService.getNegocioId();
    final uri = Uri.parse(
        '$_baseUrl/pacientes/$pacienteId/tarefas?negocio_id=$negocioId');

    try {
      final headers = await _getHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return TarefaAgendada.fromJson(json.decode(response.body));
      } else {
        final errorMessage = ErrorHandler.getApiErrorMessage(response);
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<TarefaAgendada>> getTarefas(String pacienteId,
      {String? status}) async {
    final negocioId = await _authService.getNegocioId();
    String url =
        '$_baseUrl/pacientes/$pacienteId/tarefas?negocio_id=$negocioId';
    if (status != null && status.isNotEmpty) {
      url += '&status=$status';
    }

    final uri = Uri.parse(url);

    try {
      final headers = await _getHeaders();

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => TarefaAgendada.fromJson(json)).toList();
      } else {
        final errorMessage = ErrorHandler.getApiErrorMessage(response);
        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> concluirTarefa(String tarefaId) async {
    final uri = Uri.parse('$_baseUrl/tarefas/$tarefaId/concluir');
    final response = await http.patch(
      uri,
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }
  }

  // ADICIONE ESTA FUNÇÃO COMPLETA DENTRO DA CLASSE ApiService
  Future<void> logoutFromBackend(String fcmToken) async {
    final url = Uri.parse('$_baseUrl/me/logout');
    try {
      // Usaremos _getHeaders() que já existe na sua classe
      final headers = await _getHeaders();
      final body = jsonEncode({'fcm_token': fcmToken});

      debugPrint('🚀 LOGOUT_DEBUG: Desvinculando token do backend...');
      debugPrint('🚀 LOGOUT_DEBUG: Endpoint: $url');
      debugPrint('🚀 LOGOUT_DEBUG: Payload: $body');

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        debugPrint(
            '✅ LOGOUT_DEBUG: Token desvinculado com sucesso no backend.');
      } else {
        debugPrint(
            '⚠️ LOGOUT_DEBUG: Falha ao desvincular token no backend. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      // Ignora erros de header (usuário já pode estar deslogado) e de rede para não travar o logout
      if (e.toString().contains('User not authenticated')) {
        debugPrint(
            '⚠️ LOGOUT_DEBUG: Usuário já deslogado do Firebase, pulando chamada de desvinculação de token.');
      } else {
        debugPrint(
            '❌ LOGOUT_DEBUG: Erro de rede ao tentar desvincular token: $e');
      }
    }
  }

  // ================== ASSOCIAÇÕES DINÂMICAS DE PERFIS ==================

  Future<void> managePatientAssociation(
    String patientId,
    String roleType,
    List<String> professionalIds,
  ) async {
    final url =
        Uri.parse('$_baseUrl/pacientes/$patientId/associations/$roleType');

    final response = await http.patch(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'professional_ids': professionalIds,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(ErrorHandler.getApiErrorMessage(response));
    }

    clearCache('getAllUsersInBusiness');
    clearCache('getPacientes');
  }
}
