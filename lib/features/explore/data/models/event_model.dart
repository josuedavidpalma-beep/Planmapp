class Event {
  final String id;
  final String title;
  final String? description;
  final String? date;
  final String? location;
  final String? category;
  final String? imageUrl;
  final String? sourceUrl;

  Event({
    required this.id,
    required this.title,
    this.description,
    this.date,
    this.location,
    this.category,
    this.imageUrl,
    this.sourceUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: json['date'] as String?,
      location: json['location'] as String?,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'location': location,
      'category': category,
      'image_url': imageUrl,
      'source_url': sourceUrl,
    };
  }
}
