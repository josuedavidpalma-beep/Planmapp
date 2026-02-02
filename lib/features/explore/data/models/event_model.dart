class Event {
  final String id;
  final String title;
  final String? endDate;
  final String? address;
  final String? contactInfo;

  Event({
    required this.id,
    required this.title,
    this.description,
    this.date,
    this.location,
    this.category,
    this.imageUrl,
    this.sourceUrl,
    this.endDate,
    this.address,
    this.contactInfo,
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
      endDate: json['end_date'] as String?,
      address: json['address'] as String?,
      contactInfo: json['contact_info'] as String?,
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
      'end_date': endDate,
      'address': address,
      'contact_info': contactInfo,
    };
  }
}
