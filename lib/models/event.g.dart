// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: $enumDecode(_$EventStatusEnumMap, json['status']),
      type: $enumDecode(_$EventTypeEnumMap, json['type']),
      organizerId: json['organizerId'] as String,
      attendeeIds: (json['attendeeIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      eventUrl: json['eventUrl'] as String?,
      location: json['location'] as String?,
      maxAttendees: (json['maxAttendees'] as num).toInt(),
      price: (json['price'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'status': _$EventStatusEnumMap[instance.status]!,
      'type': _$EventTypeEnumMap[instance.type]!,
      'organizerId': instance.organizerId,
      'attendeeIds': instance.attendeeIds,
      'eventUrl': instance.eventUrl,
      'location': instance.location,
      'maxAttendees': instance.maxAttendees,
      'price': instance.price,
      'imageUrl': instance.imageUrl,
    };

const _$EventStatusEnumMap = {
  EventStatus.upcoming: 'upcoming',
  EventStatus.ongoing: 'ongoing',
  EventStatus.completed: 'completed',
  EventStatus.cancelled: 'cancelled',
};

const _$EventTypeEnumMap = {
  EventType.workshop: 'workshop',
  EventType.seminar: 'seminar',
  EventType.webinar: 'webinar',
  EventType.training: 'training',
  EventType.other: 'other',
};
