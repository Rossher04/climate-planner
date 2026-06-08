class PlannerLocation {
  const PlannerLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;

  factory PlannerLocation.fromJson(Map<String, dynamic> json) {
    return PlannerLocation(
      id: json['id'] as int,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      latitude: double.parse('${json['latitude']}'),
      longitude: double.parse('${json['longitude']}'),
    );
  }
}
