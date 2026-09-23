class Message {
  final String id;
  final String? conversationId;
  final MessageSender? sender;
  final String messageType; // "TEXT", "IMAGE", "FILE", etc.
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? v;

  Message({
    required this.id,
    this.conversationId,
    this.sender,
    required this.messageType,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.updatedAt,
    this.v,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Handle sender_id - can be object or string
    MessageSender? sender;
    if (json['sender_id'] != null) {
      if (json['sender_id'] is Map<String, dynamic>) {
        sender = MessageSender.fromJson(json['sender_id'] as Map<String, dynamic>);
      } else if (json['sender_id'] is String) {
        // Fallback if API returns string ID
        sender = MessageSender(
          id: json['sender_id'] as String,
          role: '',
          photo: null,
        );
      }
    }

    // Handle read_at - can be null or DateTime string
    bool isRead = false;
    if (json['read_at'] != null) {
      isRead = true;
    } else if (json['is_read'] != null) {
      isRead = json['is_read'] as bool;
    }

    // Handle created_at vs createdAt
    DateTime createdAt;
    if (json['created_at'] != null) {
      createdAt = DateTime.parse(json['created_at']);
    } else if (json['createdAt'] != null) {
      createdAt = DateTime.parse(json['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    // Handle updatedAt
    DateTime? updatedAt;
    if (json['updated_at'] != null) {
      updatedAt = DateTime.parse(json['updated_at']);
    } else if (json['updatedAt'] != null) {
      updatedAt = DateTime.parse(json['updatedAt']);
    }

    return Message(
      id: json['_id'] ?? '',
      conversationId: json['conversation_id'],
      sender: sender,
      messageType: json['message_type'] ?? 'TEXT',
      content: json['content'] ?? '',
      isRead: isRead,
      createdAt: createdAt,
      updatedAt: updatedAt,
      v: json['__v'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'message_type': messageType,
      'content': content,
    };
  }

  // Get sender ID
  String? get senderId => sender?.id;

  // Check if message is sent by current user
  bool isSentBy(String userId) {
    return senderId == userId;
  }

  // Format time for display
  String getFormattedTime() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
  }
}

class MessageSender {
  final String id;
  final String role;
  final String? photo;
  final String? name;

  MessageSender({
    required this.id,
    required this.role,
    this.photo,
    this.name,
  });

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    String? parsedName = json['full_name'] ?? json['fullName'] ?? json['name'];
    if (parsedName == null || parsedName.isEmpty) {
      if (json['FirstName'] != null) {
        parsedName = '${json['FirstName']} ${json['LastName'] ?? ''}'.trim();
      }
    }
    
    // Fallback to role if still empty
    if (parsedName == null || parsedName.isEmpty) {
      final roleStr = json['role'] as String? ?? '';
      if (roleStr.isNotEmpty) {
        parsedName = '${roleStr[0].toUpperCase()}${roleStr.substring(1)} User';
      } else {
        parsedName = 'User';
      }
    }

    return MessageSender(
      id: json['_id'] ?? '',
      role: json['role'] ?? '',
      photo: json['photo'],
      name: parsedName,
    );
  }
}

