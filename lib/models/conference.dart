import 'package:json_annotation/json_annotation.dart';

part 'conference.g.dart';

enum ConferenceStatus {
  @JsonValue('upcoming')
  upcoming,
  @JsonValue('live')
  live,
  @JsonValue('ended')
  ended,
  @JsonValue('cancelled')
  cancelled,
}

@JsonSerializable()
class Conference {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final ConferenceStatus status;
  final String organizerId;
  final List<String> speakerIds;
  final List<String> attendeeIds;
  final String? conferenceUrl;
  final String? conferenceId;
  final String? password;
  final String? location;
  final int maxAttendees;

  const Conference({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.organizerId,
    required this.speakerIds,
    required this.attendeeIds,
    this.conferenceUrl,
    this.conferenceId,
    this.password,
    this.location,
    required this.maxAttendees,
  });

  factory Conference.fromJson(Map<String, dynamic> json) => _$ConferenceFromJson(json);

  Map<String, dynamic> toJson() => _$ConferenceToJson(this);

  Conference copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    ConferenceStatus? status,
    String? organizerId,
    List<String>? speakerIds,
    List<String>? attendeeIds,
    String? conferenceUrl,
    String? conferenceId,
    String? password,
    String? location,
    int? maxAttendees,
  }) {
    return Conference(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      organizerId: organizerId ?? this.organizerId,
      speakerIds: speakerIds ?? this.speakerIds,
      attendeeIds: attendeeIds ?? this.attendeeIds,
      conferenceUrl: conferenceUrl ?? this.conferenceUrl,
      conferenceId: conferenceId ?? this.conferenceId,
      password: password ?? this.password,
      location: location ?? this.location,
      maxAttendees: maxAttendees ?? this.maxAttendees,
    );
  }
}
