import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../config/api_config.dart';
import 'package:page_transition/page_transition.dart';
import '../models/lesson.dart';
import 'pdf_viewer_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  bool _isVideoLoading = false;
  bool _isBunnyLoading = true;
  bool _bunnyHasLoaded = false;
  bool _isFullScreen = false;
  String? _videoError;
  double _playbackSpeed = 1.0; // Default playback speed
  bool _showSpeedMenu = false;
  static const _securityChannel = MethodChannel(
    'com.flareminds.meetapp/security',
  );

  @override
  void initState() {
    super.initState();
    _enableScreenProtection();
    if (widget.lesson.isVideo &&
        widget.lesson.contentUrl != null &&
        widget.lesson.contentUrl!.isNotEmpty &&
        !_hasBunnyStreamVideo) {
      _initializeVideo();
    }
  }

  bool get _hasBunnyStreamVideo =>
      widget.lesson.bunnyVideoId != null &&
      widget.lesson.bunnyVideoId!.isNotEmpty &&
      widget.lesson.bunnyLibraryId != null &&
      widget.lesson.bunnyLibraryId!.isNotEmpty;

  Future<void> _enableScreenProtection() async {
    if (Platform.isAndroid) {
      try {
        await _securityChannel.invokeMethod('enableSecure');
      } catch (e) {
        debugPrint('Failed to enable screen protection: $e');
      }
    }
  }

  Future<void> _disableScreenProtection() async {
    if (Platform.isAndroid) {
      try {
        await _securityChannel.invokeMethod('disableSecure');
      } catch (e) {
        debugPrint('Failed to disable screen protection: $e');
      }
    }
  }

  Future<void> _initializeVideo({bool useOriginal = false}) async {
    // Ensure cleanup of any existing controller first
    if (_videoController != null) {
      try {
        await _videoController!.pause();
        await _videoController!.dispose();
      } catch (e) {
        debugPrint('Cleanup error: $e');
      }
      _videoController = null;
    }

    if (!mounted ||
        widget.lesson.contentUrl == null ||
        widget.lesson.contentUrl!.isEmpty) {
      return;
    }

    setState(() {
      _isVideoLoading = true;
      _isVideoInitialized = false;
      _videoError = null;
    });

    try {
      // Ensure the URL is sanitized (Https)
      String videoUrl = widget.lesson.contentUrl!;
      if (videoUrl.startsWith('http://')) {
        videoUrl = videoUrl.replaceFirst('http://', 'https://');
      }

      // CLOUDINARY OPTIMIZATION:
      // We force H.264 (vc_h264) codec which is 100% compatible with all hardware.
      // We use 'f_mp4' to ensure it doesn't try to send a buggy HEVC stream.
      if (!useOriginal && videoUrl.contains('res.cloudinary.com')) {
        if (videoUrl.contains('/upload/')) {
          videoUrl = videoUrl.replaceFirst(
            '/upload/',
            '/upload/vc_h264,ac_aac,q_auto,f_mp4/',
          );
        }
      }

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      // Listen for initialization and errors
      await _videoController!.initialize();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });

        _videoController!.addListener(() {
          if (mounted) {
            final bool isPlaying = _videoController!.value.isPlaying;
            if (_isVideoPlaying != isPlaying) {
              setState(() {
                _isVideoPlaying = isPlaying;
              });
            }

            // Handle player errors dynamically
            if (_videoController!.value.hasError) {
              setState(() {
                _videoError = _videoController!.value.errorDescription;
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Video initialization error: $e');

      // SMART RETRY: If Cloudinary is busy (423 Locked), wait and try optimized AGAIN.
      // Do NOT fallback to original yet, because original is corrupting the chip.
      if (!useOriginal && e.toString().contains('423')) {
        debugPrint('Cloudinary is still optimizing. Retrying in 3 seconds...');
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _initializeVideo(useOriginal: false);
          });
        }
        return;
      }

      // AUTO FALLBACK: Only fallback for other non-423 errors
      if (!useOriginal && e.toString().contains('Source error')) {
        debugPrint('General source error. Falling back to original...');
        _initializeVideo(useOriginal: true);
        return;
      }

      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _videoError =
              'Your device is having trouble decoding this high-quality video. Please try again.';
        });
      }
    }
  }

  String get _displayDuration {
    if (_isVideoInitialized && _videoController != null) {
      final duration = _videoController!.value.duration;
      if (duration.inSeconds > 0) {
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        final seconds = duration.inSeconds % 60;
        if (hours > 0) {
          return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else {
          return '$minutes:${seconds.toString().padLeft(2, '0')}';
        }
      }
    }
    return widget.lesson.duration.isNotEmpty
        ? widget.lesson.duration
        : 'Loading...';
  }

  void _toggleVideoPlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _changePlaybackSpeed(double speed) {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      _playbackSpeed = speed;
      _videoController!.setPlaybackSpeed(speed);
    });
  }

  void _showPlaybackSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Playback Speed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                children: [
                  ...([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                    final isSelected = _playbackSpeed == speed;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? const Color(0xFF5a189a)
                            : Colors.grey[400],
                      ),
                      title: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        _changePlaybackSpeed(speed);
                        Navigator.pop(context);
                      },
                    );
                  })),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showQualityDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Video Quality',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.high_quality,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Auto',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: const Text(
                      'Best quality available',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Auto quality selected (Default)'),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(Icons.hd, color: Colors.white),
                    title: const Text(
                      '1080p FHD',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: const Text(
                      'Full High definition',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '1080p FHD selected (Requires Bunny Stream)',
                          ),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.hd, color: Colors.white),
                    title: const Text(
                      '720p HD',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: const Text(
                      'High definition',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '720p HD selected (Requires Bunny Stream)',
                          ),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sd, color: Colors.white),
                    title: const Text(
                      '480p SD',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: const Text(
                      'Standard definition',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '480p SD selected (Requires Bunny Stream)',
                          ),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<void> _enterFullScreen() async {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      _isFullScreen = true;
    });

    // Detect video orientation and set appropriate preferred orientation
    final double aspectRatio = _videoController!.value.aspectRatio;
    if (aspectRatio < 1.0) {
      // For vertical (portrait) videos
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      // For horizontal (landscape) videos
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    // Hide system UI for immersive fullscreen
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Show fullscreen dialog
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _FullScreenVideoPlayer(
            controller: _videoController!,
            lesson: widget.lesson,
            onExit: _exitFullScreen,
          ),
          fullscreenDialog: true,
        ),
      );
    }

    await _exitFullScreen();
  }

  Future<void> _exitFullScreen() async {
    // Restore system UI
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Set portrait orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (mounted) {
      setState(() {
        _isFullScreen = false;
      });
    }
  }

  Future<void> _openFileExternally(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open file'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _disableScreenProtection();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF5a189a),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.lesson.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Content Viewer Section
            SliverToBoxAdapter(child: _buildContentViewer()),

            // Lesson Info Section
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF5a189a), Color(0xFF9C27B0)],
                      ).createShader(bounds),
                      child: Text(
                        widget.lesson.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Meta Information Cards
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildModernMetaCard(
                          icon: _getTypeIcon(widget.lesson.type),
                          label: widget.lesson.type.toUpperCase(),
                          color: _getTypeColor(widget.lesson.type),
                        ),
                        if (widget.lesson.isVideo)
                          _buildModernMetaCard(
                            icon: Icons.access_time_rounded,
                            label: _displayDuration,
                            color: Colors.blue,
                          ),
                        _buildModernMetaCard(
                          icon: Icons.lock_open_rounded,
                          label: 'Unlocked',
                          color: const Color(0xFF5a189a),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description
                    if (widget.lesson.description != null &&
                        widget.lesson.description!.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5a189a), Color(0xFF9C27B0)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          widget.lesson.description!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF4A4A4A),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentViewer() {
    if (widget.lesson.contentUrl == null || widget.lesson.contentUrl!.isEmpty) {
      return _buildEmptyContentViewer();
    }

    if (widget.lesson.isVideo) {
      return _buildVideoViewer();
    } else if (widget.lesson.isPdf) {
      return _buildPdfViewer();
    } else if (widget.lesson.isExcel) {
      return _buildExcelViewer();
    } else if (widget.lesson.isImage) {
      return _buildImageViewer();
    } else if (widget.lesson.isText) {
      return _buildTextViewer();
    } else {
      return _buildGenericViewer();
    }
  }

  Widget _buildVideoViewer() {
    if (_hasBunnyStreamVideo) {
      final bunnyPlayerUrl =
          'https://iframe.mediadelivery.net/embed/${widget.lesson.bunnyLibraryId}/${widget.lesson.bunnyVideoId}';
      return Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.width * 9 / 16,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isBunnyLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
                ),
              ),
            if (_videoError != null)
              Container(
                color: Colors.black,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: Text(
                  _videoError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            AnimatedOpacity(
              opacity: _isBunnyLoading || _videoError != null ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(bunnyPlayerUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: true,
                  allowsInlineMediaPlayback: true,
                  iframeAllowFullscreen: true,
                  transparentBackground: true,
                ),
                onLoadStop: (controller, url) {
                  if (mounted) {
                    setState(() {
                      _isBunnyLoading = false;
                      _bunnyHasLoaded = true;
                      _videoError = null;
                    });
                  }
                },
                onReceivedError: (controller, request, error) {
                  if (mounted &&
                      request.isForMainFrame == true &&
                      !_bunnyHasLoaded) {
                    setState(() {
                      _isBunnyLoading = false;
                      _videoError = 'Unable to load Bunny video: ${error.description}';
                    });
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  if (mounted &&
                      request.isForMainFrame == true &&
                      !_bunnyHasLoaded &&
                      errorResponse.statusCode != null &&
                      errorResponse.statusCode! >= 400) {
                    setState(() {
                      _isBunnyLoading = false;
                      _videoError = 'Bunny video returned HTTP ${errorResponse.statusCode}.';
                    });
                  }
                },
                onEnterFullscreen: (controller) async {
                  await SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                },
                onExitFullscreen: (controller) async {
                  await SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ]);
                  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                },
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.width * 9 / 16,
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _isVideoLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
              ),
            )
          : _videoError != null
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, Colors.grey[900]!],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Display Error Detected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This device cannot securely play this video in the app. Please try again or use a supported device. The video cannot be opened in an external player.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _initializeVideo,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5a189a),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _isVideoInitialized && _videoController != null
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 15),
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video Player with Aspect Ratio
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                    // Controls Overlay with better gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    // Bottom Controls
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Progress Bar
                            VideoProgressIndicator(
                              _videoController!,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: Color(0xFF5a189a),
                                bufferedColor: Colors.white70,
                                backgroundColor: Colors.white30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Time Display
                            if (_videoController != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: StreamBuilder<Duration>(
                                  stream: Stream.periodic(
                                    const Duration(seconds: 1),
                                    (_) => _videoController!.value.position,
                                  ),
                                  builder: (context, snapshot) {
                                    final position =
                                        snapshot.data ?? Duration.zero;
                                    final duration =
                                        _videoController!.value.duration;
                                    return Text(
                                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            // Control Buttons
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width:
                                    MediaQuery.of(context).size.width -
                                    16, // Screen width minus horizontal padding
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Play/Pause Button
                                    IconButton(
                                      icon: Icon(
                                        _isVideoPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      onPressed: _toggleVideoPlayPause,
                                      tooltip: _isVideoPlaying
                                          ? 'Pause'
                                          : 'Play',
                                    ),
                                    // Playback Speed Button
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _showPlaybackSpeedDialog,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.speed,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_playbackSpeed}x',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Quality Button
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _showQualityDialog,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.high_quality,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Fullscreen Button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      onPressed: _enterFullScreen,
                                      tooltip: 'Fullscreen',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, Colors.grey[900]!],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
                ),
              ),
            ),
    );
  }

  Widget _buildPdfViewer() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 500,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red[50]!, Colors.red[100]!],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 80,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'PDF Document',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap the button below to view the PDF',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.rightToLeft,
                  child: PdfViewerScreen(
                    pdfUrl: widget.lesson.contentUrl!,
                    title: widget.lesson.title,
                    isFree: widget.lesson.isFree,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('View PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
          if (widget.lesson.isFree) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _openFileExternally(widget.lesson.contentUrl!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open in External App'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExcelViewer() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 450,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[50]!, Colors.green[100]!],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.table_chart_rounded,
              size: 80,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Excel Document',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap the button below to view the Excel file',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _openFileExternally(widget.lesson.contentUrl!),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(
          ApiConfig.getImageUrl(widget.lesson.contentUrl!),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 400,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[200]!, Colors.grey[300]!],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_rounded,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextViewer() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child:
          widget.lesson.description != null &&
              widget.lesson.description!.isNotEmpty
          ? Text(
              widget.lesson.description!,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4A4A4A),
                height: 1.8,
              ),
            )
          : const Text(
              'No text content available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
    );
  }

  Widget _buildGenericViewer() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 350,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[100]!, Colors.grey[200]!],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insert_drive_file_rounded,
              size: 64,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'File Content',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${widget.lesson.type}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openFileExternally(widget.lesson.contentUrl!),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5a189a),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContentViewer() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[100]!, Colors.grey[200]!],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getTypeIcon(widget.lesson.type),
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No content available',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildModernMetaCard({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    final typeLower = type.toLowerCase();
    if (typeLower == 'video') return Icons.videocam_rounded;
    if (typeLower == 'pdf') return Icons.picture_as_pdf_rounded;
    if (typeLower == 'excel' || typeLower == 'xlsx' || typeLower == 'xls')
      return Icons.table_chart_rounded;
    if (typeLower == 'image' || typeLower == 'img') return Icons.image_rounded;
    if (typeLower == 'text') return Icons.text_fields_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getTypeColor(String type) {
    final typeLower = type.toLowerCase();
    if (typeLower == 'video') return Colors.red;
    if (typeLower == 'pdf') return Colors.red;
    if (typeLower == 'excel' || typeLower == 'xlsx' || typeLower == 'xls')
      return Colors.green;
    if (typeLower == 'image' || typeLower == 'img') return Colors.blue;
    if (typeLower == 'text') return Colors.orange;
    return Colors.grey;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}

