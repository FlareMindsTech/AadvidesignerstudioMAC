import 'package:flutter/material.dart';
import '../services/quiz_service.dart';

class QuizResultScreen extends StatefulWidget {
  final String quizId;

  const QuizResultScreen({
    super.key,
    required this.quizId,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadResult();
  }

  Future<void> _loadResult() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await QuizService.getQuizResult(widget.quizId);
      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } on QuizServiceException catch (e) {
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
          _errorMessage = 'Failed to load quiz result. Please try again.';
        });
      }
    }
  }

  double get _scorePercentage {
    if (_result == null) return 0.0;
    final score = _result!['score'] ?? 0;
    final totalMarks = _result!['totalMarks'] ?? 1;
    return (score / totalMarks) * 100;
  }

  Color get _scoreColor {
    final percentage = _scorePercentage;
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  String get _scoreGrade {
    final percentage = _scorePercentage;
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Quiz Result',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5a189a),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _result == null
                  ? _buildEmptyView()
                  : _buildResultContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadResult,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5a189a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Text('No result available'),
    );
  }

  Widget _buildResultContent() {
    final score = _result!['score'] ?? 0;
    final totalMarks = _result!['totalMarks'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Score Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _scoreColor,
                  _scoreColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _scoreColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Grade Badge
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _scoreGrade,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Score Text
                Text(
                  '$score / $totalMarks',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_scorePercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                // Performance Message
                Text(
                  _getPerformanceMessage(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Details Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF5a189a),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Quiz Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  'Total Questions',
                  '${_result!['totalQuestions'] ?? 0}',
                  Icons.help_outline,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  'Correct Answers',
                  '${_result!['correctAnswers'] ?? 0}',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  'Wrong Answers',
                  '${_result!['wrongAnswers'] ?? 0}',
                  Icons.cancel_outlined,
                  Colors.red,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  'Score',
                  '$score marks',
                  Icons.star_outline,
                  const Color(0xFF5a189a),
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  'Total Marks',
                  '$totalMarks marks',
                  Icons.assignment_outlined,
                  Colors.blue,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Module'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5a189a),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Share result or take quiz again
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Result saved!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Result'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5a189a),
                      side: const BorderSide(color: Color(0xFF5a189a)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, [Color? iconColor]) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor ?? const Color(0xFF5a189a),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _getPerformanceMessage() {
    final percentage = _scorePercentage;
    if (percentage >= 90) {
      return 'Outstanding! You have mastered this topic! 🎉';
    } else if (percentage >= 80) {
      return 'Excellent work! Keep it up! 👏';
    } else if (percentage >= 70) {
      return 'Good job! You\'re on the right track! 👍';
    } else if (percentage >= 60) {
      return 'Not bad! Review the material and try again! 📚';
    } else {
      return 'Keep practicing! You can do better! 💪';
    }
  }
}

