import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import '../models/lesson.dart';
import '../models/module.dart';
import '../models/submodule.dart';
import '../services/lesson_service.dart';

class CreateLessonScreen extends StatefulWidget {
  final Module? module;
  final SubModule? submodule;
  final Lesson? lesson;

  const CreateLessonScreen({
    super.key,
    this.module,
    this.submodule,
    this.lesson,
  }) : assert(
          lesson != null || submodule != null,
          'Submodule is required to create a lesson. For editing, lesson must be provided.',
        );

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();

  String _selectedType = 'video';
  bool _isFree = false;
  bool _isLoading = false;
  bool _uploadCancelled = false;
  double _uploadProgress = 0.0;
  File? _contentFile;
  String? _existingFileName;

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _loadLessonData();
    }
  }

  void _loadLessonData() {
    final lesson = widget.lesson!;
    _titleController.text = lesson.title;
    _descriptionController.text = lesson.description ?? '';

    // Handle duration - if it's a number (minutes), convert to readable format
    final durationStr = lesson.duration;
    if (durationStr.isNotEmpty) {
      final minutes = int.tryParse(durationStr);
      if (minutes != null && minutes > 0) {
        // Convert minutes to readable format
        if (minutes >= 60) {
          final hours = minutes ~/ 60;
          final mins = minutes % 60;
          if (mins > 0) {
            _durationController.text = '${hours}hr ${mins}min';
          } else {
            _durationController.text = '${hours}hr';
          }
        } else {
          _durationController.text = '${minutes}min';
        }
      } else {
        // Already in readable format
        _durationController.text = durationStr;
      }
    }

    _selectedType = lesson.type;
    _isFree = lesson.isFree;
    _existingFileName =
        lesson.contentUrl != null ? lesson.contentUrl!.split('/').last : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // Parse duration string to total seconds
  // Handles formats like: "2hr", "10:05", "10 mins", "30", "1.5hr"
  int _parseDurationToSeconds(String durationStr) {
    final duration = durationStr.trim().toLowerCase();

    // Try to parse time format like "10:05" (minutes:seconds) or "1:10:05" (hours:min:sec)
    if (duration.contains(':')) {
      final parts = duration.split(':');
      if (parts.length == 3) {
        final hours = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
        final mins = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        final secs = int.tryParse(parts[2].replaceAll(RegExp(r'[^0-9]'), ''));
        if (hours != null && mins != null && secs != null) {
          return (hours * 3600) + (mins * 60) + secs;
        }
      } else if (parts.length == 2) {
        final mins = int.tryParse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
        final secs = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        if (mins != null && secs != null) {
          return (mins * 60) + secs;
        }
      }
    }

    // Handle common words and units
    final cleaned = duration
        .replaceAll('hours', '')
        .replaceAll('hour', 'hr')
        .replaceAll('hrs', 'hr')
        .replaceAll('hr', 'h')
        .replaceAll('minutes', '')
        .replaceAll('minute', 'min')
        .replaceAll('mins', 'min')
        .replaceAll('min', 'm')
        .replaceAll('seconds', '')
        .replaceAll('second', 's')
        .replaceAll('secs', 's')
        .replaceAll('sec', 's')
        .trim();

    // Try to parse as number with units
    final numberOnly = cleaned.replaceAll(RegExp(r'[^0-9.]'), '');
    if (numberOnly.isNotEmpty) {
      final value = double.tryParse(numberOnly);
      if (value != null) {
        if (cleaned.contains('h')) {
          return (value * 3600).round();
        } else if (cleaned.contains('m')) {
          return (value * 60).round();
        } else if (cleaned.contains('s')) {
          return value.round();
        } else {
          // No unit specified, assume minutes for backward compatibility if it's a whole number, 
          // but if it looks like a duration from our auto-detect, it might be seconds.
          // Let's assume minutes as it was before for manual entry.
          return (value * 60).round();
        }
      }
    }

    return 0;
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result;

      if (_selectedType == 'video') {
        // For videos, use FileType.custom with video extensions
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'],
          allowMultiple: false,
        );
      } else {
        // For PDFs, use custom type
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        // Check if file path exists (for mobile) or bytes exist (for web)
        if (pickedFile.path != null) {
          final file = File(pickedFile.path!);

          // Validate file exists
          if (await file.exists()) {
            // Validate file extension
            final extension = pickedFile.extension?.toLowerCase() ??
                pickedFile.name.split('.').last.toLowerCase();

            // Auto-detect and update type based on file extension
            final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'];
            if (videoExtensions.contains(extension)) {
              // File is a video - ensure type is set to video
              if (_selectedType != 'video') {
                setState(() {
                  _selectedType = 'video';
                });
                debugPrint(
                    'Auto-detected video type from file extension: $extension');
              }
            } else if (extension == 'pdf') {
              // File is a PDF - ensure type is set to pdf
              if (_selectedType != 'pdf') {
                setState(() {
                  _selectedType = 'pdf';
                });
                debugPrint(
                    'Auto-detected PDF type from file extension: $extension');
              }
            }

            bool isValidExtension = false;
            if (_selectedType == 'video') {
              isValidExtension = videoExtensions.contains(extension);
            } else {
              isValidExtension = extension == 'pdf';
            }

            if (!isValidExtension) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _selectedType == 'video'
                        ? 'Please select a valid video file (MP4, MOV, AVI, MKV, WEBM, M4V)'
                        : 'Please select a valid PDF file',
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              return;
            }

            // Check file size for videos (max 10 GB)
            if (_selectedType == 'video') {
              final fileSize = await file.length();
              const maxSize = 10 * 1024 * 1024 * 1024; // 10 GB in bytes

              if (fileSize > maxSize) {
                final fileSizeGB =
                    (fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Video file size ($fileSizeGB GB) exceeds the maximum limit of 10 GB. Please select a smaller file.',
                    ),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                return;
              }
            }

            setState(() {
              _contentFile = file;
              _existingFileName = pickedFile.name;
            });

            // For video files, extract duration and auto-populate duration field
            String? detectedDuration;
            if (_selectedType == 'video') {
              // Show loading indicator
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Detecting video duration...'),
                      ],
                    ),
                    backgroundColor: Colors.blue,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }

              try {
                // Ensure file exists and is readable
                if (!await file.exists()) {
                  debugPrint('Video file does not exist at path: ${file.path}');
                  return;
                }

                // Try to get video duration using VideoPlayerController
                int? durationInSeconds;
                VideoPlayerController? controller;
                try {
                  controller = VideoPlayerController.file(file);

                  // Add timeout to prevent hanging
                  await controller.initialize().timeout(
                    const Duration(seconds: 10),
                    onTimeout: () {
                      debugPrint('Video initialization timeout');
                      throw TimeoutException('Video initialization timeout');
                    },
                  );

                  // Check if initialized successfully
                  if (controller.value.isInitialized &&
                      controller.value.duration.inSeconds > 0) {
                    durationInSeconds = controller.value.duration.inSeconds;
                    debugPrint(
                        'VideoPlayer detected duration: $durationInSeconds seconds');
                  }

                  await controller.dispose();
                } on UnimplementedError catch (e) {
                  debugPrint(
                      'Video player not implemented on this platform: $e');
                  await controller?.dispose();
                } catch (e) {
                  debugPrint('VideoPlayer error: $e');
                  await controller?.dispose();
                }

                // Update duration field if we got a valid duration
                if (durationInSeconds != null && durationInSeconds > 0) {
                  final hours = durationInSeconds ~/ 3600;
                  final minutes = (durationInSeconds % 3600) ~/ 60;
                  final seconds = durationInSeconds % 60;
                  
                  if (hours > 0) {
                    detectedDuration = '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                  } else {
                    detectedDuration = '$minutes:${seconds.toString().padLeft(2, '0')}';
                  }
                  
                  setState(() {
                    _durationController.text = detectedDuration!;
                  });
                  debugPrint(
                      'Video duration detected: $durationInSeconds seconds ($detectedDuration)');
                } else {
                  // Show helpful message if detection failed
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'Could not detect video duration. Please enter it manually (e.g., "5" for 5 minutes).'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Unexpected error in video duration extraction: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Could not detect video duration. Please enter it manually.'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  );
                }
              }
            }

            // Don't upload separately - file will be sent directly in create/update lesson API

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedType == 'video'
                            ? 'Video selected: ${pickedFile.name}${detectedDuration != null ? " ($detectedDuration min)" : ""}'
                            : 'File selected: ${pickedFile.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else {
            throw Exception('File does not exist');
          }
        } else if (pickedFile.bytes != null) {
          // Handle web platform (bytes instead of path)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'File upload from web is not supported. Please use mobile app.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          throw Exception('No file selected');
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error picking file: ${e.toString().replaceAll('Exception: ', '')}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // File will be sent directly in create/update lesson API - no separate upload needed

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // For new lessons, file is required
    if (widget.lesson == null && _contentFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a video or PDF file.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadCancelled = false;
      _uploadProgress = 0.0;
    });

    try {
      if (widget.lesson != null) {
        // Parse duration to seconds (number) - Only for video lessons
        int? durationSeconds;
        if (_selectedType == 'video') {
          durationSeconds = _parseDurationToSeconds(_durationController.text.trim());
          if (durationSeconds == 0 &&
              _durationController.text.trim().isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Please enter a valid duration (e.g., "1:13", "2hr", "30 mins")'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        // Update lesson
        await LessonService.updateLesson(
          lessonId: widget.lesson!.id!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _selectedType,
          duration: (_selectedType == 'video' && durationSeconds != null && durationSeconds > 0)
              ? durationSeconds.toString()
              : null, // Send as total seconds string or null (only for video)
          isFree: _isFree,
          contentFile: _contentFile,
          onProgress: (progress) {
            if (mounted && !_uploadCancelled) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Lesson updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Parse duration to seconds (number) - Only for video lessons
        int? durationSeconds;
        if (_selectedType == 'video') {
          durationSeconds = _parseDurationToSeconds(_durationController.text.trim());
          if (durationSeconds == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Please enter a valid duration (e.g., "1:13", "2hr", "30 mins")'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        // Create lesson
        // Ensure type matches file extension
        String finalType = _selectedType;
        if (_contentFile != null) {
          final extension = path
              .extension(_contentFile!.path)
              .toLowerCase()
              .replaceFirst('.', '');
          final videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'];
          if (videoExtensions.contains(extension)) {
            finalType = 'video';
          } else if (extension == 'pdf') {
            finalType = 'pdf';
          }
        }
        debugPrint(
            'Creating lesson with type: $finalType (selected: $_selectedType, file: ${_contentFile?.path})');

        // For creating new lessons, submodule is required
        if (widget.lesson == null) {
          // Creating new lesson - submodule is required
          if (widget.submodule == null || widget.submodule!.id == null || widget.submodule!.id!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SubModule is required. Please create a submodule first.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        // For new lessons, submoduleId is required
        if (widget.lesson == null) {
          await LessonService.createLesson(
            submoduleId: widget.submodule!.id!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            type: finalType,
            duration: (finalType == 'video' && durationSeconds != null && durationSeconds > 0)
                ? durationSeconds.toString()
                : null, // Send as total seconds string or null (only for video)
            isFree: _isFree,
            contentFile: _contentFile,
            onProgress: (progress) {
              if (mounted && !_uploadCancelled) {
                setState(() {
                  _uploadProgress = progress;
                });
              }
            },
          );

          if (!mounted) return;

          // Safely show SnackBar and navigate
          try {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Lesson created successfully!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              Navigator.pop(context, true);
            }
          } catch (contextError) {
            debugPrint('Error showing success message: $contextError');
            // Still try to navigate back if context is invalid
            if (mounted) {
              Navigator.pop(context, true);
            }
          }
        }
      }
    } on LessonServiceException catch (e) {
      if (!mounted) return;
      if (_uploadCancelled) return;

      setState(() {
        _isLoading = false;
      });

      // Safely show SnackBar with context check
      try {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (contextError) {
        debugPrint('Error showing SnackBar: $contextError');
      }
    } catch (e) {
      if (!mounted) return;
      if (_uploadCancelled) return;

      setState(() {
        _isLoading = false;
      });

      // Safely show SnackBar with context check
      try {
        if (mounted && context.mounted) {
          final errorMessage = e.toString().contains('TimeoutException')
              ? 'Upload timeout. The file may be too large or your connection is slow. Please try again.'
              : 'Error: ${e.toString()}';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (contextError) {
        debugPrint('Error showing SnackBar: $contextError');
      }
    }
  }

  void _cancelUpload() {
    LessonService.cancelActiveUpload();
    if (!mounted) return;
    setState(() {
      _uploadCancelled = true;
      _isLoading = false;
      _uploadProgress = 0.0;
      _contentFile = null;
      if (widget.lesson == null) {
        _existingFileName = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5a189a), Color(0xFF7B2CBF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.lesson == null
                              ? 'Create New Lesson'
                              : 'Edit Lesson',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.submodule?.title ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Card
                      _buildSectionCard(
                        title: 'Lesson Information',
                        icon: Icons.info_outline,
                        child: Column(
                          children: [
                            // Lesson Title
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Lesson Title',
                                labelStyle: TextStyle(color: Colors.grey[700]),
                                hintText: 'Enter lesson title...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF5a189a),
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5a189a)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.title,
                                      color: Color(0xFF5a189a), size: 20),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter lesson title';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Description (Optional)',
                                labelStyle: TextStyle(color: Colors.grey[700]),
                                hintText: 'Enter lesson description...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF5a189a),
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.only(bottom: 40),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5a189a)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.description,
                                      color: Color(0xFF5a189a), size: 20),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),

                            // Duration - Only show for Video lessons
                            if (_selectedType == 'video') ...[
                              TextFormField(
                                controller: _durationController,
                                readOnly: false,
                                enabled: true,
                                decoration: InputDecoration(
                                  labelText: 'Duration',
                                  labelStyle: TextStyle(color: Colors.grey[700]),
                                  hintText: 'e.g., 2hr, 10:05, 30 mins, 120',
                                  helperText: 'Duration will be auto-detected from video (editable)',
                                  helperStyle: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF5a189a),
                                      width: 2,
                                    ),
                                  ),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5a189a)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.access_time,
                                        color: Color(0xFF5a189a), size: 20),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 16),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter duration';
                                  }
                                  // Validate that we can parse it
                                  final minutes =
                                      _parseDurationToSeconds(value.trim());
                                  if (minutes == 0) {
                                    return 'Invalid format. Use: 2hr, 10:05, 30 mins, or 120';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Type and Settings Card
                      _buildSectionCard(
                        title: 'Lesson Settings',
                        icon: Icons.settings_outlined,
                        child: Column(
                          children: [
                            // Lesson Type
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lesson Type',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTypeOption(
                                        'Video',
                                        Icons.videocam,
                                        Colors.red,
                                        'video',
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTypeOption(
                                        'PDF',
                                        Icons.picture_as_pdf,
                                        Colors.blue,
                                        'pdf',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Free/Locked Toggle
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isSmallScreen =
                                    constraints.maxWidth < 360;
                                return Container(
                                  padding:
                                      EdgeInsets.all(isSmallScreen ? 16 : 20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isFree
                                          ? [
                                              Colors.green.withValues(alpha: 0.1),
                                              Colors.green.withValues(alpha: 0.05)
                                            ]
                                          : [
                                              Colors.orange.withValues(alpha: 0.1),
                                              Colors.orange.withValues(alpha: 0.05)
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _isFree
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : Colors.orange.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(
                                                  isSmallScreen ? 8 : 10),
                                              decoration: BoxDecoration(
                                                color: _isFree
                                                    ? Colors.green
                                                        .withValues(alpha: 0.2)
                                                    : Colors.orange
                                                        .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                _isFree
                                                    ? Icons.lock_open
                                                    : Icons.lock,
                                                color: _isFree
                                                    ? Colors.green.shade700
                                                    : Colors.orange.shade700,
                                                size: isSmallScreen ? 20 : 24,
                                              ),
                                            ),
                                            SizedBox(
                                                width: isSmallScreen ? 12 : 16),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _isFree
                                                        ? 'Free Preview'
                                                        : 'Locked',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen
                                                          ? 14
                                                          : 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _isFree
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors
                                                              .orange.shade700,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _isFree
                                                        ? 'Students can view this lesson'
                                                        : 'Requires course enrollment',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen
                                                          ? 11
                                                          : 12,
                                                      color: Colors.grey[700],
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 12),
                                      Flexible(
                                        flex: 0,
                                        child: Switch(
                                          value: _isFree,
                                          onChanged: (value) {
                                            setState(() {
                                              _isFree = value;
                                            });
                                          },
                                          activeColor: Colors.green,
                                          inactiveThumbColor: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // File Upload Card
                      _buildSectionCard(
                        title: 'Content File',
                        icon: _selectedType == 'video'
                            ? Icons.video_library
                            : Icons.insert_drive_file,
                        child: Column(
                          children: [
                            if (_contentFile != null ||
                                _existingFileName != null)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isSmallScreen =
                                      constraints.maxWidth < 360;
                                  return Container(
                                    padding:
                                        EdgeInsets.all(isSmallScreen ? 12 : 16),
                                    decoration: BoxDecoration(
                                      color: (_selectedType == 'video'
                                              ? Colors.red
                                              : Colors.blue)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: (_selectedType == 'video'
                                                ? Colors.red
                                                : Colors.blue)
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(
                                                  isSmallScreen ? 8 : 12),
                                              decoration: BoxDecoration(
                                                color: (_selectedType == 'video'
                                                        ? Colors.red
                                                        : Colors.blue)
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                _selectedType == 'video'
                                                    ? Icons.videocam
                                                    : Icons.picture_as_pdf,
                                                color: _selectedType == 'video'
                                                    ? Colors.red
                                                    : Colors.blue,
                                                size: isSmallScreen ? 20 : 24,
                                              ),
                                            ),
                                            SizedBox(
                                                width: isSmallScreen ? 8 : 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _contentFile != null
                                                        ? _contentFile!.path
                                                            .split('/')
                                                            .last
                                                        : _existingFileName ??
                                                            'File',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen
                                                          ? 12
                                                          : 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _contentFile != null
                                                        ? 'File selected'
                                                        : 'Existing file',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen
                                                          ? 11
                                                          : 12,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                                width: isSmallScreen ? 4 : 8),
                                            IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                color: Colors.red,
                                                size: isSmallScreen ? 20 : 24,
                                              ),
                                              padding: EdgeInsets.all(
                                                  isSmallScreen ? 4 : 8),
                                              constraints: BoxConstraints(
                                                minWidth:
                                                    isSmallScreen ? 32 : 48,
                                                minHeight:
                                                    isSmallScreen ? 32 : 48,
                                              ),
                                              onPressed: _isLoading
                                                  ? _cancelUpload
                                                  : () {
                                                      setState(() {
                                                        _contentFile = null;
                                                        if (widget.lesson == null) {
                                                          _existingFileName = null;
                                                        }
                                                      });
                                                    },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _selectedType == 'video'
                                          ? Icons.video_library_outlined
                                          : Icons.insert_drive_file_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No file selected',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedType == 'video'
                                          ? 'Select a video file (MP4, MOV, AVI, MKV)'
                                          : 'Select a PDF file',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: Icon(
                                  _contentFile != null ||
                                          _existingFileName != null
                                      ? Icons.change_circle
                                      : Icons.upload_file,
                                ),
                                label: Text(
                                  _contentFile != null ||
                                          _existingFileName != null
                                      ? 'Change File'
                                      : 'Select File',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedType == 'video'
                                      ? Colors.red
                                      : Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                            if (widget.lesson != null && _contentFile == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Leave empty to keep existing file',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5a189a), Color(0xFF7B2CBF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5a189a).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? (_uploadProgress > 0.0 && _uploadProgress < 1.0)
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          LinearProgressIndicator(
                                            value: _uploadProgress,
                                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Please do not close the app',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        widget.lesson == null
                                            ? Icons.add_circle_outline
                                            : Icons.save_outlined,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      widget.lesson == null
                                          ? 'Create Lesson'
                                          : 'Update Lesson',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5a189a).withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5a189a).withValues(alpha: 0.15),
                  const Color(0xFF5a189a).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5a189a),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5a189a).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTypeOption(
    String label,
    IconData icon,
    Color color,
    String value,
  ) {
    final isSelected = _selectedType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = value;
          // Clear file when type changes
          _contentFile = null;
          if (widget.lesson == null) {
            _existingFileName = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color, color.withValues(alpha: 0.8)],
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
