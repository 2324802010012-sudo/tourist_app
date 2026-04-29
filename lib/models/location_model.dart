class Location {
  final int id;
  final String predictedLabel;
  final String name;
  final String province;
  final String address;
  final String description;
  final String openingHours;
  final String ticketPrice;
  final List<String> highlights;
  final String videoUrl;
  final String thumbnail;
  final List<String>? gallery;
  final List<String> relatedLocations;

  Location({
    required this.id,
    required this.predictedLabel,
    required this.name,
    required this.province,
    required this.address,
    required this.description,
    required this.openingHours,
    required this.ticketPrice,
    required this.highlights,
    required this.videoUrl,
    required this.thumbnail,
    this.gallery,
    required this.relatedLocations,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'],
      predictedLabel: json['predicted_label'],
      name: json['location_name'],
      province: json['province'],
      address: json['address'],
      description: json['description'],
      openingHours: json['opening_hours'],
      ticketPrice: json['ticket_price'],
      highlights: List<String>.from(json['highlights'] ?? []),
      videoUrl: json['video_url'],
      thumbnail: "assets/${json['thumbnail_url']}",
      gallery: json['gallery'] != null
          ? List<String>.from(json['gallery'].map((e) => "assets/$e"))
          : null,
      relatedLocations: List<String>.from(json['related_locations'] ?? []),
    );
  }
}
