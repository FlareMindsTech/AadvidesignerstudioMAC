import 'package:json_annotation/json_annotation.dart';

part 'meeting.g.dart';

enum MeetingStatus {
  @JsonValue('yet_to_start')
  yetToStart,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

@JsonSerializable()
class Meeting {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final MeetingStatus status;
  final String organizerId;
  final List<String> participantIds;
  final String? meetingUrl;
  final String? meetingId;
  final String? password;

  const Meeting({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.organizerId,
    required this.participantIds,
    this.meetingUrl,
    this.meetingId,
    this.password,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) => _$MeetingFromJson(json);

  Map<String, dynamic> toJson() => _$MeetingToJson(this);

  Meeting copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    MeetingStatus? status,
    String? organizerId,
    List<String>? participantIds,
    String? meetingUrl,
    String? meetingId,
    String? password,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      organizerId: organizerId ?? this.organizerId,
      participantIds: participantIds ?? this.participantIds,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      meetingId: meetingId ?? this.meetingId,
      password: password ?? this.password,
    );
  }
}
