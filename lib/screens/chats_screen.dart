import 'package:flutter/material.dart';
import 'package:meeting_app/screens/student_notifications_screen.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/conversation.dart';
import '../config/api_config.dart';
import '../widgets/app_drawer.dart';
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart';
import '../widgets/profile_avatar.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _currentUserId;
  String? _userRole;
  bool _isLoadingRole = true;
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadUserRole();
    _loadConversations();
    _searchController.addListener(_filterConversations);
  }

  Future<void> _loadUserRole() async {
    final role = await StorageService.getRole();
    if (mounted) {
      setState(() {
        _userRole = role;
        _isLoadingRole = false;
      });
    }
  }

  bool get _isAdminOrOwner {
    if (_userRole == null) return false;
    final roleLower = _userRole!.toLowerCase();
    return roleLower == 'admin' || roleLower == 'owner';
  }

  Future<void> _loadUserInfo() async {
    final user = await AuthService.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _currentUserId = user.id;
      });
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final conversations = await ChatService.getAllConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _filteredConversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('ChatServiceException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations.where((conversation) {
          final displayName = conversation.getDisplayName(_currentUserId ?? '');
          return displayName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterConversations);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteConversation(String conversationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
            'Are you sure you want to delete this chat permanently? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ChatService.deleteConversation(conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadConversations(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              constraints: const BoxConstraints(minHeight: 56, maxHeight: 64),
              color: const Color(0xFF5a189a),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Aadvi Fashion Institute',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const StudentNotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or number',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Instruction Box (only show for admin/owner)
            if (_isAdminOrOwner && !_isLoadingRole)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Click on the '+' icon to create a group study chat",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Messages Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'MESSAGES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildConversationsList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (_isAdminOrOwner && !_isLoadingRole)
          ? FloatingActionButton(
              heroTag: null,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewChatScreen(),
                  ),
                ).then((_) {
                  // Refresh conversations when returning from new chat screen
                  _loadConversations();
                });
              },
              backgroundColor: const Color(0xFF5a189a),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildConversationsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadConversations,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5a189a),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No conversations yet'
                  : 'No conversations found',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: const Color(0xFF5a189a),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: _filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = _filteredConversations[index];
          return _buildConversationItem(conversation);
        },
      ),
    );
  }

  Widget _buildConversationItem(Conversation conversation) {
    final isGroupChat =
        conversation.type == 'GROUP' || conversation.type == 'COURSE_GROUP';
    final displayName = conversation.getDisplayName(_currentUserId ?? '');
    final displayPhoto = conversation.getDisplayPhoto(_currentUserId ?? '');
    final otherParticipant = !isGroupChat ? conversation.getOtherParticipant(_currentUserId ?? '') : null;
    final otherRole = otherParticipant?.userId?.role ?? '';
    final lastMessageData = _getLastMessageData(conversation);
    final formattedDate =
        _formatDate(conversation.lastMessageAt ?? conversation.updatedAt);
    final unreadCount = _getUnreadCount(conversation);
    final hasUnread = unreadCount > 0;
    final participantCount = conversation.participants.length;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(conversation: conversation),
          ),
        ).then((_) {
          // Refresh conversations when returning from chat detail
          _loadConversations();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: hasUnread
              ? Border.all(
                  color: const Color(0xFF5a189a).withValues(alpha: 0.2), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: hasUnread
                  ? const Color(0xFF5a189a).withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar Section
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (isGroupChat)
                  _buildGroupAvatar(conversation)
                else
                  _buildSingleChatAvatar(displayPhoto, displayName, hasUnread, otherRole),
                if (hasUnread && !isGroupChat)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5a189a),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Message Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildItemTrailing(conversation, hasUnread, formattedDate, unreadCount),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (lastMessageData['isSentByMe'] == true) ...[
                              Icon(
                                (lastMessageData['isRead'] == true) 
                                    ? Icons.done_all 
                                    : Icons.done,
                                size: 16,
                                color: (lastMessageData['isRead'] == true)
                                    ? const Color(0xFF5a189a)
                                    : Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                lastMessageData['preview'] ?? 'No messages yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: hasUnread
                                      ? Colors.black87
                                      : Colors.grey[700],
                                  fontWeight: hasUnread
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(Conversation conversation) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          child: _buildAvatar(conversation.photo, conversation.title ?? 'Group',
              size: 56, isGroup: true),
        ),
        Positioned(
          bottom: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF5a189a),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group, size: 8, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  '${conversation.participants.length}',
                  style: const TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleChatAvatar(
      String? photoUrl, String displayName, bool hasUnread, String role) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: hasUnread
                ? Border.all(
                    color: const Color(0xFF5a189a),
                    width: 2.5,
                  )
                : null,
          ),
          child: _buildAvatar(photoUrl, displayName, size: 56),
        ),
        if (role.isNotEmpty)
          Positioned(
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF5a189a),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (role.toLowerCase() == 'student') ...[
                    const Icon(Icons.school, size: 8, color: Colors.white),
                    const SizedBox(width: 2),
                  ] else if (role.toLowerCase() == 'owner' || role.toLowerCase() == 'admin') ...[
                    const Icon(Icons.shield, size: 8, color: Colors.white),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItemTrailing(Conversation conversation, bool hasUnread,
      String formattedDate, int unreadCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: hasUnread ? const Color(0xFF5a189a) : Colors.grey[600],
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF5a189a),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (_isAdminOrOwner)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'delete') {
                _deleteConversation(conversation.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildParticipantAvatar(String? photoUrl, String role,
      {double size = 32}) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      final sanitizedUrl = ApiConfig.getImageUrl(photoUrl);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          image: DecorationImage(
            image: NetworkImage(sanitizedUrl),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              print('[CHAT DEBUG] Participant avatar error: $exception');
            },
          ),
        ),
      );
    } else {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[350],
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: size * 0.7,
          ),
        ),
      );
    }
  }

  Map<String, dynamic> _getLastMessageData(Conversation conversation) {
    if (conversation.messages.isEmpty) {
      return {'preview': 'No messages yet', 'isSentByMe': false};
    }

    try {
      final lastMessage = conversation.messages.last;
      if (lastMessage is Map<String, dynamic>) {
        final content = lastMessage['content'] ?? '';
        final senderId = lastMessage['sender_id'] ?? '';
        final isSentByMe = senderId == (_currentUserId ?? '');

        String preview = content;
        if (isSentByMe) {
          preview = 'You: $content';
        }

        final isRead = lastMessage['read_at'] != null || lastMessage['is_read'] == true;

        return {
          'preview': preview,
          'isSentByMe': isSentByMe,
          'readAt': lastMessage['read_at'],
          'isRead': isRead,
        };
      }
    } catch (e) {
      debugPrint('Error parsing last message: $e');
    }

    return {'preview': 'Message', 'isSentByMe': false};
  }

  int _getUnreadCount(Conversation conversation) {
    if (conversation.messages.isEmpty) return 0;

    int count = 0;
    try {
      for (var message in conversation.messages) {
        if (message is Map<String, dynamic>) {
          final senderId = message['sender_id'] ?? '';
          final readAt = message['read_at'];

          // Message is unread if it's not from current user and read_at is null
          if (senderId != (_currentUserId ?? '') && readAt == null) {
            count++;
          }
        }
      }
    } catch (e) {
      debugPrint('Error counting unread messages: $e');
    }

    return count;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      // Show time if today
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '${difference}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildAvatar(String? photoUrl, String displayName,
      {double size = 56, bool isGroup = false}) {
    return ProfileAvatar(
      photoUrl: photoUrl,
      displayName: displayName,
      size: size,
      isGroup: isGroup,
    );
  }

  Widget _buildInitialsAvatar(String displayName, {double size = 56}) {
    final initials = _getInitials(displayName);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFF5a189a),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}
