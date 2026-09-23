import 'package:json_annotation/json_annotation.dart';

part 'launch.g.dart';

enum LaunchStatus {
  @JsonValue('scheduled')
  scheduled,
  @JsonValue('launching')
  launching,
  @JsonValue('launched')
  launched,
  @JsonValue('cancelled')
  cancelled,
}

enum LaunchType {
  @JsonValue('product')
  product,
  @JsonValue('feature')
  feature,
  @JsonValue('service')
  service,
  @JsonValue('update')
  update,
}

@JsonSerializable()
class Launch {
  final String id;
  final String title;
  final String description;
  final DateTime launchDate;
  final LaunchStatus status;
  final LaunchType type;
  final String organizerId;
  final List<String> attendeeIds;
  final String? launchUrl;
  final String? location;
  final int maxAttendees;
  final String? imageUrl;
  final String? productName;
  final String? version;

  const Launch({
    required this.id,
    required this.title,
    required this.description,
    required this.launchDate,
    required this.status,
    required this.type,
    required this.organizerId,
    required this.attendeeIds,
    this.launchUrl,
    this.location,
    required this.maxAttendees,
    this.imageUrl,
    this.productName,
    this.version,
  });

  factory Launch.fromJson(Map<String, dynamic> json) => _$LaunchFromJson(json);

  Map<String, dynamic> toJson() => _$LaunchToJson(this);

  Launch copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? launchDate,
    LaunchStatus? status,
    LaunchType? type,
    String? organizerId,
    List<String>? attendeeIds,
    String? launchUrl,
    String? location,
    int? maxAttendees,
    String? imageUrl,
    String? productName,
    String? version,
  }) {
    return Launch(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      launchDate: launchDate ?? this.launchDate,
      status: status ?? this.status,
      type: type ?? this.type,
      organizerId: organizerId ?? this.organizerId,
      attendeeIds: attendeeIds ?? this.attendeeIds,
      launchUrl: launchUrl ?? this.launchUrl,
      location: location ?? this.location,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      imageUrl: imageUrl ?? this.imageUrl,
      productName: productName ?? this.productName,
      version: version ?? this.version,
    );
  }
}
