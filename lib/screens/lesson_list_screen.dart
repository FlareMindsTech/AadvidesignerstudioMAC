import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import '../models/lesson.dart';
import '../models/module.dart';
import '../models/submodule.dart';
import '../services/lesson_service.dart';
import '../services/progress_service.dart';
import '../services/module_service.dart';
import '../services/course_service.dart';
import '../widgets/skeleton_loader.dart';
import 'create_lesson_screen.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'student_quiz_screen.dart';
import 'video_player_screen.dart';
import 'lesson_detail_screen.dart';
import '../utils/submodule_tree_builder.dart';

class LessonListScreen extends StatefulWidget {
  final Module module;

  const LessonListScreen({super.key, required this.module});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  Map<String, List<Lesson>> _lessonsBySubmodule =
      {}; // Lessons grouped by submodule ID
  bool _isLoading = true; // Start with loading state
  String _errorMessage = '';
  String? _userRole;
  Map<String, bool> _completedLessons = {}; // Track completed lessons
  Map<String, int> _moduleProgress = {}; // Track module progress percentage
  Module? _currentModule; // Store current module with updated submodules
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _currentModule = widget.module;
    _loadUserRole();
    _loadLessons();
    _loadModuleData();
    if (!_isAdminOrOwner) {
      _loadModuleProgress();
    }
  }

  Future<void> _loadModuleData() async {
    // Get the course ID from the module
    if (widget.module.courseId == null) return;

    try {
      final courseWithModules = await CourseService.getSingleCourseWithModules(
        widget.module.courseId!,
      );
      if (mounted) {
        // Find the current module in the loaded modules
        final updatedModule = courseWithModules.modules.firstWhere(
          (m) => m.id == widget.module.id,
          orElse: () => widget.module,
        );
        setState(() {
          _currentModule = updatedModule;
        });
      }
    } catch (e) {
      debugPrint('Error loading module data: $e');
      // Keep using the widget.module if loading fails
    }
  }

  Future<void> _loadModuleProgress() async {
    if (widget.module.id == null) return;

    try {
      final progress = await ProgressService.getModuleProgress(
        widget.module.id!,
      );
      if (mounted) {
        setState(() {
          _moduleProgress[widget.module.id!] = progress.percentageCompleted;
          // Mark lessons as completed based on progress data if available
          // This is a simplified approach - you may need to adjust based on API response
        });
      }
    } catch (e) {
      debugPrint('Error loading module progress: $e');
    }
  }

  Future<void> _markLessonComplete(Lesson lesson) async {
    if (lesson.id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final percentage = await ProgressService.markLessonComplete(lesson.id!);
      if (mounted) {
        setState(() {
          _completedLessons[lesson.id!] = true;
          _moduleProgress[widget.module.id ?? ''] = percentage;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Lesson marked as complete!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Reload module progress
        _loadModuleProgress();
      }
    } on ProgressServiceException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to mark lesson as complete. Please try again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadUserRole() async {
    final role = await StorageService.getRole();
    if (mounted) {
      setState(() {
        _userRole = role?.toLowerCase();
      });
    }
  }

  bool get _isAdminOrOwner {
    return _userRole == 'admin' || _userRole == 'owner';
  }

  Future<void> _loadLessons() async {
    // Reload module data to get latest submodules
    await _loadModuleData();

    if (_currentModule?.submodules == null ||
        _currentModule!.submodules!.isEmpty) {
      if (mounted) {
        setState(() {
          _lessonsBySubmodule = {};
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load lessons from all submodules and group by submodule ID
      Map<String, List<Lesson>> lessonsBySubmodule = {};
      for (final submodule in _currentModule!.submodules!) {
        if (submodule.id != null) {
          try {
            final lessons = await LessonService.getModuleLessons(submodule.id!);
            lessonsBySubmodule[submodule.id!] = lessons;
          } catch (e) {
            debugPrint(
              'Error loading lessons for submodule ${submodule.id}: $e',
            );
            // Continue loading other submodules even if one fails
            lessonsBySubmodule[submodule.id!] = [];
          }
        }
      }

      if (mounted) {
        setState(() {
          _lessonsBySubmodule = lessonsBySubmodule;
          _isLoading = false;
        });
      }
    } on LessonServiceException catch (e) {
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
          _errorMessage = 'Failed to load lessons. Please try again.';
        });
      }
    }
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    if (lesson.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Lesson',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to delete "${lesson.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistic Update: Immediately remove the lesson from the UI
    setState(() {
      _lessonsBySubmodule.values.forEach((lessonList) {
        lessonList.removeWhere((l) => l.id == lesson.id);
      });
    });

    try {
      await LessonService.deleteLesson(lesson.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Lesson deleted successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        // No need to call _loadLessons() here, it's already removed optimistically!
      }
    } on LessonServiceException catch (e) {
      if (mounted) {
        _loadLessons(); // Restore the item since it failed to delete
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _loadLessons(); // Restore the item since it failed to delete
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete lesson. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Modern Sliver App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primaryColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context, _hasChanges),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: 56,
                bottom: 15,
                right: 16,
              ),
              title: const Text(
                'Lessons',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                      const Color(0xFF7B2CBF),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 56,
                      right: 72,
                      bottom: 70,
                      child: Text(
                        widget.module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Lesson Count Badge
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.library_books,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_lessonsBySubmodule.values.fold<int>(0, (sum, lessons) => sum + lessons.length)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Progress Indicator (for students only)
              if (!_isAdminOrOwner &&
                  _moduleProgress.containsKey(widget.module.id))
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.track_changes,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_moduleProgress[widget.module.id]}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              // Quiz Button (for students only)
              if (!_isAdminOrOwner)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.quiz,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  tooltip: 'Take Quiz',
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        child: StudentQuizScreen(module: widget.module),
                      ),
                    );
                  },
                ),
            ],
          ),

          // Content Section
          SliverToBoxAdapter(
            child: Container(
                padding: const EdgeInsets.only(top: 8, bottom: 120),
              child: _isLoading
                  ? _buildLoadingState()
                  : _lessonsBySubmodule.isEmpty ||
                        _lessonsBySubmodule.values.every(
                          (lessons) => lessons.isEmpty,
                        )
                  ? _buildEmptyState()
                  : _buildLessonsList(),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          5,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const SkeletonLoader(
              width: double.infinity,
              height: 100,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLessonsList() {
    // Get all submodules from current module
    final flatSubmodules = _currentModule?.submodules ?? [];

    // Convert the flat list to a nested tree structure
    final rootSubmodules = SubModuleTreeBuilder.buildTree(flatSubmodules);

    return RefreshIndicator(
      onRefresh: _loadLessons,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: rootSubmodules.length,
        itemBuilder: (context, index) {
          final submodule = rootSubmodules[index];
          return _buildNestedSubModule(submodule, 0);
        },
      ),
    );
  }

  Widget _buildNestedSubModule(SubModule submodule, int depth) {
    final submoduleId = submodule.id;
    final lessons = submoduleId != null
        ? (_lessonsBySubmodule[submoduleId] ?? [])
        : [];
    final childrenSubmodules = submodule.subModules ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: depth == 0 ? 0 : 16.0,
        bottom: depth == 0 ? 24.0 : 8.0,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Container(
          decoration: BoxDecoration(
            color: depth == 0
                ? Colors.transparent
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(depth == 0 ? 0.3 : 0.1),
              width: 1,
            ),
          ),
          child: ExpansionTile(
            initiallyExpanded: depth == 0,
            collapsedBackgroundColor: depth == 0
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            backgroundColor: depth == 0
                ? AppTheme.primaryColor.withOpacity(0.05)
                : Colors.grey.withOpacity(0.02),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(
              childrenSubmodules.isNotEmpty ? Icons.folder : Icons.topic,
              color: AppTheme.primaryColor,
            ),
            title: Text(
              submodule.title,
              style: TextStyle(
                fontSize: depth == 0 ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            subtitle: (lessons.isNotEmpty || childrenSubmodules.isNotEmpty)
                ? Text(
                    '${childrenSubmodules.length} folders, ${lessons.length} lessons',
                    style: TextStyle(fontSize: 12),
                  )
                : null,
            childrenPadding: const EdgeInsets.all(12),
            children: [
              // 1. Render Child Submodules Recursively
              ...childrenSubmodules.map(
                (child) => _buildNestedSubModule(child, depth + 1),
              ),

              // 2. Render Lessons at this level
              if (lessons.isEmpty && childrenSubmodules.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Empty folder',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...lessons.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildModernLessonCard(entry.value, entry.key),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final hasSubmodules =
        _currentModule?.submodules != null &&
        _currentModule!.submodules!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _isAdminOrOwner
            ? () {
                if (hasSubmodules) {
                  // Show dialog to select submodule or create new one
                  _showSubmoduleSelectionDialog();
                } else {
                  _showAddSubModuleDialog();
                }
              }
            : () {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.rightToLeft,
                    child: StudentQuizScreen(module: widget.module),
                  ),
                );
              },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(
          _isAdminOrOwner
              ? (hasSubmodules
                    ? Icons.add_circle_outline
                    : Icons.add_circle_outline)
              : Icons.quiz,
        ),
        label: Text(
          _isAdminOrOwner
              ? (hasSubmodules ? 'Add Lesson / Submodule' : 'Create Submodule')
              : 'Take Quiz',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Future<void> _showSubmoduleSelectionDialog() async {
    if (_currentModule?.submodules == null ||
        _currentModule!.submodules!.isEmpty) {
      _showAddSubModuleDialog();
      return;
    }

    final result = await showDialog<SubModule>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Submodule',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _currentModule!.submodules!.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text('Create New Submodule'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddSubModuleDialog();
                  },
                );
              }
              final submodule = _currentModule!.submodules![index - 1];
              return ListTile(
                leading: Icon(Icons.topic, color: AppTheme.primaryColor),
                title: Text(submodule.title),
                onTap: () {
                  Navigator.pop(context, submodule);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.rightToLeft,
          child: CreateLessonScreen(module: _currentModule, submodule: result),
        ),
      ).then((result) async {
        if (result == true && mounted) {
          _hasChanges = true;
          await _loadLessons();
          await _loadModuleData();
        }
      });
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.15),
                    AppTheme.primaryColor.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.play_circle_outline_rounded,
                size: 100,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Lessons Yet',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _isAdminOrOwner
                    ? (_currentModule?.submodules != null &&
                              _currentModule!.submodules!.isNotEmpty
                          ? 'Select a submodule below to add lessons, or create a new submodule.'
                          : 'Lessons can only be created under submodules. Please create a submodule first, then add lessons to it.')
                    : 'No lessons are available for this module yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            if (_isAdminOrOwner) ...[
              const SizedBox(height: 40),
              // Show submodules list if they exist
              if (_currentModule?.submodules != null &&
                  _currentModule!.submodules!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Available Submodules:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._currentModule!.submodules!.map((submodule) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.topic,
                              color: AppTheme.primaryColor,
                            ),
                            title: Text(submodule.title),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                PageTransition(
                                  type: PageTransitionType.rightToLeft,
                                  child: CreateLessonScreen(
                                    module: _currentModule,
                                    submodule: submodule,
                                  ),
                                ),
                              ).then((result) async {
                                if (result == true && mounted) {
                                  _hasChanges = true;
                                  await _loadLessons();
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernLessonCard(Lesson lesson, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isCompleted =
        !_isAdminOrOwner && (_completedLessons[lesson.id] ?? false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: LessonDetailScreen(lesson: lesson),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 18 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lesson Number Badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Content Section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  lesson.title,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 17 : 19,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[900],
                                    height: 1.3,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Free Badge
                              if (lesson.isFree)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade500,
                                        Colors.green.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_open_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'FREE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Metadata Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Duration Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 14,
                                      color: Colors.grey[700],
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      lesson.duration,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 11 : 12,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Type Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: lesson.isVideo
                                        ? [
                                            Colors.red.shade50,
                                            Colors.red.shade100,
                                          ]
                                        : [
                                            Colors.blue.shade50,
                                            Colors.blue.shade100,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: lesson.isVideo
                                        ? Colors.red.shade200
                                        : Colors.blue.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      lesson.isVideo
                                          ? Icons.play_circle_filled_rounded
                                          : Icons.picture_as_pdf_rounded,
                                      size: 14,
                                      color: lesson.isVideo
                                          ? Colors.red.shade700
                                          : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      lesson.type.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 10 : 11,
                                        fontWeight: FontWeight.bold,
                                        color: lesson.isVideo
                                            ? Colors.red.shade700
                                            : Colors.blue.shade700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Completed Badge (for students)
                              if (isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade50,
                                        Colors.green.shade100,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          // Description
                          if (lesson.description != null &&
                              lesson.description!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              lesson.description!,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Actions Menu (Admin only)
                    if (_isAdminOrOwner)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.more_vert_rounded,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          onSelected: (value) {
                            if (value == 'edit') {
                              // Find which submodule this lesson belongs to
                              SubModule? targetSubmodule;
                              if (_currentModule?.submodules != null) {
                                for (var sm in _currentModule!.submodules!) {
                                  if (sm.lessons?.any((l) => l.id == lesson.id) == true) {
                                    targetSubmodule = sm;
                                    break;
                                  }
                                }
                              }

                              Navigator.push(
                                context,
                                PageTransition(
                                  type: PageTransitionType.rightToLeft,
                                  child: CreateLessonScreen(
                                    module: _currentModule,
                                    submodule: targetSubmodule,
                                    lesson: lesson,
                                  ),
                                ),
                              ).then((result) async {
                                if (result == true && mounted) {
                                  _hasChanges = true;
                                  await _loadLessons();
                                  await _loadModuleData();
                                }
                              });
                            } else if (value == 'delete') {
                              _deleteLesson(lesson);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.blue,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Edit Lesson',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_rounded,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Delete Lesson',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLessonOptions(Lesson lesson) {
    final isCompleted = _completedLessons[lesson.id] ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  lesson.isVideo ? Icons.play_circle : Icons.picture_as_pdf,
                  color: Colors.blue,
                ),
              ),
              title: Text(
                lesson.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(lesson.description ?? 'No description'),
            ),
            const Divider(),
            if (isCompleted)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Lesson Completed'),
                subtitle: const Text('You have already completed this lesson'),
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.blue,
                ),
                title: const Text('Mark as Complete'),
                subtitle: const Text('Mark this lesson as completed'),
                onTap: () {
                  Navigator.pop(context);
                  _markLessonComplete(lesson);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSubModuleDialog() async {
    if (widget.module.id == null) return;

    final titleController = TextEditingController();
    final orderController = TextEditingController(
      text: ((widget.module.submodules?.length ?? 0) + 1).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Sub-Topic',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Sub-Topic Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: orderController,
              decoration: const InputDecoration(
                labelText: 'Order',
                border: OutlineInputBorder(),
                helperText: 'Sub-topic display order',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a sub-topic title'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final order = int.tryParse(orderController.text);
              if (order == null || order < 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid order number'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      final order = int.parse(orderController.text);
      await _addSubModule(titleController.text.trim(), order);
    }
  }

  Future<void> _addSubModule(String title, int order) async {
    if (widget.module.id == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await ModuleService.createSubModule(
        moduleId: widget.module.id!,
        title: title,
        order: order,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sub-topic added successfully! You can now add lessons to it.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _isLoading = false;
      });

      // Reload module data to get updated submodules
      await _loadModuleData();
    } on ModuleServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add sub-topic. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }
}
