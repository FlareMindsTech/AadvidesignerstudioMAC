// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'launch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Launch _$LaunchFromJson(Map<String, dynamic> json) => Launch(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      launchDate: DateTime.parse(json['launchDate'] as String),
      status: $enumDecode(_$LaunchStatusEnumMap, json['status']),
      type: $enumDecode(_$LaunchTypeEnumMap, json['type']),
      organizerId: json['organizerId'] as String,
      attendeeIds: (json['attendeeIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      launchUrl: json['launchUrl'] as String?,
      location: json['location'] as String?,
      maxAttendees: (json['maxAttendees'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      productName: json['productName'] as String?,
      version: json['version'] as String?,
    );

Map<String, dynamic> _$LaunchToJson(Launch instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'launchDate': instance.launchDate.toIso8601String(),
      'status': _$LaunchStatusEnumMap[instance.status]!,
      'type': _$LaunchTypeEnumMap[instance.type]!,
      'organizerId': instance.organizerId,
      'attendeeIds': instance.attendeeIds,
      'launchUrl': instance.launchUrl,
      'location': instance.location,
      'maxAttendees': instance.maxAttendees,
      'imageUrl': instance.imageUrl,
      'productName': instance.productName,
      'version': instance.version,
    };

const _$LaunchStatusEnumMap = {
  LaunchStatus.scheduled: 'scheduled',
  LaunchStatus.launching: 'launching',
  LaunchStatus.launched: 'launched',
  LaunchStatus.cancelled: 'cancelled',
};

const _$LaunchTypeEnumMap = {
  LaunchType.product: 'product',
  LaunchType.feature: 'feature',
  LaunchType.service: 'service',
  LaunchType.update: 'update',
};
