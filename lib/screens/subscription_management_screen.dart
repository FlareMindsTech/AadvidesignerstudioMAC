import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _filteredSubscriptions = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final Map<String, bool> _cancellingSubscriptions = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final subscriptions = await PaymentService.getAllSubscriptions();
      
      // Secondary safety filter: Remove any subscriptions that don't have a valid course title
      final filteredList = subscriptions.where((sub) {
        if (sub['course'] == null) return false;
        if (sub['course'] is Map) {
          final title = sub['course']['title'];
          return title != null && title.toString().toLowerCase() != 'unknown course';
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _subscriptions = filteredList;
          _filteredSubscriptions = filteredList;
          _isLoading = false;
        });
      }
    } on PaymentServiceException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load subscriptions. Please try again.';
        });
      }
    }
  }

  Future<void> _cancelSubscription(String subscriptionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Subscription',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this subscription? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _cancellingSubscriptions[subscriptionId] = true;
    });

    try {
      await PaymentService.cancelSubscription(subscriptionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Subscription cancelled successfully')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadSubscriptions();
      }
    } on PaymentServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Failed to cancel subscription. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cancellingSubscriptions[subscriptionId] = false;
        });
      }
    }
  }

  String _getStudentName(Map<String, dynamic> subscription) {
    if (subscription['student'] == null) return 'Unknown Student';
    if (subscription['student'] is! Map) {
      return subscription['student'].toString();
    }
    final student = subscription['student'] as Map;
    final firstName = student['FirstName'] ?? student['firstName'] ?? '';
    final lastName = student['LastName'] ?? student['lastName'] ?? '';
    return '$firstName $lastName'.trim();
  }

  String _getStudentEmail(Map<String, dynamic> subscription) {
    if (subscription['student'] == null) return '';
    if (subscription['student'] is! Map) return '';
    final student = subscription['student'] as Map;
    return student['email'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      child: Column(
        children: [
          // Summary Stats
          // Search Bar
          if (_subscriptions.isNotEmpty) _buildSearchBar(),
          // Subscriptions List
          Expanded(
            child: _isLoading && _subscriptions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty && _subscriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isSmallScreen ? 13 : 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadSubscriptions,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _subscriptions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.subscriptions,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No subscriptions found',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'EMI subscriptions will appear here',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            itemCount: _filteredSubscriptions.length,
                            itemBuilder: (context, index) {
                              return _buildSubscriptionCard(
                                  _filteredSubscriptions[index], isSmallScreen);
                            },
                          ),
          ),
        ],
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by course, student, or subscription ID...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _filteredSubscriptions = _subscriptions;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            if (value.isEmpty) {
              _filteredSubscriptions = _subscriptions;
            } else {
              final query = value.toLowerCase();
              _filteredSubscriptions = _subscriptions.where((subscription) {
                final courseTitle = subscription['course'] != null
                    ? (subscription['course'] is Map
                        ? (subscription['course']['title'] ?? '').toLowerCase()
                        : subscription['course'].toString().toLowerCase())
                    : '';
                final studentName = _getStudentName(subscription).toLowerCase();
                final subscriptionId =
                    (subscription['razorpay_subscription_id'] ??
                            subscription['_id'] ??
                            '')
                        .toString()
                        .toLowerCase();
                return courseTitle.contains(query) ||
                    studentName.contains(query) ||
                    subscriptionId.contains(query);
              }).toList();
            }
          });
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(
      Map<String, dynamic> subscription, bool isSmallScreen) {
    final subscriptionId = subscription['_id'] ?? 'N/A';
    final dynamic rawRazorpaySubscriptionId =
        subscription['razorpay_subscription_id'] ??
            subscription['subscriptionId'];
    final String razorpaySubscriptionId =
        rawRazorpaySubscriptionId != null &&
                rawRazorpaySubscriptionId.toString().trim().isNotEmpty
            ? rawRazorpaySubscriptionId.toString().trim()
            : '';
    final status = subscription['status'] ?? 'unknown';
    final amount = subscription['amount'] ?? 0;
    // Amount is already in rupees (not paise) based on API response
    final amountInRupees =
        amount is int ? amount.toDouble() : (amount as num).toDouble();
    final type = subscription['type'] ?? 'subscription';
    final isOneTime = type.toString().toLowerCase() == 'one-time';
    final paidCount =
        subscription['paid_count'] ?? subscription['paidCount'] ?? 0;
    final totalCount =
        subscription['total_count'] ?? subscription['totalCount'] ?? 0;
    
    // If total_count is 0, try to infer from type. 
    // One-time payments should NOT have a total count default to 3.
    final effectiveTotalCount =
        totalCount > 0 ? totalCount : (isOneTime || type == 'free' ? 1 : 3);
    final createdAt = subscription['createdAt'] ?? subscription['created_at'];
    final expiresAt = subscription['expiresAt'] ?? subscription['expires_at'];
    final courseTitle = subscription['course'] != null
        ? (subscription['course'] is Map
            ? subscription['course']['title'] ?? 'Unknown Course'
            : subscription['course'].toString())
        : 'Unknown Course';
    final studentName = _getStudentName(subscription);
    final studentEmail = _getStudentEmail(subscription);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toString().toLowerCase()) {
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Active';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'cancelled':
      case 'canceled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusIcon = Icons.access_time;
        statusText = 'Expired';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = status.toString();
    }

    final isCancelling = _cancellingSubscriptions[subscriptionId] ?? false;
    final canCancel = status.toString().toLowerCase() == 'active' ||
        status.toString().toLowerCase() == 'pending';
    final isFree = type.toString().toLowerCase() == 'free';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.subscriptions,
                        size: 24,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Course and Student Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  courseTitle,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isFree)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'FREE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person,
                                  size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  studentName,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (studentEmail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.email,
                                    size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    studentEmail,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 11 : 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Amount and Progress Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                        AppTheme.primaryColor.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFree 
                                      ? 'Type' 
                                      : (isOneTime ? 'Total Paid' : 'Amount per Installment'),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isFree
                                      ? 'Free Enrollment'
                                      : '₹${amountInRupees.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isFree && !isOneTime && effectiveTotalCount > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$paidCount / $effectiveTotalCount',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (!isFree && !isOneTime && effectiveTotalCount > 0) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: effectiveTotalCount > 0
                                ? paidCount / effectiveTotalCount
                                : 0,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Subscription Details
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (razorpaySubscriptionId.isNotEmpty)
                        _buildDetailRow(
                          'Subscription ID',
                          razorpaySubscriptionId,
                          isSmallScreen,
                          Icons.receipt_long,
                        ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Created',
                          _formatDate(createdAt),
                          isSmallScreen,
                          Icons.calendar_today,
                        ),
                      ],
                      if (expiresAt != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Expires',
                          _formatDate(expiresAt),
                          isSmallScreen,
                          Icons.event_busy,
                        ),
                      ],
                    ],
                  ),
                ),
                // Cancel Button
                if (canCancel) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isCancelling
                          ? null
                          : () => _cancelSubscription(subscriptionId),
                      icon: isCancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel, size: 18),
                      label: Text(
                        isCancelling ? 'Cancelling...' : 'Cancel Subscription',
                        style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, bool isSmallScreen, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is String) {
        final parsed = DateTime.parse(date);
        final now = DateTime.now();
        final difference = now.difference(parsed);

        if (difference.inDays == 0) {
          return 'Today, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        } else if (difference.inDays == 1) {
          return 'Yesterday, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        } else if (difference.inDays < 7) {
          final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return '${weekdays[parsed.weekday - 1]}, ${parsed.day}/${parsed.month}/${parsed.year}';
        } else {
          return '${parsed.day}/${parsed.month}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        }
      }
      return date.toString();
    } catch (e) {
      return date.toString();
    }
  }
}
