import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meeting_app/screens/student_notifications_screen.dart';
import 'package:page_transition/page_transition.dart';
import '../services/course_service.dart';
import '../services/storage_service.dart';
import '../models/course.dart';
import '../widgets/app_drawer.dart';

class CreateCourseScreen extends StatefulWidget {
  final Course? course;

  const CreateCourseScreen({super.key, this.course});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _durationController = TextEditingController();
  final _durationInDaysController = TextEditingController();
  final _emiDurationController =
      TextEditingController(); // Number of installments
  final _emiAmountController =
      TextEditingController(); // Amount per installment

  bool _isLiveCourse = false;
  bool _isRecurring = false;
  bool _isPaidCourse = false;
  bool _supportsEMI = false;
  bool _supportsFullPayment = false;
  bool _isLoading = false;
  File? _thumbnailFile;
  String? _existingThumbnailUrl;
  String? _currentUserId;
  String _durationDaysHelperText = '';

  @override
  void initState() {
    super.initState();
    _durationInDaysController.addListener(_updateDurationInDaysHelperText);
    _loadCurrentUser();
    if (widget.course != null && widget.course!.id != null) {
      _loadCourseDataFromAPI();
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await StorageService.getUser();
    if (user != null) {
      setState(() {
        _currentUserId = user.id ?? '';
      });
    }
  }

  Future<void> _loadCourseDataFromAPI() async {
    if (widget.course?.id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('=== Loading Course Data from API ===');
      debugPrint('Course ID: ${widget.course!.id}');

      // Fetch course data from API
      final course = await CourseService.getSingleCourse(widget.course!.id!);

      debugPrint('Course Title: ${course.title}');
      debugPrint('Supports EMI: ${course.supportsEMI}');
      debugPrint('Payment Options Obj: ${course.paymentOptionsObj}');

      // Populate all fields with API data
      _titleController.text = course.title;
      _descriptionController.text = course.description;
      _categoryController.text = course.category;
      _priceController.text = course.price.toString();
      _discountController.text =
          course.discount != null && course.discount! > 0
              ? course.discount!.toString()
              : '';
      _durationController.text = course.duration;
      _durationInDaysController.text = (course.durationinDays ?? 0).toString();
      _isLiveCourse = course.isLiveCourse;
      _isRecurring = course.isRecurring;
      _isPaidCourse = course.price > 0;
      _supportsEMI = course.supportsEMI;
      _supportsFullPayment = course.supportsFullPayment;
      _existingThumbnailUrl = course.thumbnail;

      debugPrint('_supportsEMI set to: $_supportsEMI');
      debugPrint('paymentOptionsObj is null: ${course.paymentOptionsObj == null}');

      // Load EMI plan details if available
      if (course.supportsEMI && course.paymentOptionsObj != null) {
        debugPrint('Entering EMI plan loading...');
        final emiPlans = course.paymentOptionsObj!['emiPlans'] as List?;
        debugPrint('EMI Plans: $emiPlans');
        debugPrint('EMI Plans is null: ${emiPlans == null}');
        debugPrint('EMI Plans isEmpty: ${emiPlans?.isEmpty ?? true}');

        if (emiPlans != null && emiPlans.isNotEmpty) {
          debugPrint('Processing EMI plan...');
          // Get the first EMI plan (assuming single plan for now)
          final emiPlan = emiPlans[0] as Map<String, dynamic>;
          debugPrint('EMI Plan Data: $emiPlan');

          final installments = emiPlan['installments'] as int? ?? 0;
          final totalAmount =
              (emiPlan['totalAmount'] as num?)?.toDouble() ?? 0.0;

          debugPrint('Installments: $installments');
          debugPrint('Total Amount: $totalAmount');

          // Get per installment amount from API or calculate it
          final perInstallmentAmount =
              (emiPlan['perinstallmentAmount'] as num?)?.toDouble() ??
                  (installments > 0 ? totalAmount / installments : 0.0);

          debugPrint('Per Installment Amount: $perInstallmentAmount');

          // Populate EMI fields
          _emiDurationController.text = installments.toString();
          _emiAmountController.text = perInstallmentAmount.toStringAsFixed(0);

          debugPrint('EMI Duration Controller: ${_emiDurationController.text}');
          debugPrint('EMI Amount Controller: ${_emiAmountController.text}');
          debugPrint('=== EMI Data Loaded Successfully ===');
        } else {
          debugPrint('EMI Plans is null or empty');
        }
      } else {
        debugPrint('EMI not supported or paymentOptionsObj is null');
        debugPrint('supportsEMI: ${course.supportsEMI}');
        debugPrint('paymentOptionsObj: ${course.paymentOptionsObj}');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading course data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load course data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _durationController.dispose();
    _durationInDaysController.dispose();
    _emiDurationController.dispose();
    _emiAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _thumbnailFile = File(pickedFile.path);
        _existingThumbnailUrl = null;
      });
    }
  }

