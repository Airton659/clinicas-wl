// lib/widgets/quick_note_dialog.dart - VERSÃO COM CORREÇÃO DE FUSO HORÁRIO

import 'package:analicegrubert/models/registro_diario.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QuickNoteDialog extends StatefulWidget {
  final String pacienteId;
  final TipoRegistro tipoRegistro;
  final Function(Map<String, dynamic>) onSubmit;
  final RegistroDiario? initialValue;

  const QuickNoteDialog({
    super.key,
    required this.pacienteId,
    required this.tipoRegistro,
    required this.onSubmit,
    this.initialValue,
  });

  @override
  State<QuickNoteDialog> createState() => _QuickNoteDialogState();
}

class _QuickNoteDialogState extends State<QuickNoteDialog> {
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _textController.text = widget.initialValue?.anotacoes ?? '';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _getTipoDisplayName(TipoRegistro tipo) {
    switch (tipo) {
      case TipoRegistro.medicacao:
        return 'Medicação';
      case TipoRegistro.atividade:
        return 'Atividade';
      case TipoRegistro.intercorrencia:
        return 'Intercorrência';
      case TipoRegistro.sinaisVitais:
        return 'Sinais Vitais';
      case TipoRegistro.anamnese:
        return 'Anamnese';
      default:
        return "Prontuário";
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'tipo': _mapTipoToBackend(widget.tipoRegistro),
      // LINHA CORRIGIDA AQUI
      'data_hora': DateTime.now().toUtc().toIso8601String(),
      'conteudo': {
        'descricao': _textController.text,
      },
    };

    try {
      await widget.onSubmit(data);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _mapTipoToBackend(TipoRegistro tipo) {
    switch (tipo) {
      case TipoRegistro.sinaisVitais:
        return 'sinais_vitais';
      case TipoRegistro.medicacao:
        return 'medicacao';
      case TipoRegistro.intercorrencia:
        return 'intercorrencia';
      case TipoRegistro.atividade:
        return 'atividade';
      case TipoRegistro.anamnese:
        return 'anamnese';
      case TipoRegistro.anotacao:
      default:
        return 'anotacao';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDateTime = DateFormat('dd/MM/yyyy \'às\' HH:mm').format(now);

    return AlertDialog(
      title: Text('Novo ${_getTipoDisplayName(widget.tipoRegistro)}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data e Hora: $formattedDateTime',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Digite suas observações aqui...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo não pode ficar vazio.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Atualizar' : 'Salvar'),
        ),
      ],
    );
  }
}