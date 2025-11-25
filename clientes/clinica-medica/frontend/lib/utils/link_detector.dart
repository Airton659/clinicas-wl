// lib/utils/link_detector.dart

class LinkDetector {
  static final RegExp _urlRegex = RegExp(
    r'https?://(?:[-\w.])+(?:\:[0-9]+)?(?:/(?:[\w/_.])*(?:\?(?:[\w&=%.])*)?(?:\#(?:[\w.])*)?)?',
    caseSensitive: false,
  );

  // Regex para URLs sem protocolo (ex: google.com, www.site.com.br)
  static final RegExp _urlWithoutProtocolRegex = RegExp(
    r'\b(?:www\.)?[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}(?:/(?:[\w/_.-])*(?:\?(?:[\w&=%.-])*)?(?:\#(?:[\w.-])*)?)?',
    caseSensitive: false,
  );

  static final RegExp _emailRegex = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    caseSensitive: false,
  );

  /// Detecta se o texto contém URLs (com ou sem protocolo)
  static bool containsUrl(String text) {
    return _urlRegex.hasMatch(text) || _urlWithoutProtocolRegex.hasMatch(text);
  }

  /// Detecta se o texto contém emails
  static bool containsEmail(String text) {
    return _emailRegex.hasMatch(text);
  }

  /// Detecta qualquer tipo de link
  static bool containsAnyLink(String text) {
    return containsUrl(text) || containsEmail(text);
  }

  /// Extrai todas as URLs do texto (com e sem protocolo)
  static List<String> extractUrls(String text) {
    final urlsWithProtocol = _urlRegex.allMatches(text).map((match) => match.group(0)!).toList();
    final urlsWithoutProtocol = _urlWithoutProtocolRegex.allMatches(text).map((match) => match.group(0)!).toList();

    // Remove duplicatas (caso uma URL apareça com e sem protocolo)
    final allUrls = <String>{...urlsWithProtocol, ...urlsWithoutProtocol}.toList();
    return allUrls;
  }

  /// Extrai todos os emails do texto
  static List<String> extractEmails(String text) {
    return _emailRegex.allMatches(text).map((match) => match.group(0)!).toList();
  }

  /// Verifica se o texto é APENAS um link (sem texto adicional)
  static bool isOnlyUrl(String text) {
    final trimmed = text.trim();

    // Verifica URLs com protocolo
    final urlsWithProtocol = _urlRegex.allMatches(trimmed).map((match) => match.group(0)!).toList();
    if (urlsWithProtocol.length == 1 && urlsWithProtocol.first == trimmed) {
      return true;
    }

    // Verifica URLs sem protocolo
    final urlsWithoutProtocol = _urlWithoutProtocolRegex.allMatches(trimmed).map((match) => match.group(0)!).toList();
    return urlsWithoutProtocol.length == 1 && urlsWithoutProtocol.first == trimmed;
  }

  /// Verifica se o texto é APENAS um email
  static bool isOnlyEmail(String text) {
    final trimmed = text.trim();
    final emails = extractEmails(trimmed);
    return emails.length == 1 && emails.first == trimmed;
  }

  /// Normaliza URL adicionando protocolo se necessário
  static String normalizeUrl(String url) {
    final trimmed = url.trim();

    // Se já tem protocolo, retorna como está
    if (_urlRegex.hasMatch(trimmed)) {
      return trimmed;
    }

    // Se é uma URL sem protocolo, adiciona http://
    if (_urlWithoutProtocolRegex.hasMatch(trimmed)) {
      return 'http://$trimmed';
    }

    // Se não é URL válida, retorna como está
    return trimmed;
  }

  /// Análise inteligente do conteúdo
  static ContentAnalysis analyzeContent(String text) {
    final urls = extractUrls(text);
    final emails = extractEmails(text);

    if (urls.isEmpty && emails.isEmpty) {
      return ContentAnalysis(
        type: ContentType.text,
        hasLinks: false,
        suggestion: null,
      );
    }

    if (isOnlyUrl(text)) {
      return ContentAnalysis(
        type: ContentType.link,
        hasLinks: true,
        suggestion: 'Este parece ser um link. Deseja torná-lo clicável?',
        detectedUrls: urls,
      );
    }

    if (isOnlyEmail(text)) {
      return ContentAnalysis(
        type: ContentType.link,
        hasLinks: true,
        suggestion: 'Este parece ser um email. Deseja torná-lo clicável?',
        detectedEmails: emails,
      );
    }

    return ContentAnalysis(
      type: ContentType.mixed,
      hasLinks: true,
      suggestion: 'Detectamos ${urls.length + emails.length} link(s) no texto. Deseja torná-los clicáveis?',
      detectedUrls: urls,
      detectedEmails: emails,
    );
  }
}

enum ContentType {
  text,    // Apenas texto
  link,    // Apenas link/email
  mixed,   // Texto com links
}

class ContentAnalysis {
  final ContentType type;
  final bool hasLinks;
  final String? suggestion;
  final List<String> detectedUrls;
  final List<String> detectedEmails;

  ContentAnalysis({
    required this.type,
    required this.hasLinks,
    this.suggestion,
    this.detectedUrls = const [],
    this.detectedEmails = const [],
  });
}