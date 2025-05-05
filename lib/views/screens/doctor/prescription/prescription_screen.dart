import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:healthcare/utils/app_theme.dart';

// Platform imports
import 'dart:io' show Platform;

class PrescriptionScreen extends StatefulWidget {
  final String appointmentId;
  final String patientName;
  final String? existingPrescription;
  final List<String>? existingPrescriptionImages;
  final List<String>? existingVoiceNotes;

  const PrescriptionScreen({
    Key? key,
    required this.appointmentId,
    required this.patientName,
    this.existingPrescription,
    this.existingPrescriptionImages,
    this.existingVoiceNotes,
  }) : super(key: key);

  @override
  _PrescriptionScreenState createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final TextEditingController _prescriptionController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _existingImageUrls = [];
  final List<String> _existingVoiceNoteUrls = [];
  final List<File> _recordedVoiceNotes = [];
  bool _isLoading = false;
  bool _isSpeechRecognitionActive = false;
  
  // Speech to text method channel
  static const platform = MethodChannel('speech_to_text_channel');
  
  // Voice recording related variables
  final _audioRecorder = AudioRecorder();
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  int _playingIndex = -1;
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  
  // Timer for recording duration
  DateTime? _recordingStartTime;

  // Firebase instance
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    
    // Initialize with existing prescription text if available
    if (widget.existingPrescription != null) {
      _prescriptionController.text = widget.existingPrescription!;
    }
    
    // Initialize with existing prescription image URLs if available
    if (widget.existingPrescriptionImages != null) {
      _existingImageUrls.addAll(widget.existingPrescriptionImages!);
    }
    
    // Initialize with existing voice note URLs if available
    if (widget.existingVoiceNotes != null) {
      // Ensure all URLs are valid
      for (final url in widget.existingVoiceNotes!) {
        if (url.startsWith('http://') || url.startsWith('https://')) {
          _existingVoiceNoteUrls.add(url);
        } else {
          print('Warning: Skipping invalid voice note URL: $url');
        }
      }
    }
    
