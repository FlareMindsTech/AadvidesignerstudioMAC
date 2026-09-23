import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  @JsonKey(name: '_id')
  final String? id;
  
  @JsonKey(name: 'FirstName')
  final String? firstName;
  
  @JsonKey(name: 'LastName')
  final String? lastName;
  
  final String? email;
  final String role;
  
  final String? phoneNumber;
  final String? photo;
  final String? rawPassword;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? v;

  User({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    required this.role,
    this.phoneNumber,
    this.photo,
    this.rawPassword,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.v,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  bool get isProfileComplete => 
      firstName != null && firstName!.isNotEmpty && 
      email != null && email!.isNotEmpty;

  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    return '$first $last'.trim();
  }
  
  String get initials {
    final first = (firstName?.isNotEmpty ?? false) ? firstName![0] : '';
    final last = (lastName?.isNotEmpty ?? false) ? lastName![0] : '';
    return '$first$last'.toUpperCase();
  }
  
  String get displayName => fullName.isNotEmpty ? fullName : (email ?? '');

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? role,
    String? phoneNumber,
    String? photo,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photo: photo ?? this.photo,
      rawPassword: this.rawPassword,
      isActive: this.isActive,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      v: this.v,
    );
  }
}

@JsonSerializable()
class LoginResponse {
  final String message;
  final String token;
  final User user;

  LoginResponse({
    required this.message,
    required this.token,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => 
      _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

