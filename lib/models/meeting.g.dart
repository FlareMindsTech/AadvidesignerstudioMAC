// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meeting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Meeting _$MeetingFromJson(Map<String, dynamic> json) => Meeting(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      status: $enumDecode(_$MeetingStatusEnumMap, json['status']),
      organizerId: json['organizerId'] as String,
      participantIds: (json['participantIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      meetingUrl: json['meetingUrl'] as String?,
      meetingId: json['meetingId'] as String?,
      password: json['password'] as String?,
    );

Map<String, dynamic> _$MeetingToJson(Meeting instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'status': _$MeetingStatusEnumMap[instance.status]!,
      'organizerId': instance.organizerId,
      'participantIds': instance.participantIds,
      'meetingUrl': instance.meetingUrl,
      'meetingId': instance.meetingId,
      'password': instance.password,
    };

const _$MeetingStatusEnumMap = {
  MeetingStatus.yetToStart: 'yet_to_start',
  MeetingStatus.inProgress: 'in_progress',
  MeetingStatus.completed: 'completed',
  MeetingStatus.cancelled: 'cancelled',
};
