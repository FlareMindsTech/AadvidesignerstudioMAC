class Conversation {
  final String id;
  final String type; // "SINGLE" or "GROUP"
  final String? courseId;
  final String? title; // For group chats
  final String? photo; // For group/course group avatars
  final String createdBy;
  final List<Participant> participants;
  final List<dynamic> messages; // Can be empty array or message objects
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int v;
  
  bool get isGroup => type == 'GROUP' || type == 'COURSE_GROUP';

  Conversation({
    required this.id,
    required this.type,
    this.courseId,
    this.title,
    this.photo,
    required this.createdBy,
    required this.participants,
    required this.messages,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    required this.v,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['_id'] ?? '',
      type: json['type'] ?? 'SINGLE',
      courseId: json['course_id'],
      title: json['title'],
      photo: json['photo'],
      createdBy: json['created_by'] ?? '',
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => Participant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      messages: json['messages'] ?? [],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      v: json['__v'] ?? 0,
    );
  }

  // Get the other participant (for single chats)
  Participant? getOtherParticipant(String currentUserId) {
    if (participants.isEmpty) return null;
    if (participants.length == 1) return participants.first;
    
    // Find participant that is not the current user
    for (var participant in participants) {
      if (participant.userId?.id != currentUserId) {
        return participant;
      }
    }
    return participants.first;
  }

  String getDisplayName(String currentUserId) {
    if (type == 'GROUP' || type == 'COURSE_GROUP') {
      return title ?? 'Group Chat';
    }
    
    final otherParticipant = getOtherParticipant(currentUserId);
    if (otherParticipant?.userId != null) {
      final user = otherParticipant!.userId!;
      if (user.name != null && user.name!.isNotEmpty) {
        return user.name!;
      }
      // Fallback
      final roleName = user.role.isNotEmpty 
          ? user.role[0].toUpperCase() + user.role.substring(1)
          : 'User';
      return '$roleName User';
    }
    
    return 'Unknown User';
  }

  // Get display photo for the conversation
  String? getDisplayPhoto(String currentUserId) {
    if (isGroup) {
      return photo;
    }
    final otherParticipant = getOtherParticipant(currentUserId);
    return otherParticipant?.userId?.photo;
  }

  // Get last message preview
  String getLastMessagePreview() {
    if (messages.isEmpty) {
      return 'No messages yet';
    }
    
    // If messages is a list of message objects, get the last one
    try {
      final lastMessage = messages.last;
      if (lastMessage is Map<String, dynamic>) {
        return lastMessage['content'] ?? lastMessage['text'] ?? 'Message';
      }
      return 'Message';
    } catch (e) {
      return 'No messages yet';
    }
  }

  // Format date for display
  String getFormattedDate() {
    final date = lastMessageAt ?? updatedAt;
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class Participant {
  final ParticipantUser? userId;
  final String role; // "admin" or "member"
  final String id;
  final DateTime joinedAt;

  Participant({
    this.userId,
    required this.role,
    required this.id,
    required this.joinedAt,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    ParticipantUser? userId;
    
    // Handle user_id - can be object or string
    if (json['user_id'] != null) {
      if (json['user_id'] is Map<String, dynamic>) {
        // user_id is an object (from GET conversations)
        userId = ParticipantUser.fromJson(json['user_id'] as Map<String, dynamic>);
      } else if (json['user_id'] is String) {
        // user_id is a string (from CREATE group chat)
        userId = ParticipantUser(
          id: json['user_id'] as String,
          role: '', // Role not provided when user_id is string
          photo: null,
        );
      }
    }
    
    return Participant(
      userId: userId,
      role: json['role'] ?? 'member',
      id: json['_id'] ?? '',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }
}

class ParticipantUser {
  final String id;
  final String role;
  final String? photo;
  final String? name;

  ParticipantUser({
    required this.id,
    required this.role,
    this.photo,
    this.name,
  });

  factory ParticipantUser.fromJson(Map<String, dynamic> json) {
    String? parsedName = json['full_name'] ?? json['fullName'] ?? json['name'];
    if (parsedName == null || parsedName.isEmpty) {
      if (json['FirstName'] != null) {
        parsedName = '${json['FirstName']} ${json['LastName'] ?? ''}'.trim();
      }
    }
    
    return ParticipantUser(
      id: json['_id'] ?? '',
      role: json['role'] ?? '',
      photo: json['photo'],
      name: parsedName,
    );
  }
}

