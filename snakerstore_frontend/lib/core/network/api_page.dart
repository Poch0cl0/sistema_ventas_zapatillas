class ApiPage<T> {
  const ApiPage(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;
  factory ApiPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) decode,
  ) => ApiPage(
    (json['items'] as List<dynamic>)
        .map((item) => decode(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false),
    json['nextCursor'] as String?,
  );
}
