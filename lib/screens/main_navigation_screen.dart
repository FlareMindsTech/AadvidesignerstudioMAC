import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meeting_app/screens/users_list_screen.dart';
import 'package:meeting_app/services/storage_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'dashboard_screen.dart';
import 'course_list_screen.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';
import 'edit_profile_screen.dart';
import 'package:meeting_app/models/user.dart' as model;

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String _userRole = ''; // default role
  bool _isLoading = true; // Added loading state
  AppProvider? _appProvider; // Store provider reference

  List<Widget> _screens = [];
  List<BottomNavigationBarItem> _navItems = [];

  @override
  void initState() {
    super.initState();
    // Initialize with default screens first to prevent empty list error
    _buildScreensAndNavItems();
    _loadUserRole(); // load role from StorageService
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely get provider reference when dependencies are available
    if (_appProvider == null && mounted) {
      _appProvider = context.read<AppProvider>();
      _appProvider?.addListener(_onProviderChanged);
    }
  }

  Future<void> _loadUserRole() async {
    setState(() => _isLoading = true);
    
    // Load role and user in parallel for performance
    final results = await Future.wait([
      StorageService.getRole(),
      StorageService.getUser(),
    ]);
    
    final role = results[0] as String?;
    final user = results[1] as model.User?;
    
    if (mounted) {
      // Check if student profile is complete
      if (user != null && (role?.toLowerCase() == 'student' || role?.toLowerCase() == 'user')) {
        if (!user.isProfileComplete) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const EditProfileScreen(isInitialSetup: true),
            ),
          );
          return;
        }
      }

      setState(() {
        _userRole = role ?? 'student';
        _buildScreensAndNavItems();
        _isLoading = false;
      });
    }
  }

  void _buildScreensAndNavItems() {
    final isStudent = _userRole.toLowerCase() == 'student' ||
        _userRole.toLowerCase() == 'user';

    if (isStudent) {
      // Student navigation: Dashboard, Courses, Chats, Profile
      _screens = [
        const DashboardScreen(),
        const CourseListScreen(),
        const ChatsScreen(),
        const ProfileScreen(),
      ];

      _navItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.book),
          label: 'Courses',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chats',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ];
    } else {
      // Admin/Owner navigation: Dashboard, Courses, Users, Chats
      _screens = [
        const DashboardScreen(),
        const CourseListScreen(),
        const UsersListScreen(),
        const ChatsScreen(),
      ];

      _navItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.book),
          label: 'Courses',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Users',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chats',
        ),
      ];
    }
  }

  @override
  void dispose() {
    // Safely remove listener if provider is still available
    _appProvider?.removeListener(_onProviderChanged);
    _appProvider = null;
    super.dispose();
  }

  void _onProviderChanged() {
    // Check if widget is still mounted before accessing provider
    if (!mounted || _appProvider == null) return;

    try {
      final provider = _appProvider!;
      if (provider.selectedIndex != _currentIndex &&
          provider.selectedIndex >= 0 &&
          provider.selectedIndex < _screens.length) {
        if (mounted) {
          setState(() {
            _currentIndex = provider.selectedIndex;
          });
        }
      }
    } catch (e) {
      // Silently handle errors if widget is deactivated
      debugPrint('Provider listener error (widget deactivated): $e');
    }
  }

  void _onBottomNavTap(int index) {
    if (index >= 0 && index < _screens.length && mounted) {
      setState(() {
        _currentIndex = index;
      });
      _appProvider?.setSelectedIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: _onBottomNavTap,
          selectedItemColor: const Color(0xFF5a189a),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedIconTheme: const IconThemeData(size: 24),
          unselectedIconTheme: const IconThemeData(size: 24),
          showUnselectedLabels: true,
          items: _navItems,
        ),
      ),
    );
  }
}
