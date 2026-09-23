import 'package:flutter/material.dart';

class NavigationDrawer extends StatelessWidget {
  const NavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue, Colors.blueAccent],
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aadvi Fashion Institute',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Meeting & Events Platform',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: Icons.people,
                  title: 'Organization',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to organization screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.manage_accounts,
                  title: 'User Management',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to user management screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.video_call,
                  title: 'Meeting',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to meeting screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.groups,
                  title: 'Conference',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to conference screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.event,
                  title: 'Events',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to events screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.rocket_launch,
                  title: 'Launch',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to launch screen
                  },
                ),
                const Divider(),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings screen
                  },
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
