import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../config/api_config.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../widgets/profile_avatar.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class GroupManagementScreen extends StatefulWidget {
  final Conversation conversation;

  const GroupManagementScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late Conversation _conversation;
  List<User> _allUsers = [];
  List<String> _participantIds = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;
  String? _currentUserId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _loadData();
  }

  Future<void> _pickImage() async {
    if (!_canManage() || _isUploadingPhoto) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Group Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                  maxWidth: 800,
                );
                if (image != null) {
                  _uploadPhoto(File(image.path));
                }
              },
            ),
            if (_conversation.photo != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _removePhoto() async {
    setState(() => _isUploadingPhoto = true);

    try {
      final updatedConv = await ChatService.updateGroupChat(
        conversationId: _conversation.id,
        photo: null, // Send null to remove
      );

      if (mounted) {
        setState(() {
          _conversation = updatedConv;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group photo removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadPhoto(File photoFile) async {
    setState(() => _isUploadingPhoto = true);

    try {
      final updatedConv = await ChatService.updateGroupChat(
        conversationId: _conversation.id,
        photo: photoFile,
      );

      if (mounted) {
        setState(() {
          _conversation = updatedConv;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group photo updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load current user info
      final user = await AuthService.getCurrentUser();
      final role = await StorageService.getRole();

      if (mounted) {
        setState(() {
          _currentUserId = user?.id;
          _currentUserRole = role?.toLowerCase();
        });
      }

      // Load all students (for adding to group)
      final users = await UserService.getAllStudents();

      // Get current participant IDs
      final participantIds = widget.conversation.participants
          .map((p) => p.userId?.id ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _allUsers = users;
          _participantIds = List.from(participantIds);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('UserServiceException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleUser(String userId, String action) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ChatService.manageGroupUser(
        conversationId: _conversation.id,
        userId: userId,
        action: action,
      );

      if (mounted) {
        setState(() {
          if (action == 'add') {
            if (!_participantIds.contains(userId)) {
              _participantIds.add(userId);
            }
          } else {
            _participantIds.remove(userId);
          }
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'add'
                  ? 'User added to group'
                  : 'User removed from group',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(e.toString().replaceAll('ChatServiceException: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _isParticipant(String userId) {
    return _participantIds.contains(userId);
  }

  bool _canManage() {
    // Only admin and owner can manage groups
    return _currentUserRole == 'admin' || _currentUserRole == 'owner';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF5a189a),
        elevation: 0,
        title: const Text(
          'Group Members',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.of(context).pop(true), // Return true to refresh
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
              ),
            )
          : _errorMessage != null
              ? Center(
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
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5a189a),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Group Info
                    Container(
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF5a189a).withValues(alpha: 0.1),
                                    width: 4,
                                  ),
                                ),
                                child: ProfileAvatar(
                                  photoUrl: _conversation.photo,
                                  displayName: _conversation.title ?? 'Group',
                                  size: 100,
                                  isGroup: true,
                                ),
                              ),
                              if (_canManage())
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF5a189a),
                                        shape: BoxShape.circle,
                                      ),
                                      child: _isUploadingPhoto
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _conversation.title ?? 'Group Chat',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_participantIds.length} Members',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Members List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _allUsers.length,
                        itemBuilder: (context, index) {
                          final user = _allUsers[index];
                          final isParticipant = _isParticipant(user.id ?? '');
                          final isCurrentUser = user.id == _currentUserId;
                          final canRemove =
                              _canManage() && isParticipant && !isCurrentUser;
                          final canAdd = _canManage() && !isParticipant;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: _buildUserAvatar(user),
                              title: Text(user.fullName),
                              subtitle: Text(user.email ?? ''),
                              trailing: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Color(0xFF5a189a),
                                        ),
                                      ),
                                    )
                                  : isParticipant
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isCurrentUser)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'You',
                                                  style:
                                                      TextStyle(fontSize: 12),
                                                ),
                                              )
                                            else if (canRemove)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    _showRemoveConfirmation(
                                                        user),
                                              ),
                                          ],
                                        )
                                      : canAdd
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.add_circle,
                                                color: Color(0xFF5a189a),
                                              ),
                                              onPressed: () => _toggleUser(
                                                user.id!,
                                                'add',
                                              ),
                                            )
                                          : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showRemoveConfirmation(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove ${user.fullName} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _toggleUser(user.id!, 'remove');
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(User user) {
    return ProfileAvatar(
      photoUrl: user.photo,
      displayName: user.fullName,
      size: 48,
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
