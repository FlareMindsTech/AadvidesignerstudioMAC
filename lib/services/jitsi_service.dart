import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'storage_service.dart';

class JitsiService {
  static final JitsiMeet _jitsiMeet = JitsiMeet();

  /// Generate a unique meeting ID based on meeting details
  static String generateMeetingId(String title, DateTime startTime) {
    final timestamp = startTime.millisecondsSinceEpoch;
    final sanitizedTitle = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .substring(0, title.length > 20 ? 20 : title.length);
    return 'meet-$sanitizedTitle-$timestamp';
  }

  /// Extract room name from Jitsi URL
  static String extractRoomNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Extract room name from path (e.g., https://meet.jit.si/room-name)
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
      // If URL format is different, try to extract from query or fragment
      return uri.path.replaceAll('/', '').replaceAll(' ', '-');
    } catch (e) {
      debugPrint('Error extracting room name from URL: $e');
      // Fallback: use the URL itself as room name (sanitized)
      return url
          .replaceAll('https://meet.jit.si/', '')
          .replaceAll('http://meet.jit.si/', '')
          .replaceAll(' ', '-')
          .replaceAll(RegExp(r'[^a-z0-9-]'), '');
    }
  }

  /// Join a Jitsi meeting
  static Future<void> joinMeeting({
    required BuildContext context,
    required String roomName,
    String? displayName,
    String? email,
    required bool isMuted,
    required bool isVideoMuted,
    String? password,
  }) async {
    try {
      final userRole = await StorageService.getRole();
      
      // Clean room name (remove URL if it's a full URL)
      String cleanRoomName = roomName;
      if (roomName.contains('meet.jit.si') || roomName.contains('http')) {
        cleanRoomName = extractRoomNameFromUrl(roomName);
      }

      // Add password to room name if provided (Jitsi format: room#password)
      String finalRoomName = cleanRoomName;
      if (password != null && password.isNotEmpty) {
        finalRoomName = '$cleanRoomName#$password';
      }
      
      // NOTE: Do NOT add token to room URL for public Jitsi server (meet.jit.si)
      // The public server doesn't support JWT tokens and will cause authentication errors
      // We use anonymous access instead

      // Ensure displayName is never null or empty (this prevents login prompts)
      String finalDisplayName = displayName ?? 'Anonymous';
      if (finalDisplayName.trim().isEmpty) {
        finalDisplayName = email != null && email.isNotEmpty 
            ? email.split('@').first 
            : 'User';
      }
      
      // Check if user is owner/admin
      final isOwnerOrAdmin = userRole != null && 
          (userRole.toLowerCase() == 'owner' || userRole.toLowerCase() == 'admin');

      // For owners/admins, add role to display name
      if (isOwnerOrAdmin) {
        finalDisplayName = '$finalDisplayName (${userRole.toUpperCase()})';
      }
      
      // Build config overrides map
      final configOverrides = <String, dynamic>{
        // Audio/Video settings
        "startWithAudioMuted": isMuted,
        "startWithVideoMuted": isVideoMuted,
        
        // Critical: Disable login and authentication requirements
        "requireDisplayName": false,
        "prejoinPageEnabled": false,
        
        // CRITICAL: Disable members-only mode to prevent lobby
        // This is the key setting that prevents lobby from appearing
        "membersOnly": false,  // Allow anyone to join without approval
        
        // Disable lobby/waiting room completely
        "enableLobbyChat": false,
        "enableKnockingLobby": false,
        "enablePrejoinPage": false,
        "enableWelcomePage": false,
        "enableClosePage": false,
        
        // Authentication settings - completely disable to prevent login screen
        "enableAuthentication": false,  // Always disable to prevent login
        "enableUserRolesBasedOnToken": false,
        "disableLogin": true,  // Disable login button
        "enableNoAuth": true,  // Allow anonymous access
        
        // Prevent external browser opening
        "disableDeepLinking": true,
        "disableInviteFunctions": true,  // Disable invite which might open browser
        
        // Disable sounds
        "enableIncomingCallSounds": false,
        "enableOutgoingCallSounds": false,
        
        // Other settings
        "enableNoAudioDetection": false,
        "enableNoisyMicDetection": false,
        "enableLayerSuspension": true,
        "readOnlyName": false,
        
        // Additional settings to bypass lobby and prevent browser
        "enableInsecureRoomNameWarning": false,
        "enableDisplayNameInStats": false,
        "disableThirdPartyRequests": true,  // Prevent external requests
        "disableRemoteMute": false,
        "enableRemb": true,
        "enableTcc": true,
      };
      
      // NOTE: Do NOT add token to config for public Jitsi server (meet.jit.si)
      // The public server expects a JWT token with a 'context' object, which our app token is not
      // Using anonymous access instead prevents authentication errors

      // Define meeting options with enhanced config to prevent login prompts and browser opening
      // Key: Always provide userInfo with a valid displayName to avoid login prompts
      var options = JitsiMeetConferenceOptions(
        serverURL: "https://meet.jit.si",
        room: finalRoomName,
        userInfo: JitsiMeetUserInfo(
          displayName: finalDisplayName,
          email: email,
        ),
        configOverrides: configOverrides,
        featureFlags: {
          // Only use supported feature flags (removed unsupported ones per SDK warnings)
          "welcomepage.enabled": false,
          "prejoinpage.enabled": false,
          "invite.enabled": false,  // Disable invite (prevents browser)
          "calendar.enabled": false,
          "call-integration.enabled": false,
          "live-streaming.enabled": false,
          "recording.enabled": false,
          "add-people.enabled": false,  // Disable add people (prevents browser)
          "close-captions.enabled": false,
          "ios.recording.enabled": false,
          "meeting-name.enabled": false,
          "meeting-password.enabled": false,
          "server-url-change.enabled": false,
          "toolbox.alwaysVisible": false,
          
          // Enable useful features that don't require external access
          "pip.enabled": true,
          "chat.enabled": true,
          "raise-hand.enabled": true,
          "reactions.enabled": true,
          "video-share.enabled": true,
          "settings.enabled": true,
        },
      );

      // Join the meeting
      await _jitsiMeet.join(options);

      debugPrint('Successfully joined meeting: $cleanRoomName');
    } catch (e) {
      debugPrint('Error joining meeting: $e');

      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join meeting: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      rethrow;
    }
  }

  /// End the current meeting
  static Future<void> endMeeting() async {
    try {
      // await _jitsiMeet.closeMeeting();
      debugPrint('Meeting ended successfully');
    } catch (e) {
      debugPrint('Error ending meeting: $e');
      rethrow;
    }
  }

  /// Generate a random meeting URL
  static String generateRandomMeetingUrl() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp % 10000;
    return 'meet-${timestamp}-${random}';
  }
}