    // Initialize audio player
    _initializeAudioPlayer();
  }

  // Start speech to text recognition
  Future<void> _startSpeechToText() async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speech to text is currently only supported on Android'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Request microphone permission if not already granted
    PermissionStatus status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Microphone permission is required for speech recognition'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    setState(() {
      _isSpeechRecognitionActive = true;
    });
    
    try {
      final String result = await platform.invokeMethod('startSpeechRecognition');
      if (result.isNotEmpty) {
        setState(() {
          // If there's existing text, add a space before adding new text
          if (_prescriptionController.text.isNotEmpty && 
              !_prescriptionController.text.endsWith(' ')) {
            _prescriptionController.text += ' ';
          }
          _prescriptionController.text += result;
          
          // Set cursor at the end of text
          _prescriptionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _prescriptionController.text.length),
          );
        });
      }
    } on PlatformException catch (e) {
      print("Failed to get speech recognition: '${e.message}'");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Speech recognition failed: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSpeechRecognitionActive = false;
      });
    }
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
    _prescriptionController.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // Method to pick images from gallery
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }
  
  // Method to take photos with camera
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }
  
  // Method to save prescription
  Future<void> _savePrescription() async {
    if (_prescriptionController.text.trim().isEmpty && 
        _selectedImages.isEmpty && 
        _existingImageUrls.isEmpty && 
        _recordedVoiceNotes.isEmpty && 
        _existingVoiceNoteUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a prescription, add images, or record voice notes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String doctorId = FirebaseAuth.instance.currentUser!.uid;
      final List<String> imageUrls = List.from(_existingImageUrls);
      final List<String> voiceNoteUrls = List.from(_existingVoiceNoteUrls);
      
      // Upload new images to Firebase Storage
      if (_selectedImages.isNotEmpty) {
        for (File image in _selectedImages) {
          final Reference ref = FirebaseStorage.instance
              .ref()
              .child('prescriptions')
              .child(widget.appointmentId)
              .child('images')
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
          
          await ref.putFile(image);
          final String downloadUrl = await ref.getDownloadURL();
          imageUrls.add(downloadUrl);
        }
      }
      
      // Upload voice notes to Firebase Storage
      if (_recordedVoiceNotes.isNotEmpty) {
        for (File voiceNote in _recordedVoiceNotes) {
          final Reference ref = FirebaseStorage.instance
              .ref()
              .child('prescriptions')
              .child(widget.appointmentId)
              .child('voice_notes')
              .child('${DateTime.now().millisecondsSinceEpoch}.m4a');
          
          await ref.putFile(voiceNote);
          final String downloadUrl = await ref.getDownloadURL();
          voiceNoteUrls.add(downloadUrl);
        }
      }
      
      // Update appointment document in Firestore
      await _firestore.collection('appointments').doc(widget.appointmentId).update({
        'prescription': _prescriptionController.text,
        'prescriptionImages': imageUrls,
        'voiceNotes': voiceNoteUrls,
        'prescriptionUpdatedAt': firestore.FieldValue.serverTimestamp(),
        'prescribedBy': doctorId,
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print('Error saving prescription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving prescription: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Start recording voice note
  Future<void> _startRecording() async {
    // Check if microphone permission is granted
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Microphone permission is required to record voice notes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      
      // Use .m4a format instead of .aac for better compatibility
      final filePath = '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      // Start recording with more compatible settings
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 2,
        ), 
        path: filePath,
      );
      
      setState(() {
        _isRecording = true;
        _currentRecordingPath = filePath;
        _recordingStartTime = DateTime.now();
      });
      
      // Start a timer to update recording duration
      _updateRecordingDuration();
      
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Update recording duration every second
  void _updateRecordingDuration() {
    if (!_isRecording || _recordingStartTime == null) return;
    
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _isRecording) {
        setState(() {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        });
        _updateRecordingDuration(); // Continue updating
      }
    });
  }
  
  // Stop recording voice note
  Future<void> _stopRecording() async {
    try {
      if (!_isRecording) return;
      
      // Stop recording
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _recordingStartTime = null;
      });
      
      if (path != null) {
        // Create file object
        File recordedFile = File(path);
        
        // Verify file exists and has content
        if (await recordedFile.exists()) {
          int fileSize = await recordedFile.length();
          if (fileSize > 0) {
            print('Recorded file saved: $path (Size: $fileSize bytes)');
            setState(() {
              _recordedVoiceNotes.add(recordedFile);
            });
          } else {
            print('Warning: Recorded file exists but is empty: $path');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Recording failed: File is empty'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          print('Warning: Recorded file does not exist: $path');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recording failed: File not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('Error: No path returned from recorder.stop()');
      }
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Play voice note
  Future<void> _playVoiceNote(String source, bool isUrl, int index) async {
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
      // Set playback source based on whether it's a URL or file
      Source audioSource = isUrl 
          ? UrlSource(source)
          : DeviceFileSource(source);
          
      // Start playback with the appropriate source
      await _audioPlayer.play(audioSource);
      
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
  
  // Delete recorded voice note
  void _deleteRecordedVoiceNote(int index) {
    if (_isPlaying && _playingIndex == index) {
      _stopPlaying();
    }
    
    setState(() {
      _recordedVoiceNotes.removeAt(index);
    });
  }
  
  // Delete existing voice note
  void _deleteExistingVoiceNote(int index) {
    if (_isPlaying && _playingIndex == index) {
      _stopPlaying();
    }
    
    setState(() {
      _existingVoiceNoteUrls.removeAt(index);
    });
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
    final Size screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Write Prescription',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            Center(
              child: Container(
                margin: EdgeInsets.only(right: 16),
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(LucideIcons.check),
              onPressed: _savePrescription,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Saving prescription...',
                    style: GoogleFonts.poppins(
                      color: AppTheme.primaryTeal,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient info card with gradient
                  Container(
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Prescription text input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Prescription Details',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                      ),
                      if (Platform.isAndroid)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isSpeechRecognitionActive 
                                ? AppTheme.primaryTeal.withOpacity(0.2) 
                                : AppTheme.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _isSpeechRecognitionActive 
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryTeal.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    )
                                  ] 
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _isSpeechRecognitionActive ? null : _startSpeechToText,
                              child: Tooltip(
                                message: 'Speech to text - Tap to dictate prescription',
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (_isSpeechRecognitionActive) ...[
                                      // Pulsating circle animation
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.primaryTeal.withOpacity(0.5),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Icon(
                                      _isSpeechRecognitionActive 
                                          ? Icons.mic : LucideIcons.mic,
                                      color: AppTheme.primaryTeal,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        TextField(
                          controller: _prescriptionController,
                          maxLines: 8,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: AppTheme.darkText,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter medication details, dosage, and instructions...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppTheme.primaryTeal,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.all(20),
                          ),
                        ),
                        if (_isSpeechRecognitionActive)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Listening...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Please speak clearly',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Prescription images section
                  Text(
                    'Attach Images',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkText,
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // Image upload buttons with improved design
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _takePhoto,
                          icon: Icon(LucideIcons.camera),
                          label: Text(
                            'Take Photo',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: Icon(LucideIcons.image),
                          label: Text(
                            'Gallery',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Display existing images with improved layout
                  if (_existingImageUrls.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Existing Images',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        Text(
                          '${_existingImageUrls.length} images',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.mediumText,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingImageUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 120,
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _existingImageUrls[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _existingImageUrls.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                  
                  // Display newly selected images
                  if (_selectedImages.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Images',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          '${_selectedImages.length} images',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 120,
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImages[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  SizedBox(height: 20),
                  
                  // Voice Notes Section
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                LucideIcons.mic,
                                color: AppTheme.primaryTeal,
                                size: 18,
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
                          ],
                        ),
                        if (_isRecording)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.red,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _formatDuration(_recordingDuration),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
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
                  
                  // Voice recording button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _isRecording ? AppTheme.error.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isRecording 
                            ? AppTheme.error.withOpacity(0.3)
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _isRecording
                                        ? [AppTheme.error.withOpacity(0.8), AppTheme.error]
                                        : [AppTheme.primaryTeal, AppTheme.primaryTeal],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _isRecording
                                          ? AppTheme.error.withOpacity(0.3)
                                          : AppTheme.primaryTeal.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (_isRecording)
                                      ...[
                                        // Outer pulsating circle
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.6),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        // Progress indicator
                                        SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: CircularProgressIndicator(
                                            color: Colors.white.withOpacity(0.5),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ],
                                    Icon(
                                      _isRecording ? LucideIcons.square : LucideIcons.mic,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isRecording ? 'Recording in progress' : 'Record a voice note',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: _isRecording ? Colors.red : Color(0xFF2C3E50),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _isRecording 
                                          ? 'Tap to stop • ${_formatDuration(_recordingDuration)}'
                                          : 'Tap to start recording a prescription voice note',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: _isRecording ? Colors.red.shade700 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isRecording)
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Display existing voice notes
                  if (_existingVoiceNoteUrls.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: Colors.grey.shade200,
                        thickness: 1,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Existing Voice Notes',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF3366CC).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_existingVoiceNoteUrls.length} notes',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3366CC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _existingVoiceNoteUrls.length,
                      itemBuilder: (context, index) {
                        final url = _existingVoiceNoteUrls[index];
                        final bool isPlayingThis = _isPlaying && _playingIndex == index;
                        final bool isValidUrl = url.startsWith('http://') || url.startsWith('https://');
                        
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
                                  : isValidUrl ? Colors.grey.shade200 : Colors.red.shade200,
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
                                          colors: isValidUrl
                                              ? (isPlayingThis 
                                                  ? [Colors.green.shade400, Colors.green.shade600]
                                                  : [Color(0xFF3366CC), Color(0xFF5E8EF7)])
                                              : [Colors.red.shade300, Colors.red.shade400],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isValidUrl
                                                ? (isPlayingThis 
                                                    ? Colors.green.withOpacity(0.3)
                                                    : Color(0xFF3366CC).withOpacity(0.2))
                                                : Colors.red.withOpacity(0.2),
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
                                          onTap: isValidUrl 
                                              ? () {
                                                  if (isPlayingThis) {
                                                    _pauseAudio();
                                                  } else {
                                                    _playVoiceNote(url, true, index);
                                                  }
                                                }
                                              : () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Invalid URL format. Cannot play this voice note.'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                },
                                          child: Center(
                                            child: Icon(
                                              isValidUrl
                                                  ? (isPlayingThis ? LucideIcons.pause : LucideIcons.play)
                                                  : Icons.error_outline,
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
                                                isValidUrl
                                                    ? LucideIcons.music
                                                    : Icons.warning_amber_rounded,
                                                size: 14,
                                                color: isValidUrl ? Colors.grey.shade600 : Colors.red,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                isValidUrl
                                                    ? (isPlayingThis 
                                                       ? '${_formatDuration(_playbackPosition)} / ${_formatDuration(_playbackDuration)}' 
                                                       : 'Tap to play')
                                                    : 'Invalid URL format',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: isValidUrl ? Colors.grey.shade600 : Colors.red,
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
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          LucideIcons.trash2,
                                          color: Colors.red.shade400,
                                          size: 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _deleteExistingVoiceNote(index),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isPlayingThis && _playbackDuration.inMilliseconds > 0) ...[
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
                    SizedBox(height: 20),
                  ],
                  
                  // Display newly recorded voice notes
                  if (_recordedVoiceNotes.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: Colors.grey.shade200,
                        thickness: 1,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Voice Notes',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_recordedVoiceNotes.length} notes',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _recordedVoiceNotes.length,
                      itemBuilder: (context, index) {
                        final int actualIndex = index + _existingVoiceNoteUrls.length;
                        final bool isPlayingThis = _playingIndex == actualIndex && _isPlaying;
                        
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
                              color: _playingIndex == actualIndex && _isPlaying 
                                  ? Theme.of(context).primaryColor.withOpacity(0.5)
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
                                  children: [
                                    // Play/Pause button with gradient
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: _playingIndex == actualIndex && _isPlaying
                                              ? [Colors.green.shade400, Colors.green.shade600]
                                              : [Color(0xFF3366CC), Color(0xFF5E8EF7)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _playingIndex == actualIndex && _isPlaying
                                                ? Colors.green.withOpacity(0.3)
                                                : Color(0xFF3366CC).withOpacity(0.2),
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
                                            if (_playingIndex == actualIndex && _isPlaying) {
                                              _pauseAudio();
                                            } else if (_playingIndex == actualIndex && !_isPlaying) {
                                              _resumeAudio();
                                            } else {
                                              _playVoiceNote(_recordedVoiceNotes[index].path, false, actualIndex);
                                            }
                                          },
                                          child: Center(
                                            child: Icon(
                                              _playingIndex == actualIndex && _isPlaying 
                                                ? LucideIcons.pause 
                                                : LucideIcons.play,
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
                                            'Voice Note ${actualIndex + 1}',
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
                                                _playingIndex == actualIndex && _isPlaying
                                                  ? '${_formatDuration(_playbackPosition)} / ${_formatDuration(_playbackDuration)}'
                                                  : 'Tap to play',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              if (_playingIndex == actualIndex && _isPlaying) ...[
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
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          LucideIcons.trash2,
                                          color: Colors.red.shade400,
                                          size: 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _deleteRecordedVoiceNote(index),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: _getPlaybackProgress(actualIndex),
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _playingIndex == actualIndex && _isPlaying 
                                        ? Colors.green 
                                        : Theme.of(context).primaryColor
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  SizedBox(height: 24),
                  
                  // Save button with gradient
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppTheme.primaryTeal,
                          AppTheme.primaryTeal,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryTeal.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePrescription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.stethoscope, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Save Prescription',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
} 