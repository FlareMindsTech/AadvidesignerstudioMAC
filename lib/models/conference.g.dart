// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Conference _$ConferenceFromJson(Map<String, dynamic> json) => Conference(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: $enumDecode(_$ConferenceStatusEnumMap, json['status']),
      organizerId: json['organizerId'] as String,
      speakerIds: (json['speakerIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      attendeeIds: (json['attendeeIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      conferenceUrl: json['conferenceUrl'] as String?,
      conferenceId: json['conferenceId'] as String?,
      password: json['password'] as String?,
      location: json['location'] as String?,
      maxAttendees: (json['maxAttendees'] as num).toInt(),
    );

Map<String, dynamic> _$ConferenceToJson(Conference instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'status': _$ConferenceStatusEnumMap[instance.status]!,
      'organizerId': instance.organizerId,
      'speakerIds': instance.speakerIds,
      'attendeeIds': instance.attendeeIds,
      'conferenceUrl': instance.conferenceUrl,
      'conferenceId': instance.conferenceId,
      'password': instance.password,
      'location': instance.location,
      'maxAttendees': instance.maxAttendees,
    };

const _$ConferenceStatusEnumMap = {
  ConferenceStatus.upcoming: 'upcoming',
  ConferenceStatus.live: 'live',
  ConferenceStatus.ended: 'ended',
  ConferenceStatus.cancelled: 'cancelled',
};
