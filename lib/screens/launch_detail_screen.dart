import 'package:flutter/material.dart';
import '../models/launch.dart';

class LaunchDetailScreen extends StatelessWidget {
  final Launch launch;

  const LaunchDetailScreen({
    super.key,
    required this.launch,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Launch Details'),
        backgroundColor: const Color(0xFF5a189a),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigate to edit launch screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Launch Header Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFF5a189a),
                          child: Text(
                            launch.title.isNotEmpty ? launch.title[0].toUpperCase() : 'L',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                launch.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _buildStatusChip(launch.status),
                                  const SizedBox(width: 8),
                                  _buildTypeChip(launch.type),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      launch.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    if (launch.imageUrl != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          launch.imageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Launch Details
            _buildDetailSection('Launch Information', [
              _buildDetailRow('Launch Date', _formatDateTime(launch.launchDate)),
              _buildDetailRow('Launch Type', _getLaunchTypeText(launch.type)),
              if (launch.productName != null)
                _buildDetailRow('Product Name', launch.productName!),
              if (launch.version != null)
                _buildDetailRow('Version', launch.version!),
              _buildDetailRow('Location', launch.location ?? 'Online'),
              _buildDetailRow('Max Attendees', '${launch.maxAttendees}'),
            ]),
            
            const SizedBox(height: 20),
            
            // Participants
            _buildDetailSection('Participants', [
              _buildDetailRow('Total Attendees', '${launch.attendeeIds.length}'),
              _buildDetailRow('Organizer', launch.organizerId),
            ]),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Join launch
                    },
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Join Launch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5a189a),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Share launch
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(LaunchStatus status) {
    Color statusColor = _getStatusColor(status);
    String statusText = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTypeChip(LaunchType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        _getLaunchTypeText(type),
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(LaunchStatus status) {
    switch (status) {
      case LaunchStatus.scheduled:
        return Colors.orange;
      case LaunchStatus.launching:
        return Colors.green;
      case LaunchStatus.launched:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(LaunchStatus status) {
    switch (status) {
      case LaunchStatus.scheduled:
        return 'Scheduled';
      case LaunchStatus.launching:
        return 'Launching';
      case LaunchStatus.launched:
        return 'Launched';
      default:
        return 'Unknown';
    }
  }

  String _getLaunchTypeText(LaunchType type) {
    switch (type) {
      case LaunchType.product:
        return 'Product';
      case LaunchType.feature:
        return 'Feature';
      case LaunchType.service:
        return 'Service';
      case LaunchType.update:
        return 'Update';
    }
  }
}
