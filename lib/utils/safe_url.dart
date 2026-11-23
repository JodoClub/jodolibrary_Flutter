/// URL helpers that guard against launching unsafe links.
///
/// Links such as Google Maps, website and social URLs are entered by library
/// owners and come back from the server, so they must be treated as untrusted:
/// only well-known schemes are allowed (no `intent:`, `file:`, `javascript:`,
/// `content:` or custom app schemes).
class SafeUrl {
  SafeUrl._();

  static const Set<String> _allowedSchemes = {
    'https',
    'http',
    'tel',
    'sms',
    'mailto',
    'geo',
    'whatsapp',
  };

  /// Parses [raw] and returns it only if its scheme is on the allow-list.
  static Uri? parseLaunchable(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.isEmpty) return null;
    if (!_allowedSchemes.contains(uri.scheme.toLowerCase())) return null;
    if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  /// Normalises an owner-entered web link (website, maps, social).
  /// - empty input returns '' (field is optional)
  /// - a missing scheme gets `https://` prepended
  /// - returns null when the link is not a valid http(s) URL
  static String? normalizeWebLink(String? raw) {
    var v = raw?.trim() ?? '';
    if (v.isEmpty) return '';
    if (!v.contains('://')) v = 'https://$v';
    final uri = Uri.tryParse(v);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'https' && scheme != 'http') || uri.host.isEmpty || !uri.host.contains('.')) {
      return null;
    }
    return v;
  }
}
