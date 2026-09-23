class Course {
  final String? id;
  
  final String title;
  final String description;
  final String category;
  final double price;
  final double? discount; // Optional discount amount or percentage from API
  final String? createBy; // Optional - might not be in response
  final String duration;
  final String? thumbnail;
  final bool isLiveCourse;
  final bool isRecurring;
  final int? durationinDays; // Optional - might not be in response
  final List<String>? paymentOptions; // ['EMI', 'FULL'] or null for free (legacy format)
  final Map<String, dynamic>? paymentOptionsObj; // New format: {allowFullPayment, allowEMI, emiPlans}
  final bool? isSubscribed; // Whether the current user is subscribed to this course
  final Map<String, dynamic>? subscriptionDetails; // Subscription details if user has active subscription
  final List<Map<String, dynamic>>? liveMeetings; // Live meetings for this course
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Course({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.discount,
    this.createBy,
    required this.duration,
    this.thumbnail,
    required this.isLiveCourse,
    this.isRecurring = false,
    this.durationinDays,
    this.paymentOptions,
    this.paymentOptionsObj,
    this.isSubscribed,
    this.subscriptionDetails,
    this.liveMeetings,
    this.createdAt,
    this.updatedAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      price: (json['price'] is int) ? (json['price'] as int).toDouble() : (json['price'] ?? 0.0).toDouble(),
      discount: json['discount'] != null
          ? (json['discount'] is int)
              ? (json['discount'] as int).toDouble()
              : (json['discount'] as num).toDouble()
          : null,
      createBy: json['createBy'] ?? json['createdBy'], // Handle both field names
      duration: json['duration'] ?? '',
      thumbnail: json['thumbnail'],
      isLiveCourse: json['isLiveCourse'] ?? false,
      isRecurring: json['isRecurring'] ?? false,
      durationinDays: json['durationinDays'] ?? json['durationInDays'], // Handle both field names
      paymentOptions: json['paymentOptions'] != null && json['paymentOptions'] is List
          ? List<String>.from(json['paymentOptions'])
          : (json['paymentOptions'] != null && json['paymentOptions'] is String
              ? json['paymentOptions'].toString().split(',').map((e) => e.trim()).toList()
              : null),
      paymentOptionsObj: json['paymentOptions'] != null && json['paymentOptions'] is Map
          ? Map<String, dynamic>.from(json['paymentOptions'] as Map)
          : null,
      isSubscribed: json['isSubscribed'] as bool?,
      subscriptionDetails: json['subscriptionDetails'] != null && json['subscriptionDetails'] is Map
          ? Map<String, dynamic>.from(json['subscriptionDetails'] as Map)
          : null,
      liveMeetings: json['liveMeetings'] != null && json['liveMeetings'] is List
          ? (json['liveMeetings'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      if (discount != null) 'discount': discount,
      'createBy': createBy,
      'duration': duration,
      if (thumbnail != null) 'thumbnail': thumbnail,
      'isLiveCourse': isLiveCourse,
      'isRecurring': isRecurring,
      'durationinDays': durationinDays,
      if (paymentOptions != null) 'paymentOptions': paymentOptions,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  bool get isFree => price == 0;
  
  bool get hasPaymentOptions => (paymentOptions != null && paymentOptions!.isNotEmpty) || 
      (paymentOptionsObj != null && (paymentOptionsObj!['allowFullPayment'] == true || paymentOptionsObj!['allowEMI'] == true));
  
  bool get supportsEMI => paymentOptions?.contains('EMI') ?? paymentOptionsObj?['allowEMI'] == true;
  
  bool get supportsFullPayment => paymentOptions?.contains('FULL') ?? paymentOptionsObj?['allowFullPayment'] == true;

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? price,
    double? discount,
    String? createBy,
    String? duration,
    String? thumbnail,
    bool? isLiveCourse,
    bool? isRecurring,
    int? durationinDays,
    List<String>? paymentOptions,
    Map<String, dynamic>? paymentOptionsObj,
    bool? isSubscribed,
    List<Map<String, dynamic>>? liveMeetings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      createBy: createBy ?? this.createBy,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
      isLiveCourse: isLiveCourse ?? this.isLiveCourse,
      isRecurring: isRecurring ?? this.isRecurring,
      durationinDays: durationinDays ?? this.durationinDays,
      paymentOptions: paymentOptions ?? this.paymentOptions,
      paymentOptionsObj: paymentOptionsObj ?? this.paymentOptionsObj,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionDetails: subscriptionDetails ?? this.subscriptionDetails,
      liveMeetings: liveMeetings ?? this.liveMeetings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

