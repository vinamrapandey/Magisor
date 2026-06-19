final _urlRegex = RegExp(r'https?:\/\/[^\s)>\]]+');

/// Returns the first http(s) URL found in [text], or null if there is none.
/// Used to surface an "Open link" action when an AI answer references a URL.
String? firstUrl(String text) => _urlRegex.firstMatch(text)?.group(0);
