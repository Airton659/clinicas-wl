// lib/widgets/smart_support_dialog.dart

import 'package:flutter/material.dart';
import '../utils/link_detector.dart';
import '../models/suporte_psicologico.dart';

class SmartSupportDialog extends StatefulWidget {
  final SuportePsicologico? suporte;
  final Function(String titulo, String conteudo, String tipo) onSubmit;

  const SmartSupportDialog({
    super.key,
    this.suporte,
    required this.onSubmit,
  });

  @override
  State<SmartSupportDialog> createState() => _SmartSupportDialogState();
}

class _SmartSupportDialogState extends State<SmartSupportDialog> {
  late final TextEditingController _tituloController;
  late final TextEditingController _conteudoController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  ContentAnalysis? _currentAnalysis;
  bool _isLinkType = false;
  bool _showSuggestion = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.suporte?.titulo ?? '');
    _conteudoController = TextEditingController(text: widget.suporte?.conteudo ?? '');

    // Detectar tipo inicial se estiver editando
    if (widget.suporte != null && widget.suporte!.conteudo.isNotEmpty) {
      _analyzeContent(widget.suporte!.conteudo);
    }

    // Listener para detecção em tempo real
    _conteudoController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _conteudoController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    final text = _conteudoController.text.trim();
    if (text.isNotEmpty) {
      _analyzeContent(text);
    } else {
      setState(() {
        _currentAnalysis = null;
        _showSuggestion = false;
      });
    }
  }

  void _analyzeContent(String text) {
    final analysis = LinkDetector.analyzeContent(text);

    setState(() {
      _currentAnalysis = analysis;
      _showSuggestion = analysis.hasLinks && !_isLinkType;
    });
  }

  void _acceptSuggestion() {
    setState(() {
      _isLinkType = true;
      _showSuggestion = false;
    });
  }

  void _dismissSuggestion() {
    setState(() {
      _showSuggestion = false;
    });
  }

  void _toggleContentType() {
    setState(() {
      _isLinkType = !_isLinkType;
      _showSuggestion = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.suporte != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Recurso' : 'Adicionar Recurso de Suporte'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo Título
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ex: Meditação Guiada, Artigo sobre Ansiedade',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo não pode ficar vazio.';
                  }
                  if (value.trim().length < 3) {
                    return 'O título deve ter pelo menos 3 caracteres.';
                  }
                  if (value.trim().length > 100) {
                    return 'O título deve ter no máximo 100 caracteres.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Seletor de Tipo de Conteúdo
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isLinkType ? Icons.link : Icons.text_fields,
                            size: 16,
                            color: _isLinkType ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tipo de Conteúdo',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Switch(
                            value: _isLinkType,
                            onChanged: (_) => _toggleContentType(),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Texto
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isLinkType = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isLinkType ? Colors.blue.withValues(alpha: 0.1) : null,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.text_fields,
                                      color: !_isLinkType ? Colors.blue : Colors.grey,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Texto',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: !_isLinkType ? Colors.blue : Colors.grey,
                                        fontWeight: !_isLinkType ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Link
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isLinkType = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isLinkType ? Colors.blue.withValues(alpha: 0.1) : null,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.link,
                                      color: _isLinkType ? Colors.blue : Colors.grey,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Link',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _isLinkType ? Colors.blue : Colors.grey,
                                        fontWeight: _isLinkType ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Campo Conteúdo
              TextFormField(
                controller: _conteudoController,
                decoration: InputDecoration(
                  labelText: _isLinkType ? 'URL do Recurso' : 'Texto do Recurso',
                  hintText: _isLinkType
                    ? 'google.com, www.site.com.br, http://exemplo.com'
                    : 'Texto explicativo ou instrução',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isLinkType
                    ? const Icon(Icons.link, color: Colors.blue)
                    : const Icon(Icons.text_format),
                ),
                maxLines: _isLinkType ? 1 : 3,
                keyboardType: _isLinkType ? TextInputType.url : TextInputType.multiline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo não pode ficar vazio.';
                  }
                  if (value.trim().length < 5) {
                    return 'O conteúdo deve ter pelo menos 5 caracteres.';
                  }
                  if (value.trim().length > 1000) {
                    return 'O conteúdo deve ter no máximo 1000 caracteres.';
                  }

                  // Validação específica para links
                  if (_isLinkType && !LinkDetector.containsAnyLink(value.trim())) {
                    return 'Por favor, insira uma URL válida (ex: google.com, www.site.com.br)';
                  }

                  return null;
                },
              ),

              // Sugestão Inteligente
              if (_showSuggestion && _currentAnalysis != null) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentAnalysis!.suggestion!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _dismissSuggestion,
                              child: const Text('Ignorar'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _acceptSuggestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Tornar Clicável'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Informação sobre o tipo detectado
              if (_currentAnalysis != null && _isLinkType) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Links detectados: ${_currentAnalysis!.detectedUrls.length + _currentAnalysis!.detectedEmails.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          child: Text(isEditing ? 'Atualizar' : 'Adicionar'),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final tipo = _isLinkType ? 'link' : 'texto';
      String conteudo = _conteudoController.text.trim();

      // Se é tipo link e o conteúdo não tem protocolo, adiciona https://
      if (_isLinkType && LinkDetector.containsAnyLink(conteudo)) {
        conteudo = LinkDetector.normalizeUrl(conteudo);
      }

      widget.onSubmit(
        _tituloController.text.trim(),
        conteudo,
        tipo,
      );
    }
  }
}