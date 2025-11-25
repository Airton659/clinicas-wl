// lib/screens/anamnese_history_page.dart

import 'package:analicegrubert/widgets/anamnese_history_list.dart';
import 'package:flutter/material.dart';

class AnamneseHistoryPage extends StatelessWidget {
  final String pacienteId;
  final String pacienteNome;

  const AnamneseHistoryPage({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ficha de Avaliação'),
            Text(
              pacienteNome,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      // O corpo da página agora é apenas o widget reutilizável
      body: AnamneseHistoryList(
        pacienteId: pacienteId,
        pacienteNome: pacienteNome,
      ),
    );
  }
}