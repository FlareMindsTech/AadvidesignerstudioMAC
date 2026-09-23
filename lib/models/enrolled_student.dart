import 'user.dart';

class EnrolledStudent {
  final User user;
  final DateTime? subscribedAt;
  final DateTime? expiresAt;

  EnrolledStudent({
    required this.user,
    this.subscribedAt,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isLifetimeAccess {
    if (expiresAt == null) return false;
    // Consider lifetime if expires more than 100 years from now
    return expiresAt!.isAfter(DateTime.now().add(const Duration(days: 36500)));
  }

  String get subscriptionStatus {
    if (isLifetimeAccess) return 'Lifetime Access';
    if (isExpired) return 'Expired';
    return 'Active';
  }
}

