import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:page_transition/page_transition.dart';
import 'package:meeting_app/screens/privacy_policy_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/about_us_screen.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../config/api_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/quiz_list_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/announcements_screen.dart';
import '../screens/student_notifications_screen.dart';
import '../screens/payment_management_screen.dart';
import '../screens/cms_management_screen.dart';
import '../screens/my_progress_screen.dart';
import '../screens/meeting_list_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../widgets/profile_avatar.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _userName = 'User';
  String _userInitials = 'U';
  String _organizationCode = '';
  String? _userRole;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = await AuthService.getCurrentUser();
    final role = await StorageService.getRole();
    if (mounted) {
      setState(() {
        if (user != null) {
          _userName = user.fullName;
          _userInitials = user.initials;
          _photoUrl = user.photo;
        }
        _organizationCode = 'PZPHZN'; // Default organization code
        _userRole = role?.toLowerCase();
      });
    }
  }

  bool get _isAdminOrOwner {
    return _userRole == 'admin' || _userRole == 'owner';
  }


  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Drawer(
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            children: [
              // User Profile Section with Light Background
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Profile Picture
                      ProfileAvatar(
                        photoUrl: _photoUrl,
                        displayName: _userName,
                        size: 70, // Matches radius 35 * 2
                      ),
                      const SizedBox(width: 16),
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Name
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            _buildRoleTag(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // _buildDrawerItem(
                    //   icon: Icons.download,
                    //   title: 'Offline Downloads',
                    //   hasBadge: true,
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     ScaffoldMessenger.of(context).showSnackBar(
                    //       const SnackBar(
                    //           content: Text('Offline Downloads coming soon')),
                    //     );
                    //   },
                    // ),
                    // _buildDrawerItem(
                    //   icon: Icons.folder,
                    //   title: 'Free Material',
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     ScaffoldMessenger.of(context).showSnackBar(
                    //       const SnackBar(
                    //           content: Text('Free Material coming soon')),
                    //     );
                    //   },
                    // ),
                    // _buildDrawerItem(
                    //   icon: Icons.format_quote,
                    //   title: 'Students Testimonial',
                    //   hasBadge: true,
                    //   onTap: () {
                    //     Navigator.pop(context);
                    //     ScaffoldMessenger.of(context).showSnackBar(
                    //       const SnackBar(
                    //           content:
                    //               Text('Students Testimonial coming soon')),
                    //     );
                    //   },
                    // ),
                    _buildDrawerItem(
                      icon: Icons.person,
                      title: 'Edit Profile',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            child: const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.video_call,
                      title: 'Meetings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            child: const MeetingListScreen(),
                          ),
                        );
                      },
                    ),
                    if (!_isAdminOrOwner) ...[
                      _buildDrawerItem(
                        icon: Icons.track_changes,
                        title: 'My Progress',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: const MyProgressScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: const StudentNotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    _buildDrawerItem(
                      icon: Icons.settings,
                      title: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    if (_isAdminOrOwner) ...[
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ADMIN PANEL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      _buildDrawerItem(
                        icon: Icons.quiz,
                        title: 'Quiz Management',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: const QuizListScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.analytics,
                        title: 'Reports & Analytics',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: const ReportsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.campaign,
                        title: 'Announcements',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: const AnnouncementsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.payment,
                        title: 'Payment Management',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: const PaymentManagementScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.article,
                        title: 'CMS Management',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: const CmsManagementScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                    _buildDrawerItem(
                      icon: Icons.help_outline,
                      title: 'How to use the App',
                      hasBadge: true,
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('How to use the App coming soon')),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.info_outline,
                      title: 'About Us',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutUsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.privacy_tip,
                      title: 'Privacy Policy',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.description,
                      title: 'Terms & Conditions',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TermsScreen(),
                          ),
                        );
                      },
                    ),

                  ],
                ),
              ),
              // Social Links
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Connect With Us',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSocialIcon(
                          icon: Icons.play_arrow_rounded,
                          color: Colors.red,
                          onTap: () async {
                            final uri = Uri.parse('https://youtube.com/@aadvidesignerstudio?si=mAuvVg7G98gLVkOM');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        _buildSocialIcon(
                          icon: Icons.camera_alt_rounded,
                          color: const Color(0xFFE40C5F),
                          isInstagram: true,
                          onTap: () async {
                            final uri = Uri.parse('https://www.instagram.com/aadvi_designer_studio?stkn=cmVlZ21sOGlpZDZt');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        _buildSocialIcon(
                          icon: Icons.location_on_rounded,
                          color: Colors.blue[700]!,
                          onTap: () async {
                            final uri = Uri.parse('https://maps.app.goo.gl/smQec1r6pJJPYgU76?g_st=aw');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTag() {
    if (_userRole == null) return const SizedBox.shrink();

    String label = _userRole!.toUpperCase();
    Color color = const Color(0xFF5a189a); // Primary Purple

    if (_userRole == 'owner') {
      label = 'OWNER';
      color = const Color(0xFF5a189a);
    } else if (_userRole == 'admin') {
      label = 'ADMIN';
      color = const Color(0xFF5a189a);
    } else {
      label = 'STUDENT';
      color = const Color(0xFF5a189a);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _userRole == 'owner' || _userRole == 'admin' 
                ? Icons.admin_panel_settings 
                : Icons.school,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    bool hasBadge = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5a189a).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF5a189a),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (hasBadge)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5a189a),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildSocialIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isInstagram = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: isInstagram
              ? const LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Color(0xFFFFB144),
                    Color(0xFFE40C5F),
                    Color(0xFF833AB4),
                  ],
                )
              : null,
          color: isInstagram ? null : color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isInstagram ? const Color(0xFFE40C5F) : color).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
