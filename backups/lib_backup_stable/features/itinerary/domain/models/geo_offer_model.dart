class GeoOffer {
  final String id;
  final String title;
  final String description;
  final String code;
  final double discount; // 0.1 = 10%
  final double lat;
  final double lng;
  final String category; // food, drink, activity

  GeoOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.discount,
    required this.lat,
    required this.lng,
    required this.category,
  });
}
