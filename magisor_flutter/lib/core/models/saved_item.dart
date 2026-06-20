/// A single AI interaction stored in the local history database.
///
/// Every analysis (pie-menu action or free-form "what's on my screen?" ask)
/// is written as one of these. [saved] flags items the user starred so they
/// survive a history clear and show up on the Saved screen.
class SavedItem {
  final int? id;
  final String query;
  final String summary;
  final String extractedText;
  final String providerUsed;
  final int createdAt; // epoch millis
  final bool saved;

  SavedItem({
    this.id,
    required this.query,
    required this.summary,
    required this.extractedText,
    required this.providerUsed,
    required this.createdAt,
    this.saved = false,
  });

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(createdAt);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'query': query,
        'summary': summary,
        'extracted_text': extractedText,
        'provider_used': providerUsed,
        'created_at': createdAt,
        'saved': saved ? 1 : 0,
      };

  factory SavedItem.fromMap(Map<String, dynamic> m) => SavedItem(
        id: m['id'] as int?,
        query: (m['query'] ?? '') as String,
        summary: (m['summary'] ?? '') as String,
        extractedText: (m['extracted_text'] ?? '') as String,
        providerUsed: (m['provider_used'] ?? '') as String,
        createdAt: (m['created_at'] ?? 0) as int,
        saved: ((m['saved'] ?? 0) as int) == 1,
      );
}
