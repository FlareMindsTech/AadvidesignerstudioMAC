import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/meeting.dart';
import '../models/user.dart';
import '../services/jitsi_service.dart';
import '../services/meeting_service.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';
import '../providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'jitsi_meeting_screen.dart';

class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;

  const MeetingDetailScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  String? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
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

  bool get _isAdmin => _userRole?.toLowerCase() == 'admin' ||
      _userRole?.toLowerCase() == 'owner';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Meeting Details',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        foregroundColor: const Color(0xFF1A1A1A),
        actions: [
          // Hide all admin actions for completed/cancelled meetings
          if (_isAdmin && !_isLoadingRole &&
              widget.meeting.status != MeetingStatus.completed &&
              widget.meeting.status != MeetingStatus.cancelled) ...[
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.schedule, size: 20),
                ),
                onPressed: () => _showRescheduleDialog(widget.meeting),
                tooltip: 'Reschedule Meeting',
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add, size: 20),
                ),
                onPressed: () => _showAllocateStudentsDialog(widget.meeting),
                tooltip: 'Allocate Students',
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact Modern Header
                Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE8E8E8),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Status Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _getStatusColor(widget.meeting.status).withOpacity(0.08),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(widget.meeting.status)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.videocam_rounded,
                                color: _getStatusColor(widget.meeting.status),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.meeting.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            _buildCompactStatusChip(widget.meeting.status),
                          ],
                        ),
                      ),
                      // Description
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.description_outlined,
                                color: Color(0xFF757575),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.meeting.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF757575),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Meeting Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernDetailSection(
                        context,
                        'Meeting Information',
                        Icons.info_outline_rounded,
                        [
                          _buildModernDetailRow(
                            Icons.calendar_today_rounded,
                            'Start Time',
                            _formatDateTime(widget.meeting.startTime),
                            const Color(0xFF4CAF50),
                          ),
                          _buildModernDetailRow(
                            Icons.event_rounded,
                            'End Time',
                            _formatDateTime(widget.meeting.endTime),
                            const Color(0xFFFF5722),
                          ),
                          _buildModernDetailRow(
                            Icons.timer_outlined,
                            'Duration',
                            _calculateDuration(),
                            const Color(0xFF5a189a),
                          ),
                          _buildModernDetailRow(
                            Icons.tag_rounded,
                            'Meeting ID',
                            widget.meeting.meetingId ?? 'Not provided',
                            const Color(0xFF9C27B0),
                          ),
                          _buildModernDetailRow(
                            Icons.lock_outline_rounded,
                            'Password',
                            widget.meeting.password ?? 'No password',
                            const Color(0xFFFF9800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildModernDetailSection(
                        context,
                        'Participants',
                        Icons.people_outline_rounded,
                        [
                          _buildModernDetailRow(
                            Icons.group_rounded,
                            'Total',
                            '${widget.meeting.participantIds.length} ${widget.meeting.participantIds.length == 1 ? 'person' : 'people'}',
                            const Color(0xFF3F51B5),
                          ),
                          _buildModernDetailRow(
                            Icons.person_outline_rounded,
                            'Organizer',
                            widget.meeting.organizerId,
                            const Color(0xFF00BCD4),
                          ),
                          // Hide "Allocate Students" button for completed/cancelled meetings
                          if (_isAdmin && !_isLoadingRole &&
                              widget.meeting.status != MeetingStatus.completed &&
                              widget.meeting.status != MeetingStatus.cancelled)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAllocateStudentsDialog(widget.meeting),
                                  icon: const Icon(Icons.person_add, size: 18),
                                  label: const Text('Allocate Students'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5a189a),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Fixed Bottom Action Buttons - Hide completely for completed/cancelled meetings
          if (widget.meeting.status != MeetingStatus.completed &&
              widget.meeting.status != MeetingStatus.cancelled)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Join Meeting button
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4CAF50),
                                Color(0xFF45B049),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _handleJoinMeeting(widget.meeting),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.video_call_rounded, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Join Meeting',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Share button
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Share meeting
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: const Center(
                              child: Icon(
                                Icons.share_rounded,
                                color: Color(0xFF5a189a),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildCompactStatusChip(MeetingStatus status) {
    String statusText = _getStatusText(status);
    Color statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDetailSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8E8E8),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF5a189a),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildModernDetailRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF757575),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _calculateDuration() {
    final duration = widget.meeting.endTime.difference(widget.meeting.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Color _getStatusColor(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.yetToStart:
        return const Color(0xFFFF9800); // Modern Orange
      case MeetingStatus.completed:
        return const Color(0xFF4CAF50); // Modern Green
      case MeetingStatus.inProgress:
        return const Color(0xFF5a189a); // Modern Blue
      default:
        return const Color(0xFF9E9E9E); // Modern Grey
    }
  }

  String _getStatusText(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.yetToStart:
        return 'UPCOMING';
      case MeetingStatus.completed:
        return 'COMPLETED';
      case MeetingStatus.inProgress:
        return 'LIVE NOW';
      default:
        return 'UNKNOWN';
    }
  }

  Future<void> _showAllocateStudentsDialog(Meeting meeting) async {
    List<User> students = [];
    List<User> filteredStudents = [];
    List<String> selectedStudentIds = [];
    bool isLoading = true;
    bool isAllocating = false;
    final TextEditingController searchController = TextEditingController();

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Load students on dialog open
          if (isLoading) {
            UserService.getAllStudents().then((loadedStudents) {
              setDialogState(() {
                students = loadedStudents;
                filteredStudents = loadedStudents;
                isLoading = false;
              });
            }).catchError((e) {
              setDialogState(() {
                isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load students: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            });
          }

          void filterStudents(String query) {
            setDialogState(() {
              if (query.isEmpty) {
                filteredStudents = students;
              } else {
                filteredStudents = students.where((student) {
                  return student.fullName.toLowerCase().contains(query.toLowerCase()) ||
                      (student.email ?? '').toLowerCase().contains(query.toLowerCase());
                }).toList();
              }
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5a189a), Color(0xFF9C27B0)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Allocate Students',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                meeting.title,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: isAllocating
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: filterStudents,
                        decoration: InputDecoration(
                          hintText: 'Search students...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF5a189a)),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    searchController.clear();
                                    filterStudents('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Selected Count Badge
                  if (selectedStudentIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5a189a).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF5a189a).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5a189a),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${selectedStudentIds.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${selectedStudentIds.length} student${selectedStudentIds.length > 1 ? 's' : ''} selected',
                                style: const TextStyle(
                                  color: Color(0xFF5a189a),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  selectedStudentIds.clear();
                                });
                              },
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  color: Color(0xFF5a189a),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Students List
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
                              ),
                            ),
                          )
                        : filteredStudents.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        searchController.text.isNotEmpty
                                            ? 'No students found'
                                            : 'No students available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student = filteredStudents[index];
                                  final isSelected =
                                      selectedStudentIds.contains(student.id);
                                  return _buildStudentCard(
                                    student,
                                    isSelected,
                                    () {
                                      setDialogState(() {
                                        if (isSelected) {
                                          selectedStudentIds.remove(student.id!);
                                        } else {
                                          selectedStudentIds.add(student.id!);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isAllocating
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (isAllocating || selectedStudentIds.isEmpty)
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isAllocating = true;
                                    });

                                    try {
                                      final result =
                                          await MeetingService.allocateStudents(
                                        meetingId: widget.meeting.id,
                                        studentIds: selectedStudentIds,
                                      );

                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(result['message'] ??
                                                    'Students allocated successfully'),
                                                if (result['allocatedCount'] != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text(
                                                      '${result['allocatedCount']} student(s) allocated',
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isAllocating = false;
                                      });
                                      
                                      // Extract error message properly
                                      String errorMessage = 'Failed to allocate students. Please try again.';
                                      
                                      debugPrint('Caught exception type: ${e.runtimeType}');
                                      debugPrint('Caught exception: $e');
                                      
                                      if (e is MeetingServiceException) {
                                        errorMessage = e.message;
                                        debugPrint('Extracted error message from MeetingServiceException: $errorMessage');
                                      } else {
                                        final errorString = e.toString();
                                        debugPrint('Exception string: $errorString');
                                        // Try to extract message from exception string
                                        if (errorString.contains('message')) {
                                          final match = RegExp(r'message[:\s]+([^,}]+)').firstMatch(errorString);
                                          if (match != null) {
                                            errorMessage = match.group(1)!.trim();
                                          } else {
                                            errorMessage = errorString.replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
                                          }
                                        } else {
                                          errorMessage = errorString.replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
                                        }
                                        debugPrint('Final error message: $errorMessage');
                                      }
                                      
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.error_outline,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Expanded(
                                                      child: Text(
                                                        'Allocation Failed',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  errorMessage,
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            duration: const Duration(seconds: 6),
                                            margin: const EdgeInsets.all(16),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5a189a),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: isAllocating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Allocate',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentCard(User student, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF5a189a).withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF5a189a)
              : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF5a189a).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                          ? [const Color(0xFF5a189a), const Color(0xFF9C27B0)]
                          : [Colors.grey[400]!, Colors.grey[600]!],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      student.fullName.isNotEmpty
                          ? student.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Student Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF5a189a)
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.email ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkbox
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF5a189a)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF5a189a)
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRescheduleDialog(Meeting meeting) async {
    DateTime? selectedDate = meeting.startTime;
    TimeOfDay? selectedStartTime = TimeOfDay.fromDateTime(meeting.startTime);
    TimeOfDay? selectedEndTime = TimeOfDay.fromDateTime(meeting.endTime);
    bool isRescheduling = false;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String _formatTimeOfDay(TimeOfDay time) {
            final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
            final minute = time.minute.toString().padLeft(2, '0');
            final period = time.period == DayPeriod.am ? 'AM' : 'PM';
            return '$hour:$minute $period';
          }

          Future<void> _selectDate() async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF5a189a),
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setDialogState(() {
                selectedDate = picked;
              });
            }
          }

          Future<void> _selectStartTime() async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: selectedStartTime ?? TimeOfDay.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF5a189a),
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setDialogState(() {
                selectedStartTime = picked;
              });
            }
          }

          Future<void> _selectEndTime() async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: selectedEndTime ?? TimeOfDay.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF5a189a),
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setDialogState(() {
                selectedEndTime = picked;
              });
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5a189a), Color(0xFF9C27B0)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Reschedule Meeting',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: isRescheduling
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meeting Title
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.videocam, color: Color(0xFF5a189a)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  meeting.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Date Picker
                        _buildRescheduleField(
                          label: 'Date',
                          icon: Icons.calendar_today,
                          value: selectedDate != null
                              ? DateFormat('EEEE, MMM dd, yyyy').format(selectedDate!)
                              : 'Select date',
                          onTap: _selectDate,
                        ),
                        const SizedBox(height: 16),

                        // Time Pickers Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildRescheduleField(
                                label: 'Start Time',
                                icon: Icons.access_time,
                                value: selectedStartTime != null
                                    ? _formatTimeOfDay(selectedStartTime!)
                                    : 'Select time',
                                onTap: _selectStartTime,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildRescheduleField(
                                label: 'End Time',
                                icon: Icons.access_time_filled,
                                value: selectedEndTime != null
                                    ? _formatTimeOfDay(selectedEndTime!)
                                    : 'Select time',
                                onTap: _selectEndTime,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isRescheduling
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (isRescheduling ||
                                    selectedDate == null ||
                                    selectedStartTime == null ||
                                    selectedEndTime == null)
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isRescheduling = true;
                                    });

                                    try {
                                      // Format date as "yyyy-MM-dd"
                                      final formattedDate =
                                          DateFormat('yyyy-MM-dd').format(selectedDate!);
                                      final formattedStartTime =
                                          _formatTimeOfDay(selectedStartTime!);
                                      final formattedEndTime =
                                          _formatTimeOfDay(selectedEndTime!);

                                      await MeetingService.rescheduleMeeting(
                                        meetingId: meeting.id,
                                        date: formattedDate,
                                        startTime: formattedStartTime,
                                        endTime: formattedEndTime,
                                      );

                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                        
                                        // Refresh meetings list
                                        if (context.mounted) {
                                          context.read<AppProvider>().refreshMeetings();
                                        }

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(Icons.check_circle,
                                                    color: Colors.white),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Meeting rescheduled successfully!',
                                                    style: TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );

                                        // Navigate back to refresh the detail screen
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isRescheduling = false;
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.error,
                                                    color: Colors.white),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Error: ${e.toString()}',
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5a189a),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: isRescheduling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.update, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Reschedule',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRescheduleField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5a189a).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF5a189a), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value == 'Select date' || value == 'Select time'
                          ? Colors.grey[400]
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _handleJoinMeeting(Meeting meeting) async {
    // Check if user is student
    final role = await StorageService.getRole();
    final isStudent = role?.toLowerCase() == 'student' || role?.toLowerCase() == 'user';

    if (isStudent) {
      // For students, call the join API first to check if they're accepted
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
            ),
          ),
        );

        final result = await MeetingService.joinMeeting(meeting.id);

        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog

          // Extract room name from meeting URL or use meeting ID
          String roomName = meeting.meetingId ?? 
              JitsiService.generateMeetingId(
                meeting.title,
                meeting.startTime,
              );

          // If API returned a meeting URL, extract room name from it
          if (result['meetingUrl'] != null && result['meetingUrl'].toString().isNotEmpty) {
            final meetingUrl = result['meetingUrl'].toString();
            // Extract room name from Jitsi URL
            roomName = JitsiService.extractRoomNameFromUrl(meetingUrl);
          }

          // Open Jitsi meeting in-app using SDK
          _openJitsiMeeting(meeting, roomName: roomName);
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          
          // Check if error is about not being accepted
          final errorMessage = e.toString().replaceAll('MeetingServiceException: ', '');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage.contains('not accepted') || 
                      errorMessage.contains('not allocated') ||
                      errorMessage.contains('request')
                          ? 'Your request to join this meeting is pending approval. Please wait for the organizer to accept your request.'
                          : errorMessage,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      // For admin/owner, directly open Jitsi meeting (no API call needed)
      _openJitsiMeeting(meeting);
    }
  }

  void _openJitsiMeeting(Meeting meeting, {String? roomName}) {
    final finalRoomName = roomName ?? 
        meeting.meetingId ??
        JitsiService.generateMeetingId(
          meeting.title,
          meeting.startTime,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JitsiMeetingScreen(
          roomName: finalRoomName,
          meetingTitle: meeting.title,
          meetingId: meeting.meetingId,
          password: meeting.password,
        ),
      ),
    );
  }
}
