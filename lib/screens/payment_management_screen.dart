import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import 'subscription_management_screen.dart';

class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  Map<String, dynamic>? _analytics;
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Rebuild when tab changes so header/search respond to active tab
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await PaymentService.getAllPayments();
      final allPayments = (result['payments'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      
      // Secondary safety filter: Remove any payments that don't have a valid course title
      final payments = allPayments.where((pay) {
        if (pay['course'] == null) return false;
        if (pay['course'] is Map) {
          final title = pay['course']['title'];
          return title != null && title.toString().toLowerCase() != 'unknown course';
        }
        return true;
      }).toList();

      final analytics = result['analytics'] as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _payments = payments;
          _filteredPayments = payments;
          _analytics = analytics;
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
          _errorMessage = 'Failed to load payments. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Payment Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w500,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'One-Time Payments'),
            Tab(text: 'Subscriptions'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Summary Stats
          if (_payments.isNotEmpty && _tabController.index == 0)
            _buildSummaryStats(),
          // Search Bar
          if (_payments.isNotEmpty && _tabController.index == 0) _buildSearchBar(),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentsTab(),
                const SubscriptionManagementScreen(),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildPaymentsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: _isLoading && _payments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.grey[600], fontSize: isSmallScreen ? 13 : 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPayments,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No payments found',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'One-time payments will appear here',
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
                      itemCount: _filteredPayments.length,
                      itemBuilder: (context, index) {
                        return _buildPaymentCard(_filteredPayments[index], isSmallScreen);
                      },
                    ),
    );
  }

  Widget _buildSummaryStats() {
    // Use ONLY analytics values from API; if missing, show 0
    double totalAmount = 0;
    int totalPayments = 0;
    int activeSubscriptions = 0;

    if (_analytics != null) {
      final analyticsTotalRevenue = _analytics!['totalRevenue'];
      final analyticsTotalPayments = _analytics!['totalPayments'];
      final analyticsActiveSubscriptions = _analytics!['activeSubscriptions'];

      if (analyticsTotalRevenue is num) {
        totalAmount = analyticsTotalRevenue.toDouble();
      }
      if (analyticsTotalPayments is num) {
        totalPayments = analyticsTotalPayments.toInt();
      }
      if (analyticsActiveSubscriptions is num) {
        activeSubscriptions = analyticsActiveSubscriptions.toInt();
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On very small screens, use two items per row; otherwise three in one row
          final maxWidth = constraints.maxWidth;
          final isVeryNarrow = maxWidth < 360;
          final itemWidth =
              isVeryNarrow ? (maxWidth - 16) / 2 : (maxWidth - 24) / 3;

          return Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                label: 'Total Revenue',
                value: '₹${totalAmount.toStringAsFixed(2)}',
                width: itemWidth,
              ),
              _buildSummaryItem(
                label: 'Total Payments',
                value: '$totalPayments',
                width: itemWidth,
              ),
              _buildSummaryItem(
                label: 'Active Subscriptions',
                value: '$activeSubscriptions',
                width: itemWidth,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
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
          hintText: 'Search by course, student, or payment ID...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _filteredPayments = _payments;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            if (value.isEmpty) {
              _filteredPayments = _payments;
            } else {
              final query = value.toLowerCase();
              _filteredPayments = _payments.where((payment) {
                final courseTitle = payment['course'] != null
                    ? (payment['course'] is Map
                        ? (payment['course']['title'] ?? '').toLowerCase()
                        : payment['course'].toString().toLowerCase())
                    : '';
                final studentName = _getStudentName(payment).toLowerCase();
                final paymentId = (payment['razorpay_payment_id'] ?? '').toLowerCase();
                final orderId = (payment['razorpay_order_id'] ?? '').toLowerCase();
                return courseTitle.contains(query) ||
                    studentName.contains(query) ||
                    paymentId.contains(query) ||
                    orderId.contains(query);
              }).toList();
            }
          });
        },
      ),
    );
  }

  String _getStudentName(Map<String, dynamic> payment) {
    if (payment['student'] == null) return 'Unknown Student';
    if (payment['student'] is! Map) return payment['student'].toString();
    final student = payment['student'] as Map;
    final firstName = student['FirstName'] ?? student['firstName'] ?? '';
    final lastName = student['LastName'] ?? student['lastName'] ?? '';
    return '$firstName $lastName'.trim();
  }

  String _getStudentEmail(Map<String, dynamic> payment) {
    if (payment['student'] == null) return '';
    if (payment['student'] is! Map) return '';
    final student = payment['student'] as Map;
    return student['email'] ?? '';
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, bool isSmallScreen) {
    final amount = payment['amount'] ?? 0;
    // Amount is already in rupees (not paise) based on API response
    final amountInRupees = amount is int ? amount.toDouble() : (amount as num).toDouble();
    final status = payment['status'] ?? 'captured'; // Default to captured if no status
    final paymentId = payment['razorpay_payment_id'] ?? payment['_id'] ?? 'N/A';
    final orderId = payment['razorpay_order_id'] ?? payment['orderId'] ?? 'N/A';
    final createdAt = payment['createdAt'] ?? payment['created_at'];
    final courseTitle = payment['course'] != null
        ? (payment['course'] is Map
            ? payment['course']['title'] ?? 'Unknown Course'
            : payment['course'].toString())
        : 'Unknown Course';
    final studentName = _getStudentName(payment);
    final studentEmail = _getStudentEmail(payment);
    final paymentMode = payment['paymentMode']?.toString().toUpperCase() ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toString().toLowerCase()) {
      case 'captured':
      case 'success':
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Paid';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'failed':
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Failed';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = status.toString();
    }

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
          onTap: () {
            // Could show details dialog
          },
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
                        Icons.payment,
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
                          Text(
                            courseTitle,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey[600]),
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
                                Icon(Icons.email, size: 12, color: Colors.grey[500]),
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
                    // Status Badge & Payment Mode
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        if (paymentMode.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              paymentMode,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Amount Section
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Amount',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${amountInRupees.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 22 : 26,
                                fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      ),
                      // Removed duplicate rupee icon as amount text already includes '₹'
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Payment Details
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
                      _buildDetailRow('Payment ID', paymentId, isSmallScreen, Icons.receipt),
                      const SizedBox(height: 12),
                      _buildDetailRow('Order ID', orderId, isSmallScreen, Icons.shopping_bag),
                      if (createdAt != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Payment Date',
                          _formatDate(createdAt),
                          isSmallScreen,
                          Icons.calendar_today,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isSmallScreen, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
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

