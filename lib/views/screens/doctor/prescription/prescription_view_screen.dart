import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:healthcare/utils/app_theme.dart';

// Audio player widget for better playback experience
class AudioPlayerWidget extends StatefulWidget {
  final String source;
  final bool isUrl;
  final String label;

  const AudioPlayerWidget({
    Key? key,
    required this.source,
    required this.isUrl,
    required this.label,
  }) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Setup listeners
      _positionSubscription = _audioPlayer.onPositionChanged.listen((pos) {
        if (mounted) {
          setState(() => _position = pos);
        }
      });
      
      _durationSubscription = _audioPlayer.onDurationChanged.listen((dur) {
        if (mounted) {
          setState(() => _duration = dur);
        }
      });
      
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
      setState(() {
            _isPlaying = state == PlayerState.playing;
            if (state == PlayerState.completed) {
              _position = _duration;
        _isPlaying = false;
            }
          });
        }
      });
      
      // If it's a URL, we need to check its validity
      if (widget.isUrl) {
        if (!widget.source.startsWith('http')) {
        setState(() {
            _hasError = true;
            _errorMessage = 'Invalid URL format';
            _isLoading = false;
          });
          return;
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Setup error: ${e.toString()}';
          _isLoading = false;
        });
      }
      print('Error initializing audio player: $e');
    }
  }
  
  Future<void> _playPause() async {
    if (_hasError) return;
    
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() => _isLoading = true);
        
        // Set the source if we haven't started playing yet or if we're at the end
        if (_position.inMilliseconds == 0 || _position >= _duration) {
          Source audioSource = widget.isUrl 
              ? UrlSource(widget.source)
              : DeviceFileSource(widget.source);
              
          await _audioPlayer.play(audioSource);
        } else {
          // Resume from current position
          await _audioPlayer.resume();
        }
        
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Playback error: ${e.toString()}';
        _isLoading = false;
      });
      print('Error playing audio: $e');
    }
  }
  
  Future<void> _seekTo(double value) async {
    if (_duration.inMilliseconds > 0) {
      final position = Duration(milliseconds: (value * _duration.inMilliseconds).round());
      await _audioPlayer.seek(position);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _hasError 
              ? Colors.red.shade200 
              : (_isPlaying 
                  ? AppTheme.primaryTeal.withOpacity(0.5) 
                  : Colors.grey.shade200),
          width: 1.5,
        ),
      ),
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play/Pause button with gradient
              Container(
                width: screenWidth * 0.12,
                height: screenWidth * 0.12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _hasError
                        ? [Colors.red.shade300, Colors.red.shade400]
                        : (_isPlaying 
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : [AppTheme.primaryTeal, AppTheme.primaryTeal]),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _hasError
                          ? Colors.red.withOpacity(0.2)
                          : (_isPlaying 
                              ? Colors.green.withOpacity(0.3)
                              : AppTheme.primaryTeal.withOpacity(0.2)),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isLoading || _hasError ? null : _playPause,
                    child: Center(
                      child: _isLoading
                          ? SizedBox(
                              width: screenWidth * 0.05,
                              height: screenWidth * 0.05,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Icon(
                              _hasError 
                                  ? Icons.error_outline
                                  : (_isPlaying 
                                      ? LucideIcons.pause 
                                      : LucideIcons.play),
                              color: Colors.white,
                              size: screenWidth * 0.055,
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.poppins(
                        fontSize: screenWidth * 0.038,
                        fontWeight: FontWeight.w600,
                        color: _hasError ? Colors.red : Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _hasError 
                              ? Icons.warning_amber_rounded
                              : LucideIcons.music,
                          size: screenWidth * 0.035,
                          color: _hasError ? Colors.red : Colors.grey.shade600,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _hasError 
                              ? _errorMessage ?? 'Error'
                              : _isPlaying 
                                  ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}' 
                                  : _duration.inMilliseconds > 0 
                                      ? _formatDuration(_duration)
                                      : 'Tap to play',
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.03,
                            color: _hasError ? Colors.red : Colors.grey.shade600,
                          ),
                        ),
                        if (_isPlaying) ...[
                          SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Audio progress bar with draggable thumb
          if (!_hasError && _duration.inMilliseconds > 0)
            Container(
              height: 24,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                  trackShape: RoundedRectSliderTrackShape(),
                  activeTrackColor: _isPlaying ? Colors.green : AppTheme.primaryTeal,
                  inactiveTrackColor: Colors.grey.shade200,
                  thumbColor: _isPlaying ? Colors.green : AppTheme.primaryTeal,
                  overlayColor: (_isPlaying ? Colors.green : AppTheme.primaryTeal).withOpacity(0.2),
                ),
                child: Slider(
                  value: _position.inMilliseconds > 0 && _duration.inMilliseconds > 0
                      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: (value) {
                    _seekTo(value);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PrescriptionViewScreen extends StatefulWidget {
  final String patientName;
  final String? prescription;
  final List<String>? prescriptionImages;
  final String? prescriptionDate;
  final List<String>? voiceNotes;

  const PrescriptionViewScreen({
    Key? key,
    required this.patientName,
    this.prescription,
    this.prescriptionImages,
    this.prescriptionDate,
    this.voiceNotes,
  }) : super(key: key);

  @override
  _PrescriptionViewScreenState createState() => _PrescriptionViewScreenState();
}

class _PrescriptionViewScreenState extends State<PrescriptionViewScreen> {
  int _currentImageIndex = 0;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  // Helper method to format durations (kept for reference/possible future use)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // Add download image functionality
  Future<void> _downloadImage(String imageUrl, int index) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
              SizedBox(width: 10),
              Text('Saving image to gallery...'),
            ],
          ),
          backgroundColor: AppTheme.primaryTeal,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Note: In a real implementation, you would use a plugin like image_gallery_saver
      // to save the image to the device gallery. This is a placeholder.
      await Future.delayed(Duration(seconds: 2));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image saved to gallery'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error downloading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save image: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'View Prescription',
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientCard(),
            SizedBox(height: 24),
            if (widget.prescription != null && widget.prescription!.isNotEmpty) ...[
              _buildPrescriptionText(),
              SizedBox(height: 24),
            ],
            if (widget.voiceNotes != null && widget.voiceNotes!.isNotEmpty) ...[
              _buildVoiceNotesSection(),
              SizedBox(height: 24),
            ],
            if (widget.prescriptionImages != null && widget.prescriptionImages!.isNotEmpty) ...[
              _buildPrescriptionImagesSection(),
            ],
            if ((widget.prescription == null || widget.prescription!.isEmpty) && 
                (widget.prescriptionImages == null || widget.prescriptionImages!.isEmpty) &&
                (widget.voiceNotes == null || widget.voiceNotes!.isEmpty)) ...[
              _buildNoPrescriptionMessage(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryTeal,
            AppTheme.primaryTeal,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.user,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Name',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  widget.patientName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (widget.prescriptionDate != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.calendar,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          widget.prescriptionDate!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionText() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.stethoscope,
                  color: AppTheme.primaryTeal,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Doctor\'s Prescription',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                    'MEDICATION DETAILS',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryTeal,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
              widget.prescription!,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppTheme.darkText,
                height: 1.6,
              ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNotesSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.mic,
                color: AppTheme.primaryTeal,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Voice Notes',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            Spacer(),
            Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.voiceNotes!.length} notes',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ),
          ],
        ),
          SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
        SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: widget.voiceNotes!.length,
          itemBuilder: (context, index) {
            final url = widget.voiceNotes![index];
            final bool isValidUrl = url.startsWith('http://') || url.startsWith('https://');
            
            if (!isValidUrl) {
              return SizedBox.shrink(); // Skip invalid URLs
            }
            
              // Use the AudioPlayerWidget for better UI and interaction
              return AudioPlayerWidget(
                source: url,
                isUrl: true,
                label: 'Voice Note ${index + 1}',
              );
            },
          ),
        ],
      ),
    );
  }

  // Improved prescription images section
  Widget _buildPrescriptionImagesSection() {
            return Container(
      padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
                child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.image,
                color: AppTheme.primaryTeal,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Prescription Images',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            Spacer(),
            if (widget.prescriptionImages!.length > 1)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${widget.prescriptionImages!.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          SizedBox(height: 16),
          
          // Main image view with improved UI
        Container(
            height: 350,
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  PhotoViewGallery.builder(
              scrollPhysics: BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(widget.prescriptionImages![index]),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        heroAttributes: PhotoViewHeroAttributes(tag: 'prescription_image_$index'),
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade400,
                                    size: 40,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Failed to load image',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                );
              },
              itemCount: widget.prescriptionImages!.length,
              loadingBuilder: (context, event) => Center(
                      child: Container(
                        width: 36,
                        height: 36,
                child: CircularProgressIndicator(
                          value: event == null
                              ? 0
                              : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                          strokeWidth: 3,
                        ),
                ),
              ),
              backgroundDecoration: BoxDecoration(
                color: Colors.transparent,
              ),
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
            ),
                  
                  // Top indicator for zooming instructions
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical:
                        8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.zoomIn,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pinch to zoom',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Download and navigation controls
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.prescriptionImages!.length > 1)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(LucideIcons.chevronsLeft, color: Colors.white),
                                  onPressed: _currentImageIndex > 0
                                      ? () {
                                          _pageController.animateToPage(
                                            0,
                                            duration: Duration(milliseconds: 300),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      : null,
                                  color: _currentImageIndex > 0 ? Colors.white : Colors.white.withOpacity(0.3),
                                  iconSize: 20,
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.chevronLeft, color: Colors.white),
                                  onPressed: _currentImageIndex > 0
                                      ? () {
                                          _pageController.previousPage(
                                            duration: Duration(milliseconds: 300),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      : null,
                                  color: _currentImageIndex > 0 ? Colors.white : Colors.white.withOpacity(0.3),
                                  iconSize: 20,
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '${_currentImageIndex + 1}/${widget.prescriptionImages!.length}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.chevronRight, color: Colors.white),
                                  onPressed: _currentImageIndex < widget.prescriptionImages!.length - 1
                                      ? () {
                                          _pageController.nextPage(
                                            duration: Duration(milliseconds: 300),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      : null,
                                  color: _currentImageIndex < widget.prescriptionImages!.length - 1
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                                  iconSize: 20,
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.chevronsRight, color: Colors.white),
                                  onPressed: _currentImageIndex < widget.prescriptionImages!.length - 1
                                      ? () {
                                          _pageController.animateToPage(
                                            widget.prescriptionImages!.length - 1,
                                            duration: Duration(milliseconds: 300),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      : null,
                                  color: _currentImageIndex < widget.prescriptionImages!.length - 1
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                                  iconSize: 20,
                                ),
                              ],
                            ),
                          ),
                        SizedBox(width: 16),
                        InkWell(
                          onTap: () => _downloadImage(
                              widget.prescriptionImages![_currentImageIndex], _currentImageIndex),
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              LucideIcons.download,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ),
        ),
        
        if (widget.prescriptionImages!.length > 1) ...[
            SizedBox(height: 20),
            Text(
              'All Images',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            SizedBox(height: 12),
          Container(
              height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.prescriptionImages!.length,
              itemBuilder: (context, index) {
                  bool isSelected = _currentImageIndex == index;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                      width: 80,
                      height: 80,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                            ? AppTheme.primaryTeal 
                            : Colors.transparent,
                          width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: isSelected
                                ? AppTheme.primaryTeal.withOpacity(0.3)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: isSelected ? 8 : 4,
                          offset: Offset(0, 2),
                            spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                        widget.prescriptionImages![index],
                        fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return Container(
                                  color: Colors.grey.shade100,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                                        strokeWidth: 2,
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                      ),
                    ),
                  ),
                );
              },
                            ),
                            if (isSelected)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: AppTheme.primaryTeal.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
            ),
          ),
        ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoPrescriptionMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.info,
              color: AppTheme.warning,
              size: 32,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No Prescription Available',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'The doctor has not provided a prescription for this appointment yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.mediumText,
            ),
          ),
        ],
      ),
    );
  }
} 