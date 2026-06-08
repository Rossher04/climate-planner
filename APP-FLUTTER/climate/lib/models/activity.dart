import 'activity_statistics.dart';

enum ActivityStatus { recommended, possible, reschedule, finished }

class Activity {
  const Activity({
    this.id,
    this.locationId,
    required this.title,
    required this.location,
    required this.date,
    required this.time,
    required this.endTime,
    required this.type,
    required this.temperature,
    required this.rainProbability,
    required this.score,
    required this.status,
    required this.weatherSource,
    this.description = '',
    this.desiredConditions = const [],
    this.statistics,
  });

  final int? id;
  final int? locationId;
  final String title;
  final String location;
  final String date;
  final String time;
  final String endTime;
  final String type;
  final double temperature;
  final int rainProbability;
  final int score;
  final ActivityStatus status;
  final String weatherSource;
  final String description;
  final List<String> desiredConditions;
  final ActivityStatistics? statistics;

  Activity copyWith({
    int? id,
    int? locationId,
    String? title,
    String? location,
    String? date,
    String? time,
    String? endTime,
    String? type,
    double? temperature,
    int? rainProbability,
    int? score,
    ActivityStatus? status,
    String? weatherSource,
    String? description,
    List<String>? desiredConditions,
    ActivityStatistics? statistics,
  }) {
    return Activity(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      title: title ?? this.title,
      location: location ?? this.location,
      date: date ?? this.date,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      temperature: temperature ?? this.temperature,
      rainProbability: rainProbability ?? this.rainProbability,
      score: score ?? this.score,
      status: status ?? this.status,
      weatherSource: weatherSource ?? this.weatherSource,
      description: description ?? this.description,
      desiredConditions: desiredConditions ?? this.desiredConditions,
      statistics: statistics ?? this.statistics,
    );
  }
}