  void _handleThumbnailTap() {
    if (_thumbnailFile != null || _existingThumbnailUrl != null) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.fullscreen),
                title: const Text('View Full Image'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Center(
                          child: InteractiveViewer(
                            child: _thumbnailFile != null
                                ? Image.file(_thumbnailFile!)
                                : (_existingThumbnailUrl != null ? Image.network(_existingThumbnailUrl!) : const SizedBox()),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Change Thumbnail'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Thumbnail',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _thumbnailFile = null;
                    _existingThumbnailUrl = null;
                  });
                },
              ),
            ],
          ),
        ),
      );
    } else {
      _pickImage();
    }
  }

  void _updateDurationInDaysHelperText() {
    final text = _durationInDaysController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _durationDaysHelperText = '';
      });
      return;
    }

    final days = int.tryParse(text);
    if (days == null || days <= 0) {
      setState(() {
        _durationDaysHelperText = '';
      });
      return;
    }

    // Approximate months using 30 days per month as per example (180 -> 6 months)
    String helper;
    if (days < 30) {
      helper = 'Less than 1 Month.';
    } else {
      if (days % 30 == 0) {
        final months = days ~/ 30;
        helper = 'Equivalent to $months Month${months == 1 ? '' : 's'}.';
      } else {
        final months = (days / 30).toStringAsFixed(1);
        helper = 'Approximately $months Months.';
      }
    }

    setState(() {
      _durationDaysHelperText = helper;
    });
  }

  Future<void> _handleSubmit() async {
    // Validate form - this will show validation errors
    if (!_formKey.currentState!.validate()) {
      // Scroll to first error if validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_currentUserId == null || _currentUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if thumbnail is required (for new courses)
    if (widget.course == null &&
        _thumbnailFile == null &&
        _existingThumbnailUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a thumbnail image for the course.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Form validation already handles EMI fields via validators
    // No need for additional manual validation here

    setState(() {
      _isLoading = true;
    });

    try {
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final durationInDays = int.tryParse(_durationInDaysController.text) ?? 0;
      final emiDuration =
          int.tryParse(_emiDurationController.text.trim().isEmpty
                  ? '0'
                  : _emiDurationController.text.trim()) ??
              0;
      final emiAmount = double.tryParse(
          _emiAmountController.text.trim().isEmpty
              ? '0'
              : _emiAmountController.text.trim());
      final discount = _discountController.text.trim().isEmpty
          ? null
          : double.tryParse(_discountController.text.trim());

      // Build paymentOptions as List<String> format for API
      // The API expects ['EMI', 'FULL'] format, not the Map format
      List<String>? paymentOptions;
      if (_isPaidCourse && (_supportsEMI || _supportsFullPayment)) {
        paymentOptions = [];
        
        if (_supportsFullPayment) {
          paymentOptions.add('FULL');
        }
        
        if (_supportsEMI) {
          paymentOptions.add('EMI');
        }
      }

      // Debug: print the payload that will be sent to the API
      final payloadDebug = {
        'mode': widget.course != null ? 'update' : 'create',
        'courseId': widget.course?.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
        'price': price,
        'discount': discount,
        'createdBy': _currentUserId,
        'duration': _durationController.text.trim(),
        'durationInDays': durationInDays,
        'isLiveCourse': _isLiveCourse,
        'isRecurring': _isRecurring,
        'isPaidCourse': _isPaidCourse,
        'supportsEMI': _supportsEMI,
        'supportsFullPayment': _supportsFullPayment,
        'paymentOptions': paymentOptions,
        'emiDuration': emiDuration,
        'emiAmount': emiAmount,
        'hasThumbnailFile': _thumbnailFile != null,
      };
      debugPrint('=== Course Form Payload ===');
      debugPrint(payloadDebug.toString());

      if (widget.course != null) {
        // Update course
        await CourseService.updateCourse(
          courseId: widget.course!.id!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim(),
          price: price,
          discount: discount,
          createBy: _currentUserId!,
          duration: _durationController.text.trim(),
          thumbnail: _thumbnailFile,
          isLiveCourse: _isLiveCourse,
          isRecurring: _isRecurring,
          durationinDays: durationInDays,
          paymentOptions: paymentOptions,
          emiDuration: _supportsEMI ? emiDuration : null,
          emiAmount: _supportsEMI ? emiAmount : null,
        );
      } else {
        // Create course
        await CourseService.createCourse(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _categoryController.text.trim(),
          price: price,
          discount: discount,
          createBy: _currentUserId!,
          duration: _durationController.text.trim(),
          thumbnail: _thumbnailFile,
          isLiveCourse: _isLiveCourse,
          isRecurring: _isRecurring,
          durationinDays: durationInDays,
          paymentOptions: paymentOptions,
          emiDuration: _supportsEMI ? emiDuration : null,
          emiAmount: _supportsEMI ? emiAmount : null,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.course != null
              ? 'Course updated successfully!'
              : 'Course created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on CourseServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
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
          content: Text('An unexpected error occurred. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Header with SafeArea top padding
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
            ),
            color: const Color(0xFF5a189a),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56, maxHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Aadvi Fashion Institute',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: const StudentNotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Content with SafeArea
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      _buildHeaderCard(),
                      const SizedBox(height: 24),

                      // Thumbnail
                      _buildThumbnailSection(),
                      const SizedBox(height: 24),

                      // Form Fields
                      _buildFormFields(),
                      const SizedBox(height: 100), // Space for fixed button
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Fixed bottom button
          _buildFixedBottomButton(),
        ],
      ),
      // ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5a189a), Color(0xFF7B2CBF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5a189a).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.book_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.course != null ? 'Edit Course' : 'Create New Course',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill in the details to ${widget.course != null ? 'update' : 'create'} a course',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Thumbnail',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _handleThumbnailTap,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _thumbnailFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _thumbnailFile!,
                      fit: BoxFit.cover,
                    ),
                  )
                : _existingThumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _existingThumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      )
                    : _buildPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Tap to add thumbnail',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _titleController,
          label: 'Course Title',
          icon: Icons.title,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Title is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _descriptionController,
          label: 'Description',
          icon: Icons.description,
          maxLines: 4,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Description is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _categoryController,
          label: 'Category',
          icon: Icons.category,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Category is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _priceController,
          label: 'Price (₹)',
          icon: Icons.currency_rupee,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Price is required';
            }
            if (double.tryParse(value) == null) {
              return 'Enter a valid price';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _discountController,
          label: 'Discount (₹)',
          icon: Icons.local_offer,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return null; // Optional field
            }
            final parsed = double.tryParse(value);
            if (parsed == null || parsed < 0) {
              return 'Enter a valid discount';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _durationController,
          label: 'Duration (e.g., 10 hours)',
          icon: Icons.access_time,
          validator: (value) =>
              value?.isEmpty ?? true ? 'Duration is required' : null,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _durationInDaysController,
          label: 'Validity (Total Days)',
          icon: Icons.calendar_today,
          keyboardType: TextInputType.number,
          helperText: _durationDaysHelperText.isEmpty
              ? null
              : _durationDaysHelperText,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Validity (total days) is required';
            }
            if (int.tryParse(value) == null) {
              return 'Enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        // Course Type
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Course Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Live Course'),
                value: _isLiveCourse,
                onChanged: (value) {
                  setState(() {
                    _isLiveCourse = value;
                  });
                },
                activeColor: const Color(0xFF5a189a),
              ),
              SwitchListTile(
                title: const Text('Enable Renewal'),
                subtitle: const Text(
                  'Allow this course to be treated as recurring for subscription/renewal.',
                ),
                value: _isRecurring,
                onChanged: (value) => setState(() => _isRecurring = value),
                activeColor: const Color(0xFF5a189a),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Payment Options
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Options',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Paid Course'),
                subtitle: const Text('Enable payment options for this course'),
                value: _isPaidCourse,
                onChanged: (value) {
                  setState(() {
                    _isPaidCourse = value;
                    if (!value) {
                      _supportsEMI = false;
                      _supportsFullPayment = false;
                    }
                  });
                },
                activeColor: const Color(0xFF5a189a),
              ),
              if (_isPaidCourse) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('EMI Payment'),
                  value: _supportsEMI,
                  onChanged: (value) {
                    setState(() {
                      _supportsEMI = value ?? false;
                      if (!_supportsEMI) {
                        // Clear EMI fields when unchecked
                        _emiDurationController.clear();
                        _emiAmountController.clear();
                      }
                    });
                  },
                  activeColor: const Color(0xFF5a189a),
                ),
                // EMI Configuration Fields (shown when EMI is enabled)
                if (_supportsEMI) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emiDurationController,
                    label: 'EMI Duration (Number of Installments)',
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      // Only validate if EMI is enabled
                      if (!_supportsEMI) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter EMI duration';
                      }
                      final duration = int.tryParse(value.trim());
                      if (duration == null || duration <= 0) {
                        return 'Please enter a valid number (greater than 0)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emiAmountController,
                    label: 'EMI Amount (Per Installment)',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      // Only validate if EMI is enabled
                      if (!_supportsEMI) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter EMI amount';
                      }
                      final amount = double.tryParse(value.trim());
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount (greater than 0)';
                      }
                      return null;
                    },
                  ),
                ],
                CheckboxListTile(
                  title: const Text('Full Payment'),
                  value: _supportsFullPayment,
                  onChanged: (value) =>
                      setState(() => _supportsFullPayment = value ?? false),
                  activeColor: const Color(0xFF5a189a),
                ),
                if (!_supportsEMI && !_supportsFullPayment)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Please select at least one payment option',
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? helperText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon, color: const Color(0xFF5a189a)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF5a189a),
              width: 2,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildFixedBottomButton() {
    // Button should always be enabled unless loading
    final bool isButtonEnabled = !_isLoading;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isButtonEnabled ? _handleSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5a189a),
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: const Color(0xFF5a189a).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.course != null ? 'Updating...' : 'Creating...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.course != null ? Icons.save : Icons.add,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.course != null
                            ? 'Update Course'
                            : 'Create Course',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      // ],
      // ),
    );
  }
}
