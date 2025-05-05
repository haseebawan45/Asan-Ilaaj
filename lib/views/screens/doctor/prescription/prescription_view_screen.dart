import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:healthcare/utils/app_theme.dart';

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
  
  // Audio playback related variables
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _playingIndex = -1;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initializeAudioPlayer();
  }
  
  void _initializeAudioPlayer() {
    _audioPlayer = AudioPlayer();
    
    // Setup duration listener
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _playbackDuration = duration;
      });
    });
    
    // Setup position listener
    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _playbackPosition = position;
      });
    });
    
    // Setup completion listener
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _playingIndex = -1;
        _playbackPosition = Duration.zero;
      });
    });
    
    // Setup state change listener
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
          _playingIndex = -1;
          _playbackPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // Format duration as mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  double _getPlaybackProgress(int index) {
    if (_playingIndex != index || _playbackPosition.inMilliseconds == 0 || _playbackDuration.inMilliseconds == 0) {
      return 0.0;
    }
    return _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds;
  }
  
  // Play voice note
  Future<void> _playVoiceNote(String url, int index) async {
    if (_isPlaying && _playingIndex == index) {
      // Already playing this audio, pause it
      await _pauseAudio();
      return;
    }
    
    if (_isPlaying) {
      // Stop any currently playing audio
      await _stopPlaying();
    }
    
    try {
      await _audioPlayer.play(UrlSource(url));
      setState(() {
        _isPlaying = true;
        _playingIndex = index;
        _playbackPosition = Duration.zero;
      });
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play audio: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Pause playing voice note
  Future<void> _pauseAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }
  
  // Resume playing voice note
  Future<void> _resumeAudio() async {
    if (!_isPlaying && _playingIndex != -1) {
      await _audioPlayer.resume();
      setState(() {
        _isPlaying = true;
      });
    }
  }
  
  Future<void> _stopPlaying() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingIndex = -1;
        _playbackPosition = Duration.zero;
      });
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
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Text(
              widget.prescription!,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppTheme.darkText,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNotesSection() {
    return Column(
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
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: widget.voiceNotes!.length,
          itemBuilder: (context, index) {
            final url = widget.voiceNotes![index];
            final bool isPlayingThis = _isPlaying && _playingIndex == index;
            final bool isValidUrl = url.startsWith('http://') || url.startsWith('https://');
            
            if (!isValidUrl) {
              return SizedBox.shrink(); // Skip invalid URLs
            }
            
            return Container(
              margin: EdgeInsets.only(bottom: 12),
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
                  color: isPlayingThis 
                      ? Colors.green.withOpacity(0.5)
                      : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isPlayingThis
                                  ? [AppTheme.success.withOpacity(0.8), AppTheme.success]
                                  : [AppTheme.primaryTeal, AppTheme.primaryTeal],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: isPlayingThis
                                    ? AppTheme.success.withOpacity(0.3)
                                    : AppTheme.primaryTeal.withOpacity(0.2),
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
                              onTap: () {
                                if (isPlayingThis) {
                                  _pauseAudio();
                                } else if (_playingIndex == index && !_isPlaying) {
                                  _resumeAudio();
                                } else {
                                  _playVoiceNote(url, index);
                                }
                              },
                              child: Center(
                                child: Icon(
                                  isPlayingThis ? LucideIcons.pause : LucideIcons.play,
                                  color: Colors.white,
                                  size: 22,
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
                                'Voice Note ${index + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    LucideIcons.music,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isPlayingThis
                                      ? '${_formatDuration(_playbackPosition)} / ${_formatDuration(_playbackDuration)}'
                                      : 'Tap to play',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isPlayingThis) ...[
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
                    if (isPlayingThis) ...[
                      SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _getPlaybackProgress(index),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrescriptionImagesSection() {
    return Column(
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
        Container(
          height: 300,
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PhotoViewGallery.builder(
              scrollPhysics: BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(widget.prescriptionImages![index]),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  heroAttributes: PhotoViewHeroAttributes(tag: 'image$index'),
                );
              },
              itemCount: widget.prescriptionImages!.length,
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
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
          ),
        ),
        
        if (widget.prescriptionImages!.length > 1) ...[
          SizedBox(height: 16),
          Container(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.prescriptionImages!.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 70,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _currentImageIndex == index 
                            ? AppTheme.primaryTeal 
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        widget.prescriptionImages![index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
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