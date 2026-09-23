import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

enum EventStatus {
  @JsonValue('upcoming')
  upcoming,
  @JsonValue('ongoing')
  ongoing,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

enum EventType {
  @JsonValue('workshop')
  workshop,
  @JsonValue('seminar')
  seminar,
  @JsonValue('webinar')
  webinar,
  @JsonValue('training')
  training,
  @JsonValue('other')
  other,
}

@JsonSerializable()
class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final EventStatus status;
  final EventType type;
  final String organizerId;
  final List<String> attendeeIds;
  final String? eventUrl;
  final String? location;
  final int maxAttendees;
  final double? price;
  final String? imageUrl;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.type,
    required this.organizerId,
    required this.attendeeIds,
    this.eventUrl,
    this.location,
    required this.maxAttendees,
    this.price,
    this.imageUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    EventStatus? status,
    EventType? type,
    String? organizerId,
    List<String>? attendeeIds,
    String? eventUrl,
    String? location,
    int? maxAttendees,
    double? price,
    String? imageUrl,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      type: type ?? this.type,
      organizerId: organizerId ?? this.organizerId,
      attendeeIds: attendeeIds ?? this.attendeeIds,
      eventUrl: eventUrl ?? this.eventUrl,
      location: location ?? this.location,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
