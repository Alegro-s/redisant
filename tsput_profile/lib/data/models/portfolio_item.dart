class PortfolioItem {
  PortfolioItem({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.date,
    required this.source,
  });

  final String id;
  final String title;
  final String category;
  final String status;
  final DateTime date;
  final String source;

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Без названия',
      category: json['category']?.toString() ?? 'Другое',
      status: json['status']?.toString() ?? 'Новый',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      source: json['source']?.toString() ?? '1C',
    );
  }
}
