// Production server origin used when no dart-define override is provided.
const _productionServerOrigin = 'http://72.61.149.88:3009';
const _productionApiBaseUrl = _productionServerOrigin;
const _productionSocketBaseUrl = _productionServerOrigin;

// Override via --dart-define:
//   flutter run ^
//     --dart-define=API_BASE_URL=http://192.168.x.x:3000 ^
//     --dart-define=SOCKET_BASE_URL=http://192.168.x.x:3000
const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _configuredSocketBaseUrl = String.fromEnvironment('SOCKET_BASE_URL');

String get defaultApiBaseUrl => apiCandidateBaseUrls.first;

String get defaultSocketBaseUrl => socketCandidateBaseUrls.first;

List<String> get apiCandidateBaseUrls => _buildCandidateBaseUrls(
  values: [
    _configuredApiBaseUrl,
    _configuredSocketBaseUrl,
    _productionApiBaseUrl,
    _productionSocketBaseUrl,
  ],
  normalizer: normalizeApiBaseUrl,
);

List<String> get socketCandidateBaseUrls => _buildCandidateBaseUrls(
  values: [
    _configuredSocketBaseUrl,
    _configuredApiBaseUrl,
    _productionSocketBaseUrl,
    _productionApiBaseUrl,
  ],
  normalizer: normalizeSocketBaseUrl,
);

List<String> _buildCandidateBaseUrls({
  required List<String?> values,
  required String Function(String? value) normalizer,
}) {
  final candidateBaseUrls = <String>[];

  for (final value in values) {
    final normalized = normalizer(value);
    if (normalized.isEmpty || candidateBaseUrls.contains(normalized)) {
      continue;
    }

    candidateBaseUrls.add(normalized);
  }

  return List.unmodifiable(candidateBaseUrls);
}

String normalizeApiBaseUrl(String? value) {
  final normalized = normalizeBaseUrl(value);
  if (normalized.isEmpty) {
    return '';
  }

  return normalized.replaceFirst(RegExp(r'/api$', caseSensitive: false), '');
}

String normalizeSocketBaseUrl(String? value) {
  final normalized = normalizeBaseUrl(value);
  if (normalized.isEmpty) {
    return '';
  }

  return normalized
      .replaceFirst(RegExp(r'/socket\.io$', caseSensitive: false), '')
      .replaceFirst(RegExp(r'/api$', caseSensitive: false), '');
}

String normalizeBaseUrl(String? value) {
  final trimmedValue = value?.trim() ?? '';
  if (trimmedValue.isEmpty) return '';
  return trimmedValue.endsWith('/')
      ? trimmedValue.substring(0, trimmedValue.length - 1)
      : trimmedValue;
}
