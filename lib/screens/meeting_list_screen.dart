import 'package:flutter/material.dart';
import 'package:meeting_app/screens/student_notifications_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../services/storage_service.dart';
import '../services/meeting_service.dart';
import '../models/meeting.dart';
import 'create_meeting_screen.dart';
import 'meeting_detail_screen.dart';

class MeetingListScreen extends StatefulWidget {
  const MeetingListScreen({super.key});

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _userRole;
  String? _selectedFilter; // null means "All"

  @override
  void initState() {
    super.initState();
    _selectedFilter = 'All';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadMeetings();
      _loadUserRole();
    });
  }

  // Get available filters dynamically from meetings
  List<String> _getAvailableFilters(List<Meeting> meetings) {
    Set<String> statusSet = {'All'}; // Always include "All"

    for (var meeting in meetings) {
      String statusText = _getStatusTextFromEnum(meeting.status);
      statusSet.add(statusText);
    }

    // Sort filters: All first, then others
    List<String> filters = statusSet.toList();
    filters.sort((a, b) {
      if (a == 'All') return -1;
      if (b == 'All') return 1;
      return a.compareTo(b);
    });

    return filters;
  }

  Future<void> _loadUserRole() async {
    final role = await StorageService.getRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Meeting> _getFilteredMeetings(List<Meeting> meetings) {
    String searchQuery = _searchController.text.toLowerCase();

    List<Meeting> filtered = meetings.where((meeting) {
      // Search filter
      bool matchesSearch = meeting.title.toLowerCase().contains(searchQuery) ||
          (meeting.description.toLowerCase().contains(searchQuery));

      // Status filter
      bool matchesStatus = true;
      if (_selectedFilter != null && _selectedFilter != 'All') {
        String statusText = _getStatusTextFromEnum(meeting.status);
        matchesStatus = statusText == _selectedFilter;
      }

      return matchesSearch && matchesStatus;
    }).toList();

    return filtered;
  }

  Future<void> _navigateToCreateMeeting() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateMeetingScreen(),
      ),
    );

    if (result == true) {
      if (mounted) {
        context.read<AppProvider>().refreshMeetings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole?.toLowerCase() == 'admin' ||
        _userRole?.toLowerCase() == 'owner';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF5a189a),
        elevation: 0,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Meetings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StudentNotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            // Container(
            //   constraints: const BoxConstraints(minHeight: 56, maxHeight: 64),
            //   color: const Color(0xFF5a189a),
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //   child: Row(
            //     children: [
            //       Expanded(
            //         child: Text(
            //           'Meetings',
            //           style: const TextStyle(
            //             color: Colors.white,
            //             fontSize: 18,
            //             fontWeight: FontWeight.w600,
            //           ),
            //           textAlign: TextAlign.center,
            //         ),
            //       ),
            //       IconButton(
            //         icon: const Icon(Icons.notifications, color: Colors.white),
            //         onPressed: () {
            //           Navigator.push(
            //             context,
            //             MaterialPageRoute(
            //               builder: (context) =>
            //                   const StudentNotificationsScreen(),
            //             ),
            //           );
            //         },
            //       ),
            //     ],
            //   ),
            // ),

            // Search Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search meetings...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF5a189a)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
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

            // Status Filter Chips
            Consumer<AppProvider>(
              builder: (context, provider, child) {
                final availableFilters =
                    _getAvailableFilters(provider.meetings);

                return Container(
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: availableFilters.length,
                    itemBuilder: (context, index) {
                      final filter = availableFilters[index];
                      final isSelected = _selectedFilter == filter;
                      final count = filter == 'All'
                          ? provider.meetings.length
                          : provider.meetings.where((m) {
                              String statusText =
                                  _getStatusTextFromEnum(m.status);
                              return statusText == filter;
                            }).length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          selectedColor: const Color(0xFF5a189a),
                          backgroundColor: Colors.grey[200],
                          checkmarkColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF5a189a)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            // Meetings List
            Expanded(
              child: Consumer<AppProvider>(
                builder: (context, provider, child) {
                  final filteredMeetings =
                      _getFilteredMeetings(provider.meetings);

                  if (provider.isLoadingMeetings && provider.meetings.isEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return _buildSkeletonCard();
                      },
                    );
                  }

                  if (filteredMeetings.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _searchController.text.isNotEmpty ||
                                      _selectedFilter != 'All'
                                  ? Icons.search_off
                                  : Icons.videocam_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty ||
                                    _selectedFilter != 'All'
                                ? 'No meetings found'
                                : 'No meetings available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty ||
                              _selectedFilter != 'All')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _selectedFilter = 'All';
                                  });
                                },
                                child: const Text('Clear filters'),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Meetings (${filteredMeetings.length})',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (isAdmin)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5a189a),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF5a189a)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _navigateToCreateMeeting,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.add,
                                              color: Colors.white, size: 20),
                                          SizedBox(width: 6),
                                          Text(
                                            'Create',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => provider.refreshMeetings(),
                          color: const Color(0xFF5a189a),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredMeetings.length,
                            itemBuilder: (context, index) {
                              final meeting = filteredMeetings[index];
                              return _buildMeetingCard(meeting);
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLoader(
              width: 100,
              height: 100,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(height: 16, width: 120),
                  const SizedBox(height: 8),
                  const SkeletonBox(height: 14, width: 200),
                  const SizedBox(height: 8),
                  const SkeletonBox(height: 12, width: 150),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingCard(Meeting meeting) {
    String statusText = _getStatusTextFromEnum(meeting.status);
    Color statusColor = _getStatusColorFromEnum(meeting.status);
    bool isLive = statusText == 'LIVE NOW';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MeetingDetailScreen(meeting: meeting),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLive
                    ? [
                        Colors.red.shade50,
                        Colors.white,
                      ]
                    : [
                        Colors.white,
                        Colors.white,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLive ? Colors.red.shade200 : Colors.grey.shade200,
                width: isLive ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail with gradient
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF5a189a).withOpacity(0.8),
                              const Color(0xFF9C27B0).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5a189a).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                'https://picsum.photos/seed/meeting/${meeting.id}/100/100',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF5a189a)
                                              .withOpacity(0.8),
                                          const Color(0xFF9C27B0)
                                              .withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.videocam,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF5a189a)
                                              .withOpacity(0.8),
                                          const Color(0xFF9C27B0)
                                              .withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (isLive)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title and Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Badge and Delete Button Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLive
                                            ? Icons.circle
                                            : statusText == 'UPCOMING'
                                                ? Icons.schedule
                                                : Icons.check_circle,
                                        size: 12,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                if (_userRole?.toLowerCase() == 'admin' ||
                                    _userRole?.toLowerCase() == 'owner')
                                  PopupMenuButton<String>(
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _showDeleteConfirmationDialog(meeting);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Delete Meeting',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Title
                            Text(
                              meeting.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Course info if available
                            if (meeting.description.isNotEmpty &&
                                meeting.description.startsWith('Course:'))
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.book,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        meeting.description
                                            .replaceFirst('Course: ', ''),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Divider
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey[200],
                  ),
                  const SizedBox(height: 12),
                  // Date/Time Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatMeetingDateTime(
                                  meeting.startTime, meeting.endTime),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Meeting URL if available
                  if (meeting.meetingUrl != null &&
                      meeting.meetingUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final url = Uri.parse(meeting.meetingUrl!);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Could not open ${meeting.meetingUrl}'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.link,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                meeting.meetingUrl!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColorFromEnum(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.yetToStart:
        return const Color(0xFFFF9800);
      case MeetingStatus.completed:
        return const Color(0xFF4CAF50);
      case MeetingStatus.inProgress:
        return const Color(0xFF5a189a);
      case MeetingStatus.cancelled:
        return const Color(0xFF9E9E9E);
    }
  }

  String _getStatusTextFromEnum(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.yetToStart:
        return 'UPCOMING';
      case MeetingStatus.completed:
        return 'COMPLETED';
      case MeetingStatus.inProgress:
        return 'LIVE NOW';
      case MeetingStatus.cancelled:
        return 'CANCELLED';
    }
  }

  // Keep old methods for backward compatibility if needed
  Color _getStatusColor(String status) {
    // Handle both enum string representation and direct status string
    final statusLower = status.toLowerCase();
    if (statusLower.contains('yettostart') ||
        statusLower.contains('upcoming')) {
      return const Color(0xFFFF9800);
    } else if (statusLower.contains('completed') ||
        statusLower.contains('finished')) {
      return const Color(0xFF4CAF50);
    } else if (statusLower.contains('inprogress') ||
        statusLower.contains('ongoing') ||
        statusLower.contains('live')) {
      return const Color(0xFF5a189a);
    } else if (statusLower.contains('cancelled') ||
        statusLower.contains('canceled')) {
      return const Color(0xFF9E9E9E);
    }

    // Fallback for enum string format
    switch (status) {
      case 'MeetingStatus.yetToStart':
        return const Color(0xFFFF9800);
      case 'MeetingStatus.completed':
        return const Color(0xFF4CAF50);
      case 'MeetingStatus.inProgress':
        return const Color(0xFF5a189a);
      case 'MeetingStatus.cancelled':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _getStatusText(String status) {
    // Handle both enum string representation and direct status string
    final statusLower = status.toLowerCase();
    if (statusLower.contains('yettostart') ||
        statusLower.contains('upcoming')) {
      return 'UPCOMING';
    } else if (statusLower.contains('completed') ||
        statusLower.contains('finished')) {
      return 'COMPLETED';
    } else if (statusLower.contains('inprogress') ||
        statusLower.contains('ongoing') ||
        statusLower.contains('live')) {
      return 'LIVE NOW';
    } else if (statusLower.contains('cancelled') ||
        statusLower.contains('canceled')) {
      return 'CANCELLED';
    }

    // Fallback for enum string format
    switch (status) {
      case 'MeetingStatus.yetToStart':
        return 'UPCOMING';
      case 'MeetingStatus.completed':
        return 'COMPLETED';
      case 'MeetingStatus.inProgress':
        return 'LIVE NOW';
      case 'MeetingStatus.cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  String _formatMeetingDateTime(DateTime startTime, DateTime endTime) {
    final now = DateTime.now();
    final startDate = DateTime(startTime.year, startTime.month, startTime.day);
    final today = DateTime(now.year, now.month, now.day);

    String dateStr;
    if (startDate == today) {
      dateStr = 'Today';
    } else if (startDate == today.subtract(const Duration(days: 1))) {
      dateStr = 'Yesterday';
    } else if (startDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      dateStr =
          '${startTime.day} ${months[startTime.month - 1]} ${startTime.year}';
    }

    final startTimeStr = _formatTime(startTime);
    final endTimeStr = _formatTime(endTime);

    return '$dateStr\n$startTimeStr - $endTimeStr';
  }

  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? 'PM' : 'AM';

    if (hour > 12) {
      hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _showDeleteConfirmationDialog(Meeting meeting) async {
    bool isDeleting = false;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFDC3545), Color(0xFFC82333)],
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
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Delete Meeting',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: isDeleting
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.videocam, color: Colors.red[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  meeting.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Are you sure you want to delete this meeting?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This action cannot be undone.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
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
                            onPressed: isDeleting
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
                            onPressed: isDeleting
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isDeleting = true;
                                    });

                                    try {
                                      await MeetingService.deleteMeeting(
                                          meeting.id);

                                      if (context.mounted) {
                                        Navigator.of(context).pop();

                                        // Refresh meetings list
                                        context
                                            .read<AppProvider>()
                                            .refreshMeetings();

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                Icon(Icons.check_circle,
                                                    color: Colors.white),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Meeting deleted successfully!',
                                                    style:
                                                        TextStyle(fontSize: 16),
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
                                            duration:
                                                const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isDeleting = false;
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
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
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: isDeleting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
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
}
