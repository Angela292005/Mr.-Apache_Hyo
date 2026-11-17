String displayImageUrl(String value) {
  final input = value.trim();
  final uri = Uri.tryParse(input);
  if (uri == null ||
      (uri.host != 'drive.google.com' && uri.host != 'docs.google.com')) {
    return input;
  }

  final queryId = uri.queryParameters['id'];
  final segments = uri.pathSegments;
  final fileSegment = segments.indexOf('d');
  final fileId =
      queryId ??
      (fileSegment >= 0 && fileSegment + 1 < segments.length
          ? segments[fileSegment + 1]
          : null);
  if (fileId == null || fileId.isEmpty) return input;

  return Uri.https('drive.google.com', '/uc', {
    'export': 'view',
    'id': fileId,
  }).toString();
}

String? validateImageUrl(String value) {
  if (value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return 'Ingresa un enlace de imagen válido.';
  }
  final isDrive =
      uri.host == 'drive.google.com' || uri.host == 'docs.google.com';
  if (isDrive && displayImageUrl(value) == value.trim()) {
    return 'No se pudo identificar el archivo en este enlace de Drive.';
  }
  return null;
}
