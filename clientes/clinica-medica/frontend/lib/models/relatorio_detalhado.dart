// lib/models/relatorio_detalhado.dart

import 'package:analicegrubert/models/relatorio_medico.dart';
import 'package:analicegrubert/models/usuario.dart';
import 'package:analicegrubert/models/ficha_completa.dart';
import 'package:analicegrubert/models/registro_diario.dart';
import 'package:analicegrubert/models/exame.dart';
import 'package:analicegrubert/models/suporte_psicologico.dart';

class RelatorioDetalhado {
  final RelatorioMedico relatorio;
  final Usuario? paciente;
  final Usuario? medico;
  final FichaCompleta? fichaCompleta;
  final List<RegistroDiario> registrosDiarios;
  final List<Exame> exames;
  final List<SuportePsicologico> suportePsicologico;
  final List<String> fotos;

  const RelatorioDetalhado({
    required this.relatorio,
    this.paciente,
    this.medico,
    this.fichaCompleta,
    required this.registrosDiarios,
    required this.exames,
    required this.suportePsicologico,
    required this.fotos,
  });

  factory RelatorioDetalhado.fromJson(Map<String, dynamic> json) {
    return RelatorioDetalhado(
      relatorio: RelatorioMedico.fromJson(json['relatorio'] as Map<String, dynamic>),
      paciente: json['paciente'] != null 
          ? Usuario.fromJson(json['paciente'] as Map<String, dynamic>)
          : null,
      medico: json['medico'] != null 
          ? Usuario.fromJson(json['medico'] as Map<String, dynamic>)
          : null,
      fichaCompleta: json['ficha_completa'] != null 
          ? FichaCompleta.fromJson(json['ficha_completa'] as Map<String, dynamic>)
          : null,
      registrosDiarios: (json['registros_diarios'] as List<dynamic>? ?? [])
          .map((e) => RegistroDiario.fromJson(e as Map<String, dynamic>))
          .toList(),
      exames: (json['exames'] as List<dynamic>? ?? [])
          .map((e) => Exame.fromJson(e as Map<String, dynamic>))
          .toList(),
      suportePsicologico: (json['suporte_psicologico'] as List<dynamic>? ?? [])
          .map((e) => SuportePsicologico.fromJson(e as Map<String, dynamic>))
          .toList(),
      fotos: (json['fotos'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

}