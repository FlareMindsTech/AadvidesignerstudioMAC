// import 'package:flutter/material.dart';
// import '../widgets/app_drawer.dart';
//
// class NotificationsScreen extends StatefulWidget {
//   const NotificationsScreen({super.key});
//
//   @override
//   State<NotificationsScreen> createState() => _NotificationsScreenState();
// }
//
// class _NotificationsScreenState extends State<NotificationsScreen> {
//   List<Map<String, dynamic>> _notifications = [];
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       drawer: const AppDrawer(),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Header
//             Container(
//               constraints: const BoxConstraints(minHeight: 56, maxHeight: 64),
//               color: const Color(0xFF5a189a),
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: Row(
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.arrow_back, color: Colors.white),
//                     onPressed: () => Navigator.of(context).pop(),
//                   ),
//                   const Expanded(
//                     child: Text(
//                       'Notifications',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                   const SizedBox(width: 48), // Balance the back button
//                 ],
//               ),
//             ),
//
//             // Content
//             Expanded(
//               child: _notifications.isEmpty
//                   ? _buildEmptyState()
//                   : _buildNotificationsList(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           // Bell Icon in Circle
//           Container(
//             width: 120,
//             height: 120,
//             decoration: BoxDecoration(
//               color: const Color(0xFFE3F2FD), // Light blue circle
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.notifications_outlined,
//               size: 60,
//               color: Color(0xFF5a189a), // Light blue bell icon
//             ),
//           ),
//           const SizedBox(height: 24),
//           // Main Text
//           const Text(
//             "It's a bit lonely around here!",
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 12),
//           // Subtext
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 40),
//             child: Text(
//               'The notifications you receive will appear in this section',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey[600],
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildNotificationsList() {
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _notifications.length,
//       itemBuilder: (context, index) {
//         final notification = _notifications[index];
//         return Container(
//           margin: const EdgeInsets.only(bottom: 12),
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(
//               color: Colors.grey.shade200,
//               width: 1,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withValues(alpha: 0.05),
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 width: 48,
//                 height: 48,
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF5a189a).withValues(alpha: 0.1),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(
//                   Icons.notifications,
//                   color: Color(0xFF5a189a),
//                   size: 24,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       notification['title'] ?? 'Notification',
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       notification['message'] ?? '',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       notification['time'] ?? '',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey[500],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
