class MagisorResponse {
  final String summary;
  final List<String> actions;
  final String extractedText;
  final String providerUsed;

  MagisorResponse({
    required this.summary,
    required this.actions,
    required this.extractedText,
    required this.providerUsed,
  });

  factory MagisorResponse.fromJson(Map<String, dynamic> json, String provider) {
    return MagisorResponse(
      summary: json['summary'] ?? '',
      actions: (json['actions'] as List<dynamic>?)?.map((e) => e.toString()).take(3).toList() ?? [],
      extractedText: json['extractedText'] ?? '',
      providerUsed: provider,
    );
  }
}