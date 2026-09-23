import 'package:flutter/material.dart';
import '../services/jitsi_service.dart';
import '../services/storage_service.dart';

class JitsiMeetingScreen extends StatefulWidget {
  final String roomName;
  final String meetingTitle;
  final String? meetingId;
  final String? password;

  const JitsiMeetingScreen({
    super.key,
    required this.roomName,
    required this.meetingTitle,
    this.meetingId,
    this.password,
  });

  @override
  State<JitsiMeetingScreen> createState() => _JitsiMeetingScreenState();
}

class _JitsiMeetingScreenState extends State<JitsiMeetingScreen> {
  bool _isMuted = false;
  bool _isVideoMuted = false;
  String? _displayName;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final email = await StorageService.getEmail();
    final firstName = await StorageService.getFirstName();
    final lastName = await StorageService.getLastName();
    
    // Build display name from first and last name, fallback to email
    String displayName = 'User';
    if (firstName != null && firstName.isNotEmpty) {
      displayName = firstName;
      if (lastName != null && lastName.isNotEmpty) {
        displayName = '$firstName $lastName';
      }
    } else if (email != null && email.isNotEmpty) {
      // Use email username part as fallback
      displayName = email.split('@').first;
    }
    
    setState(() {
      _email = email;
      _displayName = displayName;
    });
  }

  Future<void> _joinMeeting() async {
    try {
      await JitsiService.joinMeeting(
        context: context,
        roomName: widget.roomName,
        displayName: _displayName,
        email: _email,
        isMuted: _isMuted,
        isVideoMuted: _isVideoMuted,
        password: widget.password,
      );
    } catch (e) {
      debugPrint('Error joining meeting: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to join meeting. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Meeting'),
        backgroundColor: const Color(0xFF5a189a),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meeting Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.video_call,
                            size: 30,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Meeting',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.meetingTitle,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.meetingId != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Meeting ID: ${widget.meetingId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Settings Section
            const Text(
              'Audio & Video Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Audio Mute Toggle
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.mic),
                title: const Text('Mute Microphone'),
                subtitle: const Text('Join with microphone off'),
                value: _isMuted,
                onChanged: (value) {
                  setState(() {
                    _isMuted = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            // Video Mute Toggle
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.videocam),
                title: const Text('Turn Off Camera'),
                subtitle: const Text('Join with camera off'),
                value: _isVideoMuted,
                onChanged: (value) {
                  setState(() {
                    _isVideoMuted = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 30),

            // Join Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _joinMeeting,
                icon: const Icon(Icons.video_call),
                label: const Text(
                  'Join Meeting',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure you have a stable internet connection for the best experience.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
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
  }
}

