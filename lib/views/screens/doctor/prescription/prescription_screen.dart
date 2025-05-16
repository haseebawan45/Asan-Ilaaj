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

// Audio player widget for better playback experience
class AudioPlayerWidget extends StatefulWidget {
  final String source;
  final bool isUrl;
  final String label;
  final Function? onDelete;

  const AudioPlayerWidget({
    Key? key,
    required this.source,
    required this.isUrl,
    required this.label,
    this.onDelete,
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
      } else {
        // Check if file exists
        final file = File(widget.source);
        if (!(await file.exists())) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Audio file not found';
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
              if (widget.onDelete != null)
                Container(
                  width: screenWidth * 0.09,
                  height: screenWidth * 0.09,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      LucideIcons.trash2,
                      color: Colors.red.shade400,
                      size: screenWidth * 0.045,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _audioPlayer.stop();
                      widget.onDelete?.call();
                    },
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
                      ? _position.inMilliseconds / _duration.inMilliseconds
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
  bool _isRecording = false;
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;
  
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

  @override
  void dispose() {
    _prescriptionController.dispose();
    
    // Stop recording if needed, just in case
    try {
      if (_isRecording) {
        _audioRecorder.stop();
      }
    } catch (e) {
      print('Error stopping recorder during dispose: $e');
    }
    
    _audioRecorder.dispose();
    super.dispose();
  }

  // Method to pick images from gallery
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    
    // Enable multi-image selection
    final pickedFiles = await picker.pickMultiImage(
      imageQuality: 85,
    );
    
    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var pickedFile in pickedFiles) {
        _selectedImages.add(File(pickedFile.path));
        }
      });
      
      // Show success message for multiple images
      if (pickedFiles.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pickedFiles.length} images selected'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo captured'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  // View image fullscreen
  void _viewImage(String? url, bool isLocalFile, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: IconThemeData(color: Colors.white),
            title: Text(
              isLocalFile ? 'New Image ${index + 1}' : 'Image ${index + 1}',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            actions: [
              if (isLocalFile)
                IconButton(
                  icon: Icon(LucideIcons.trash2, color: Colors.red.shade400),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImages.removeAt(index);
                    });
                  },
                ),
              if (!isLocalFile)
                IconButton(
                  icon: Icon(LucideIcons.trash2, color: Colors.red.shade400),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _existingImageUrls.removeAt(index);
                    });
                  },
                ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: isLocalFile
                ? Image.file(
                    File(url!),
                    fit: BoxFit.contain,
                  )
                : Image.network(
                    url!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ),
      ),
    );
  }

  // Updated method to save prescription with reliable file upload processing
  Future<void> _savePrescription() async {
    // Validation check
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
    
    // Set loading state
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    
    try {
      final String doctorId = FirebaseAuth.instance.currentUser!.uid;
      
      // Create a local copy of existing URLs to avoid modification issues
      final List<String> imageUrls = List<String>.from(_existingImageUrls);
      final List<String> voiceNoteUrls = List<String>.from(_existingVoiceNoteUrls);
      
      // Process images one by one
      if (_selectedImages.isNotEmpty) {
        for (int i = 0; i < _selectedImages.length; i++) {
          if (!mounted) return;  // Check if still mounted before each operation
          
          final File imageFile = _selectedImages[i];
          if (!(await imageFile.exists())) {
            print('Image file does not exist: ${imageFile.path}');
            continue;  // Skip this file
          }
          
          try {
            // Generate a unique file name with timestamp and index
            final String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
            
            // Create a reference to the file location
            final Reference storageRef = FirebaseStorage.instance
              .ref()
              .child('prescriptions')
              .child(widget.appointmentId)
              .child('images')
                .child(fileName);
                
            // Create and execute the upload task
            final TaskSnapshot uploadTask = await storageRef.putFile(
              imageFile,
              SettableMetadata(contentType: 'image/jpeg')
            );
            
            // Get download URL only if upload was successful
            if (uploadTask.state == TaskState.success) {
              final String downloadUrl = await storageRef.getDownloadURL();
          imageUrls.add(downloadUrl);
              print('Successfully uploaded image #$i: $downloadUrl');
            }
          } catch (uploadError) {
            print('Error uploading image #$i: $uploadError');
            // Continue with next image
          }
        }
      }
      
            // Process voice notes one by one with improved handling
      if (_recordedVoiceNotes.isNotEmpty) {
        int successCount = 0;
        int failCount = 0;
        
        for (int i = 0; i < _recordedVoiceNotes.length; i++) {
          if (!mounted) return;  // Check if still mounted before each operation
          
          final File voiceFile = _recordedVoiceNotes[i];
          if (!(await voiceFile.exists())) {
            print('Voice file does not exist: ${voiceFile.path}');
            failCount++;
            continue;  // Skip this file
          }
          
          // Check file size to ensure it's not empty
          int fileSize = await voiceFile.length();
          if (fileSize <= 0) {
            print('Voice file is empty: ${voiceFile.path}');
            failCount++;
            continue;  // Skip empty file
          }
          
          try {
            // Generate a unique file name with timestamp and index
            final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}_$i.m4a';
            
            // Create a reference to the file location
            final Reference storageRef = FirebaseStorage.instance
              .ref()
              .child('prescriptions')
              .child(widget.appointmentId)
              .child('voice_notes')
              .child(fileName);
              
            // Create and execute the upload task with proper content type
            final TaskSnapshot uploadTask = await storageRef.putFile(
              voiceFile,
              SettableMetadata(
                contentType: 'audio/m4a',
                customMetadata: {
                  'fileName': fileName,
                  'uploadedAt': DateTime.now().toIso8601String(),
                }
              )
            );
            
            // Only proceed if we're still mounted
            if (!mounted) return;
            
            // Get download URL only if upload was successful
            if (uploadTask.state == TaskState.success) {
              final String downloadUrl = await storageRef.getDownloadURL();
          voiceNoteUrls.add(downloadUrl);
              print('Successfully uploaded voice note #$i: $downloadUrl');
              successCount++;
            } else {
              print('Upload task failed for voice note #$i with state: ${uploadTask.state}');
              failCount++;
            }
          } catch (uploadError) {
            print('Error uploading voice note #$i: $uploadError');
            failCount++;
            // Continue with next voice note
          }
        }
        
        // Log summary of upload results
        print('Voice note upload summary: $successCount successful, $failCount failed');
      }
      
      // Final check to ensure we're still mounted before Firestore update
      if (!mounted) return;
      
      // Prepare the data to update
      final Map<String, dynamic> prescriptionData = {
        'prescription': _prescriptionController.text,
        'prescriptionImages': imageUrls,
        'voiceNotes': voiceNoteUrls,
        'prescriptionUpdatedAt': firestore.FieldValue.serverTimestamp(),
        'prescribedBy': doctorId,
      };
      
      // Update Firestore document
      await _firestore.collection('appointments').doc(widget.appointmentId).update(prescriptionData);
      
      // Show success message and pop screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return success and close screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Handle any errors
      print('Error in prescription saving process: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save prescription: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Ensure loading state is reset if we're still showing this screen
      if (mounted && _isLoading) {
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
    if (!mounted) return;
    
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
      if (!mounted) return;
      
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
      if (!mounted) return;
      
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
      
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingStartTime = null;
      });
      
      if (path != null) {
        // Create file object
        File recordedFile = File(path);
        
        // Verify file exists and has content
        final bool fileExists = await recordedFile.exists();
        if (fileExists) {
          int fileSize = await recordedFile.length();
          if (!mounted) return;
          
          if (fileSize > 0) {
            print('Recorded file saved: $path (Size: $fileSize bytes)');
            setState(() {
              _recordedVoiceNotes.add(recordedFile);
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Voice note recorded successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
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
        if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
              content: Text('Recording failed: Could not save audio file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
    } catch (e) {
      print('Error stopping recording: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Delete recorded voice note
  void _deleteRecordedVoiceNote(int index) {
    setState(() {
      _recordedVoiceNotes.removeAt(index);
    });
  }
  
  // Delete existing voice note
  void _deleteExistingVoiceNote(int index) {
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

  // Updated UI for displaying existing images with improved layout
  Widget _buildExistingImagesSection(double screenWidth, double screenHeight) {
    if (_existingImageUrls.isEmpty) return SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Existing Images',
              style: GoogleFonts.poppins(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_existingImageUrls.length} images',
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.035,
                  color: AppTheme.primaryTeal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.015),
        Container(
          height: screenHeight * 0.15,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _existingImageUrls.length,
            itemBuilder: (context, index) {
              double itemWidth = screenWidth * 0.3;
              return Container(
                width: itemWidth,
                margin: EdgeInsets.only(right: screenWidth * 0.03),
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
                    GestureDetector(
                      onTap: () => _viewImage(_existingImageUrls[index], false, index),
                      child: Hero(
                        tag: 'existing_image_$index',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _existingImageUrls[index],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Container(
                                color: Colors.grey.shade100,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
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
                          padding: EdgeInsets.all(screenWidth * 0.015),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: screenWidth * 0.04,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Image ${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.03,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
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
    );
  }

  // Updated UI for displaying newly selected images with improved layout
  Widget _buildSelectedImagesSection(double screenWidth, double screenHeight) {
    if (_selectedImages.isEmpty) return SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'New Images',
              style: GoogleFonts.poppins(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedImages.length} images',
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.035,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.015),
        Container(
          height: screenHeight * 0.15,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              double itemWidth = screenWidth * 0.3;
              return Container(
                width: itemWidth,
                margin: EdgeInsets.only(right: screenWidth * 0.03),
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
                    GestureDetector(
                      onTap: () => _viewImage(_selectedImages[index].path, true, index),
                      child: Hero(
                        tag: 'new_image_$index',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImages[index],
                            fit: BoxFit.cover,
                          ),
                        ),
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
                          padding: EdgeInsets.all(screenWidth * 0.015),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: screenWidth * 0.04,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'New ${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.03,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double horizontalPadding = screenSize.width * 0.04;
    final double verticalPadding = screenSize.height * 0.02;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Write Prescription',
          style: GoogleFonts.poppins(
            fontSize: screenSize.width * 0.05,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
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
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                    ),
                    SizedBox(height: screenSize.height * 0.02),
                    Text(
                      'Saving prescription...',
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryTeal,
                        fontSize: screenSize.width * 0.04,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient info card with gradient
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          padding: EdgeInsets.all(constraints.maxWidth * 0.05),
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
                                padding: EdgeInsets.all(constraints.maxWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.user,
                                  color: Colors.white,
                                  size: constraints.maxWidth * 0.07,
                                ),
                              ),
                              SizedBox(width: constraints.maxWidth * 0.04),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Patient Name',
                                      style: GoogleFonts.poppins(
                                        fontSize: constraints.maxWidth * 0.035,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        widget.patientName,
                                        style: GoogleFonts.poppins(
                                          fontSize: constraints.maxWidth * 0.05,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                    
                    SizedBox(height: screenSize.height * 0.03),
                    
                    // Prescription text input section header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prescription Details',
                          style: GoogleFonts.poppins(
                            fontSize: screenSize.width * 0.045,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        if (Platform.isAndroid)
                          Container(
                            width: screenSize.width * 0.12,
                            height: screenSize.width * 0.12,
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
                                          width: screenSize.width * 0.11,
                                          height: screenSize.width * 0.11,
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
                                        size: screenSize.width * 0.06,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: screenSize.height * 0.015),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
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
                                  fontSize: constraints.maxWidth * 0.038,
                                  color: AppTheme.darkText,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter medication details, dosage, and instructions...',
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade400,
                                    fontSize: constraints.maxWidth * 0.038,
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
                                  contentPadding: EdgeInsets.all(constraints.maxWidth * 0.05),
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
                                        width: constraints.maxWidth * 0.15,
                                        height: constraints.maxWidth * 0.15,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Listening...',
                                        style: GoogleFonts.poppins(
                                          fontSize: constraints.maxWidth * 0.045,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Please speak clearly',
                                        style: GoogleFonts.poppins(
                                          fontSize: constraints.maxWidth * 0.035,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Prescription images section
                    Text(
                      'Attach Images',
                      style: GoogleFonts.poppins(
                        fontSize: screenSize.width * 0.045,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.015),
                    
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
                                fontSize: screenSize.width * 0.035,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.018),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        SizedBox(width: screenSize.width * 0.03),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImages,
                            icon: Icon(LucideIcons.images),
                            label: Text(
                              'Gallery',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: screenSize.width * 0.035,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.018),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: screenSize.height * 0.025),
                    
                    // Display existing images with improved layout
                    if (_existingImageUrls.isNotEmpty) 
                      _buildExistingImagesSection(screenSize.width, screenSize.height),
                    
                    if (_existingImageUrls.isNotEmpty && _selectedImages.isNotEmpty)
                      SizedBox(height: screenSize.height * 0.025),
                    
                    // Display newly selected images with improved layout
                    if (_selectedImages.isNotEmpty)
                      _buildSelectedImagesSection(screenSize.width, screenSize.height),
                    
                    SizedBox(height: 20),
                    
                    // Voice Notes Section
                    Container(
                      margin: EdgeInsets.only(bottom: screenSize.height * 0.02),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(screenSize.width * 0.02),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  LucideIcons.mic,
                                  color: AppTheme.primaryTeal,
                                  size: screenSize.width * 0.045,
                                ),
                              ),
                              SizedBox(width: screenSize.width * 0.03),
                              Text(
                                'Voice Notes',
                                style: GoogleFonts.poppins(
                                  fontSize: screenSize.width * 0.045,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkText,
                                ),
                              ),
                            ],
                          ),
                          if (_isRecording)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenSize.width * 0.03, 
                                vertical: screenSize.height * 0.008
                              ),
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
                                    size: screenSize.width * 0.03,
                                  ),
                                  SizedBox(width: screenSize.width * 0.01),
                                  Text(
                                    _formatDuration(_recordingDuration),
                                    style: GoogleFonts.poppins(
                                      fontSize: screenSize.width * 0.03,
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: constraints.maxWidth * 0.05, 
                                  vertical: 16
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: constraints.maxWidth * 0.14,
                                      height: constraints.maxWidth * 0.14,
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
                                                width: constraints.maxWidth * 0.14,
                                                height: constraints.maxWidth * 0.14,
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
                                                width: constraints.maxWidth * 0.14,
                                                height: constraints.maxWidth * 0.14,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white.withOpacity(0.5),
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ],
                                          Icon(
                                            _isRecording ? LucideIcons.square : LucideIcons.mic,
                                            color: Colors.white,
                                            size: constraints.maxWidth * 0.06,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: constraints.maxWidth * 0.04),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _isRecording ? 'Recording in progress' : 'Record a voice note',
                                              style: GoogleFonts.poppins(
                                                fontSize: constraints.maxWidth * 0.04,
                                                fontWeight: FontWeight.w600,
                                                color: _isRecording ? Colors.red : Color(0xFF2C3E50),
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _isRecording 
                                                ? 'Tap to stop • ${_formatDuration(_recordingDuration)}'
                                                : 'Tap to start recording a prescription voice note',
                                            style: GoogleFonts.poppins(
                                              fontSize: constraints.maxWidth * 0.033,
                                              color: _isRecording ? Colors.red.shade700 : Colors.grey.shade600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_isRecording)
                                      Container(
                                        width: constraints.maxWidth * 0.03,
                                        height: constraints.maxWidth * 0.03,
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
                        );
                      }
                    ),
                    
                    SizedBox(height: screenSize.height * 0.025),
                    
                    // Display existing voice notes with improved UI
                    if (_existingVoiceNoteUrls.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.015),
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
                              fontSize: screenSize.width * 0.04,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.03,
                              vertical: screenSize.height * 0.005
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_existingVoiceNoteUrls.length} notes',
                              style: GoogleFonts.poppins(
                                fontSize: screenSize.width * 0.03,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenSize.height * 0.015),
                      ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _existingVoiceNoteUrls.length,
                            itemBuilder: (context, index) {
                              final url = _existingVoiceNoteUrls[index];
                          // Use the new AudioPlayerWidget
                          return AudioPlayerWidget(
                            source: url,
                            isUrl: true,
                            label: 'Voice Note ${index + 1}',
                            onDelete: () => _deleteExistingVoiceNote(index),
                          );
                        },
                      ),
                      SizedBox(height: screenSize.height * 0.025),
                    ],
                    
                    // Display newly recorded voice notes with improved UI
                    if (_recordedVoiceNotes.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: screenSize.height * 0.015),
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
                              fontSize: screenSize.width * 0.04,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.03,
                              vertical: screenSize.height * 0.005
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_recordedVoiceNotes.length} notes',
                              style: GoogleFonts.poppins(
                                fontSize: screenSize.width * 0.03,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenSize.height * 0.015),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _recordedVoiceNotes.length,
                        itemBuilder: (context, index) {
                          final int actualIndex = index + _existingVoiceNoteUrls.length;
                          // Use the new AudioPlayerWidget for better UI and interaction
                          return AudioPlayerWidget(
                            source: _recordedVoiceNotes[index].path,
                            isUrl: false,
                            label: 'New Voice Note ${actualIndex + 1}',
                            onDelete: () => _deleteRecordedVoiceNote(index),
                          );
                        },
                      ),
                    ],
                    
                    SizedBox(height: screenSize.height * 0.03),
                    
                    // Save button with gradient
                    Container(
                      width: double.infinity,
                      height: screenSize.height * 0.07,
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
                            Icon(LucideIcons.stethoscope, size: screenSize.width * 0.05),
                            SizedBox(width: screenSize.width * 0.02),
                            Text(
                              'Save Prescription',
                              style: GoogleFonts.poppins(
                                fontSize: screenSize.width * 0.04,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.03),
                  ],
                ),
              ),
      ),
    );
  }
} 