// Fullscreen Video Player Widget
class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final Lesson lesson;
  final VoidCallback onExit;

  const _FullScreenVideoPlayer({
    required this.controller,
    required this.lesson,
    required this.onExit,
  });

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  bool _showControls = true;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    _playbackSpeed = widget.controller.value.playbackSpeed;
    widget.controller.addListener(_videoListener);
    _hideControlsAfterDelay();
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.controller.value.isPlaying;
      });
    }
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _hideControlsAfterDelay();
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
      _showControls = true;
    });
    _hideControlsAfterDelay();
  }

  void _changePlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      widget.controller.setPlaybackSpeed(speed);
      _showControls = true;
    });
    _hideControlsAfterDelay();
  }

  void _showPlaybackSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Playback Speed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
              final isSelected = _playbackSpeed == speed;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected
                      ? const Color(0xFF5a189a)
                      : Colors.grey[400],
                ),
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[300],
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  _changePlaybackSpeed(speed);
                  Navigator.pop(context);
                },
              );
            })),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video Player
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),

            // Controls Overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Stack(
                  children: [
                    // Top Bar - Title and Exit
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.lesson.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen_exit_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onExit();
                                },
                                tooltip: 'Exit Fullscreen',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Center - Play/Pause Button
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 72,
                          ),
                        ),
                      ),
                    ),

                    // Bottom Bar - Progress and Controls
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress Indicator
                              VideoProgressIndicator(
                                widget.controller,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Color(0xFF5a189a),
                                  bufferedColor: Colors.white70,
                                  backgroundColor: Colors.white30,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Control Buttons
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width -
                                      16, // screen width minus horizontal padding
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Play/Pause
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            _isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                          onPressed: _togglePlayPause,
                                        ),
                                      ),
                                      // Playback Speed Button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _showPlaybackSpeedDialog,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.speed,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${_playbackSpeed}x',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Quality Button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            showModalBottomSheet(
                                              context: context,
                                              backgroundColor:
                                                  Colors.transparent,
                                              isScrollControlled: true,
                                              builder: (context) => Container(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      MediaQuery.of(
                                                        context,
                                                      ).size.height *
                                                      0.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[900],
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(
                                                          20,
                                                        ),
                                                      ),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 40,
                                                      height: 4,
                                                      margin:
                                                          const EdgeInsets.only(
                                                            top: 12,
                                                            bottom: 20,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[600],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              2,
                                                            ),
                                                      ),
                                                    ),
                                                    const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 20,
                                                          ),
                                                      child: Text(
                                                        'Video Quality',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Flexible(
                                                      child: ListView(
                                                        shrinkWrap: true,
                                                        physics:
                                                            const ClampingScrollPhysics(),
                                                        children: [
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons
                                                                  .high_quality,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            title: const Text(
                                                              'Auto',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                            subtitle: const Text(
                                                              'Best quality available',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            onTap: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Auto quality selected (Default)',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .blue,
                                                                  duration:
                                                                      Duration(
                                                                        seconds:
                                                                            2,
                                                                      ),
                                                                ),
                                                              );
                                                            },
                                                          ),

                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons.hd,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            title: const Text(
                                                              '1080p FHD',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                            subtitle: const Text(
                                                              'Full High definition',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            onTap: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    '1080p FHD selected (Requires Bunny Stream)',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .blue,
                                                                  duration:
                                                                      Duration(
                                                                        seconds:
                                                                            2,
                                                                      ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons.hd,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            title: const Text(
                                                              '720p HD',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                            subtitle: const Text(
                                                              'High definition',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            onTap: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    '720p HD selected (Requires Bunny Stream)',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .blue,
                                                                  duration:
                                                                      Duration(
                                                                        seconds:
                                                                            2,
                                                                      ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons.sd,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            title: const Text(
                                                              '480p SD',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                            subtitle: const Text(
                                                              'Standard definition',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            onTap: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    '480p SD selected (Requires Bunny Stream)',
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .blue,
                                                                  duration:
                                                                      Duration(
                                                                        seconds:
                                                                            2,
                                                                      ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: MediaQuery.of(
                                                        context,
                                                      ).padding.bottom,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.high_quality,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Time Display
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: StreamBuilder<Duration>(
                                          stream: Stream.periodic(
                                            const Duration(seconds: 1),
                                            (_) => widget
                                                .controller
                                                .value
                                                .position,
                                          ),
                                          builder: (context, snapshot) {
                                            final position =
                                                snapshot.data ?? Duration.zero;
                                            final duration = widget
                                                .controller
                                                .value
                                                .duration;
                                            return Text(
                                              '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      // Exit Fullscreen
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.fullscreen_exit_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            widget.onExit();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
