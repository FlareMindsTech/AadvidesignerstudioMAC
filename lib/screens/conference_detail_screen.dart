import 'package:flutter/material.dart';
import '../models/conference.dart';

class ConferenceDetailScreen extends StatelessWidget {
  final Conference conference;

  const ConferenceDetailScreen({
    super.key,
    required this.conference,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conference Details'),
        backgroundColor: const Color(0xFF5a189a),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigate to edit conference screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conference Header Card
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
                            conference.title.isNotEmpty ? conference.title[0].toUpperCase() : 'C',
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
                                conference.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildStatusChip(conference.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      conference.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Conference Details
            _buildDetailSection('Conference Information', [
              _buildDetailRow('Start Date', _formatDateTime(conference.startDate)),
              _buildDetailRow('End Date', _formatDateTime(conference.endDate)),
              _buildDetailRow('Duration', _calculateDuration()),
              _buildDetailRow('Conference ID', conference.conferenceId ?? 'Not provided'),
              _buildDetailRow('Password', conference.password ?? 'No password'),
              _buildDetailRow('Location', conference.location ?? 'Online'),
              _buildDetailRow('Max Attendees', '${conference.maxAttendees}'),
            ]),
            
            const SizedBox(height: 20),
            
            // Participants
            _buildDetailSection('Participants', [
              _buildDetailRow('Total Speakers', '${conference.speakerIds.length}'),
              _buildDetailRow('Total Attendees', '${conference.attendeeIds.length}'),
              _buildDetailRow('Organizer', conference.organizerId),
            ]),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Join conference
                    },
                    icon: const Icon(Icons.groups),
                    label: const Text('Join Conference'),
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
                      // Share conference
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

  Widget _buildStatusChip(ConferenceStatus status) {
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

  String _calculateDuration() {
    final duration = conference.endDate.difference(conference.startDate);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    return '${days}d ${hours}h';
  }

  Color _getStatusColor(ConferenceStatus status) {
    switch (status) {
      case ConferenceStatus.upcoming:
        return Colors.orange;
      case ConferenceStatus.live:
        return Colors.green;
      case ConferenceStatus.ended:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(ConferenceStatus status) {
    switch (status) {
      case ConferenceStatus.upcoming:
        return 'Upcoming';
      case ConferenceStatus.live:
        return 'Live';
      case ConferenceStatus.ended:
        return 'Ended';
      default:
        return 'Unknown';
    }
  }
}
