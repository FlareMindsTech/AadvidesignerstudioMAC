import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user.dart';
import '../models/conversation.dart';
import '../models/course.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/course_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../widgets/profile_avatar.dart';
import 'chat_detail_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  bool _isSingleChat = true;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<User> _users = [];
  List<User> _filteredUsers = [];
  List<Course> _courses = [];
  User? _selectedUser;
  Course? _selectedCourse;
  List<String> _selectedParticipants = [];
  bool _isLoading = false;
  bool _isLoadingUsers = true;
  bool _isLoadingCourses = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadCourses();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((u) {
        final nameMatches = (u.fullName).toLowerCase().contains(query);
        final emailMatches = (u.email ?? '').toLowerCase().contains(query);
        return nameMatches || emailMatches;
      }).toList();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final users = await UserService.getAllStudents();
      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
          _errorMessage = 'Failed to load users: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoadingCourses = true;
    });

    try {
      final courses = await CourseService.getAllCourses();
      if (mounted) {
        setState(() {
          _courses = courses;
          _isLoadingCourses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCourses = false;
        });
      }
    }
  }

  Future<void> _createChat() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isSingleChat) {
      if (_selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a user'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a group title'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_selectedCourse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a course'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_selectedParticipants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one participant'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Conversation conversation;

      if (_isSingleChat) {
        conversation = await ChatService.createSingleChat(
          receiverId: _selectedUser!.id!,
        );
      } else {
        conversation = await ChatService.createGroupChat(
          title: _titleController.text.trim(),
          courseId: _selectedCourse!.id!,
          participants: _selectedParticipants,
        );
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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

  void _toggleParticipant(String userId) {
    setState(() {
      if (_selectedParticipants.contains(userId)) {
        _selectedParticipants.remove(userId);
      } else {
        _selectedParticipants.add(userId);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF5a189a),
        elevation: 0,
        title: const Text(
          'New Chat',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chat Type Toggle
                Container(
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
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildChatTypeButton(
                          'Single Chat',
                          Icons.person,
                          true,
                        ),
                      ),
                      Expanded(
                        child: _buildChatTypeButton(
                          'Group Chat',
                          Icons.group,
                          false,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_isSingleChat) ...[
                  // Single Chat: User Selection
                  _buildSectionTitle('Select User'),
                  const SizedBox(height: 12),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildUserSelection(),
                ] else ...[
                  // Group Chat: Title
                  _buildSectionTitle('Group Title'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText:
                          'Enter group title (e.g., Fullstack Batch - Dec 2025)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a group title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Group Chat: Course Selection
                  _buildSectionTitle('Select Course'),
                  const SizedBox(height: 12),
                  _buildCourseSelection(),
                  const SizedBox(height: 24),

                  // Group Chat: Participants Selection
                  _buildSectionTitle('Select Participants'),
                  const SizedBox(height: 12),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildParticipantsSelection(),
                ],

                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5a189a),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create Chat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTypeButton(String label, IconData icon, bool isSingle) {
    final isSelected = _isSingleChat == isSingle;
    return InkWell(
      onTap: () {
        setState(() {
          _isSingleChat = isSingle;
          _selectedUser = null;
          _selectedCourse = null;
          _selectedParticipants.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5a189a) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by name or email',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF5a189a)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5a189a), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildUserSelection() {
    if (_isLoadingUsers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
          ),
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No users found'),
        ),
      );
    }

    return Container(
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
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          final isSelected = _selectedUser?.id == user.id;
          return ListTile(
            leading: _buildUserAvatar(user),
            title: Text(user.fullName),
            subtitle: Text(user.email ?? ''),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Color(0xFF5a189a))
                : null,
            onTap: () {
              setState(() {
                _selectedUser = user;
              });
              
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildCourseSelection() {
    if (_isLoadingCourses) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No courses available'),
        ),
      );
    }

    return Container(
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
      child: DropdownButtonFormField<Course>(
        isExpanded: true,
        value: _selectedCourse,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          prefixIcon: const Icon(Icons.book),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        hint: const Text('Select a course'),
        items: _courses.map((course) {
          return DropdownMenuItem<Course>(
            value: course,
            child: Text(course.title),
          );
        }).toList(),
        onChanged: (course) {
          setState(() {
            _selectedCourse = course;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a course';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildParticipantsSelection() {
    if (_isLoadingUsers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
          ),
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No users found'),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
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
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          final isSelected = _selectedParticipants.contains(user.id);
          return CheckboxListTile(
            value: isSelected,
            onChanged: (value) => _toggleParticipant(user.id!),
            title: Text(user.fullName),
            subtitle: Text(user.email ?? ''),
            secondary: _buildUserAvatar(user),
            activeColor: const Color(0xFF5a189a),
          );
        },
      ),
    );
  }

  Widget _buildUserAvatar(User user) {
    return ProfileAvatar(
      photoUrl: user.photo,
      displayName: user.fullName,
      size: 40,
    );
  }

  Widget _buildInitialsAvatar(User user) {
    final initials = _getInitials(user.fullName);
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF5a189a),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
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
