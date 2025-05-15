import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_selector/file_selector.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthcare/utils/app_theme.dart';

import '../../../../models/chat_message_model.dart';
import '../../../../models/chat_room_model.dart';
import '../../../../services/chat_service.dart';
import '../../../../utils/agora_config.dart';
import '../calls/voice_call_screen.dart';
import '../calls/video_call_screen.dart';

// Define app colors based on logo - Using centralized AppTheme
class AppColors {
  static const Color primaryPink = AppTheme.primaryPink;
  static const Color primaryTeal = AppTheme.primaryTeal;
  static const Color lightPink = AppTheme.lightPink;
  static const Color lightTeal = AppTheme.lightTeal;
  static const Color darkText = AppTheme.darkText;
  static const Color lightText = AppTheme.mediumText;
  static const Color onlineGreen = AppTheme.success;
}

class ChatDetailScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final bool isDoctor;

  const ChatDetailScreen({
    Key? key,
    required this.chatRoom,
    required this.isDoctor,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _receiverId;
  bool _isRecording = false;
  int _recordDuration = 0;
  String? _currentlyPlayingId;
  
  // Streams for online status
  Stream<bool>? _contactOnlineStatusStream;
  Stream<DateTime?>? _contactLastSeenStream;
  
  @override
  void initState() {
    super.initState();
    _setReceiverId();
    // Mark messages as read when chat is opened
    _chatService.markMessagesAsRead(widget.chatRoom.id, _currentUserId);
    
    // Set user as online
    _updateUserOnlineStatus(true);
    
    // Setup online status streams
    _setupOnlineStatusStreams();
  }
  
  @override
  void dispose() {
    // Set user as offline when leaving chat
    _updateUserOnlineStatus(false);
    _messageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  void _setReceiverId() {
    // Determine the receiver ID based on the current user
    if (widget.isDoctor) {
      _receiverId = widget.chatRoom.patientId;
    } else {
      _receiverId = widget.chatRoom.doctorId;
    }
  }
  
  void _updateUserOnlineStatus(bool isOnline) {
    _chatService.updateOnlineStatus(_currentUserId, widget.isDoctor, isOnline);
  }
  
  void _setupOnlineStatusStreams() {
    // We need to check the status of the other person
    // If current user is doctor, check patient status and vice versa
    final isCheckingDoctor = !widget.isDoctor;
    
    _contactOnlineStatusStream = 
        _chatService.getContactOnlineStatus(widget.chatRoom.id, isCheckingDoctor);
    
    _contactLastSeenStream = 
        _chatService.getContactLastSeen(widget.chatRoom.id, isCheckingDoctor);
  }
  
  // Format last seen time
  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inSeconds < 60) {
      return 'Last seen just now';
    } else if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours} h ago';
    } else if (difference.inDays < 7) {
      return 'Last seen ${difference.inDays} days ago';
    } else {
      return 'Last seen ${DateFormat.yMMMd().format(lastSeen)}';
    }
  }
  
  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _receiverId == null) return;
    
    // Store the text and clear the input field immediately
    final String messageToSend = text;
    _messageController.clear();
    
    try {
      await _chatService.sendTextMessage(
        roomId: widget.chatRoom.id,
        senderId: _currentUserId,
        receiverId: _receiverId!,
        content: messageToSend,
      );
      
      // Text controller is already cleared above
    } catch (e) {
      _showErrorSnackBar('Failed to send message');
    }
  }
  
  Future<void> _pickAndSendImage() async {
    if (_receiverId == null) return;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        
        // Show preview dialog instead of sending immediately
        _showImageUploadPreviewDialog(imageFile);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load image');
    }
  }
  
  Future<void> _takeAndSendPhoto() async {
    if (_receiverId == null) return;
    
    try {
      // Request camera permission
      var status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _showErrorSnackBar('Camera permission is required to take photos');
        return;
      }
      
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      
      if (image != null) {
        final File imageFile = File(image.path);
        
        // Use the same preview dialog as for gallery images
        _showImageUploadPreviewDialog(imageFile);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: ${e.toString()}');
    }
  }
  
  void _showImageUploadPreviewDialog(File imageFile) {
    final TextEditingController captionController = TextEditingController();
    bool isDialogOpen = true;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final Color primaryColor = widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal;
          final Size screenSize = MediaQuery.of(context).size;
          
          return WillPopScope(
            onWillPop: () async {
              isDialogOpen = false;
              return true;
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                  offset: Offset(0, -5),
                    spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // Header with blur effect
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor.withOpacity(0.95),
                              primaryColor.withOpacity(0.85),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              // Drag handle
                Container(
                                width: 40,
                                height: 5,
                  decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                  ),
                                margin: EdgeInsets.only(bottom: 16),
                              ),
                              Row(
                    children: [
                                  // Close button with animated container
                                  GestureDetector(
                                    onTap: () {
                                      isDialogOpen = false;
                                      Navigator.pop(context);
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(LucideIcons.x, color: Colors.white, size: 20),
                                    ),
                      ),
                      Expanded(
                        child: Text(
                                      'Preview Image',
                                      style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                                  // Send icon with animated container
                                  GestureDetector(
                                    onTap: () {
                                      isDialogOpen = false;
                                      String caption = captionController.text;
                          Navigator.pop(context);
                                      _sendImageWithCaption(imageFile, caption);
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(LucideIcons.send, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                      ),
                    ],
                          ),
                        ),
                      ),
                  ),
                ),
                
                  // Image preview and caption
                Expanded(
                  child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            // Type indicator
                        Container(
                              margin: EdgeInsets.only(top: 24, bottom: 16),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.image,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Image',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Image preview with animated container
                            Hero(
                              tag: 'imagePreview',
                              child: Container(
                                width: double.infinity,
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.4,
                          ),
                          decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 15,
                                      offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              imageFile,
                              fit: BoxFit.contain,
                                  ),
                            ),
                          ),
                        ),
                        
                            // Caption section
                            Container(
                              margin: EdgeInsets.only(top: 24, bottom: 8),
                              child: Text(
                                'Add a Caption',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              'Add an optional message with your image',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            // Caption input field with enhanced styling
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                          child: TextField(
                            controller: captionController,
                            decoration: InputDecoration(
                                  hintText: 'Type your message here...',
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                              ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Icon(
                                      LucideIcons.messageCircle,
                                      color: primaryColor,
                                      size: 22,
                                ),
                              ),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                            ),
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                      ],
                        ),
                    ),
                  ),
                ),
                
                // Send button
                  SafeArea(
                    child: Container(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: ElevatedButton(
                    onPressed: () {
                          isDialogOpen = false;
                          String caption = captionController.text;
                      Navigator.pop(context);
                          _sendImageWithCaption(imageFile, caption);
                    },
                    style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                      ),
                          elevation: 4,
                          shadowColor: primaryColor.withOpacity(0.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                            Icon(LucideIcons.send, size: 18),
                            SizedBox(width: 12),
                        Text(
                              'Send Image',
                              style: GoogleFonts.poppins(
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
              ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      if (isDialogOpen) {
        captionController.dispose();
      }
    });
  }
  
  Future<void> _sendImageWithCaption(File imageFile, String caption) async {
    if (_receiverId == null) return;
    
    try {
      // Show loading indicator
      _showSendingIndicator();
      
      await _chatService.sendImageMessage(
        roomId: widget.chatRoom.id,
        senderId: _currentUserId,
        receiverId: _receiverId!,
        imageFile: imageFile,
        caption: caption.trim(), // Add caption parameter to ChatService
      );
    } catch (e) {
      _showErrorSnackBar('Failed to send image');
    }
  }
  
  void _showSendingIndicator({bool isDocument = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text(isDocument ? 'Sending document...' : 'Sending image...'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
  
  Future<void> _pickAndSendDocument() async {
    if (_receiverId == null) return;
    
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'documents',
        extensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      
      final XFile? file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );
      
      if (file != null) {
        final File documentFile = File(file.path);
        final String fileName = file.name;
        
        // Show preview dialog instead of sending immediately
        _showDocumentPreviewDialog(documentFile, fileName);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to select document');
    }
  }
  
  void _showDocumentPreviewDialog(File documentFile, String fileName) {
    final TextEditingController captionController = TextEditingController();
    bool isDialogOpen = true;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final Color primaryColor = widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal;
          final Size screenSize = MediaQuery.of(context).size;
          final fileExtension = fileName.split('.').last.toLowerCase();
          final Color fileTypeColor = _getFileTypeColor(fileExtension);
          
          return WillPopScope(
            onWillPop: () async {
              isDialogOpen = false;
              return true;
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                  offset: Offset(0, -5),
                    spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // Header with blur effect
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor.withOpacity(0.95),
                              primaryColor.withOpacity(0.85),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              // Drag handle
                Container(
                                width: 40,
                                height: 5,
                  decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                  ),
                                margin: EdgeInsets.only(bottom: 16),
                              ),
                              Row(
                    children: [
                                  // Close button with animated container
                                  GestureDetector(
                                    onTap: () {
                                      isDialogOpen = false;
                                      Navigator.pop(context);
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(LucideIcons.x, color: Colors.white, size: 20),
                                    ),
                      ),
                      Expanded(
                        child: Text(
                                      'Preview Document',
                                      style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                                  // Send icon with animated container
                                  GestureDetector(
                                    onTap: () {
                                      isDialogOpen = false;
                                      String caption = captionController.text;
                          Navigator.pop(context);
                                      _sendDocumentWithCaption(documentFile, fileName, caption);
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(LucideIcons.send, color: Colors.white, size: 20),
                                    ),
                      ),
                    ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ),
                ),
                
                  // Document preview and caption
                Expanded(
                  child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            // Type indicator
                        Container(
                              margin: EdgeInsets.only(top: 24, bottom: 16),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: fileTypeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getFileIcon(fileName),
                                    size: 14,
                                    color: fileTypeColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    fileExtension.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: fileTypeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Document card with shadow and gradient
                            Container(
                              width: double.infinity,
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    Colors.grey.shade50,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                    spreadRadius: 0,
                                  ),
                                ],
                                border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                                  // File icon with glowing effect
                              Container(
                                    width: 80,
                                    height: 80,
                                decoration: BoxDecoration(
                                      color: fileTypeColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: fileTypeColor.withOpacity(0.2),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                ),
                                      ],
                                    ),
                                    child: Center(
                                child: Icon(
                                  _getFileIcon(fileName),
                                  size: 40,
                                        color: fileTypeColor,
                                ),
                              ),
                                  ),
                                  SizedBox(height: 20),
                                  
                                  // Filename with ellipsis for long names
                              Text(
                                fileName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                                  SizedBox(height: 8),
                                  
                                  // File size with loading animation
                              FutureBuilder<int>(
                                future: documentFile.length(),
                                builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Container(
                                          margin: EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(fileTypeColor),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Calculating size...',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      
                                      final fileSize = _formatFileSize(snapshot.data!);
                                      return Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: fileTypeColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.hardDrive,
                                              size: 14,
                                              color: fileTypeColor,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                    fileSize,
                                              style: GoogleFonts.poppins(
                                      fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: fileTypeColor,
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
                        
                            // Caption section
                            Container(
                              margin: EdgeInsets.only(top: 24, bottom: 8),
                              child: Text(
                                'Add a Caption',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              'Add an optional message with your document',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            // Caption input field with enhanced styling
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                          child: TextField(
                            controller: captionController,
                            decoration: InputDecoration(
                                  hintText: 'Type your message here...',
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                              ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Icon(
                                      LucideIcons.messageCircle,
                                      color: primaryColor,
                                      size: 22,
                                ),
                              ),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                            ),
                                maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                        ),
                    ),
                  ),
                ),
                
                // Send button
                  SafeArea(
                    child: Container(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: ElevatedButton(
                    onPressed: () {
                          isDialogOpen = false;
                          String caption = captionController.text;
                      Navigator.pop(context);
                          _sendDocumentWithCaption(documentFile, fileName, caption);
                    },
                    style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                      ),
                          elevation: 4,
                          shadowColor: primaryColor.withOpacity(0.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                            Icon(LucideIcons.send, size: 18),
                            SizedBox(width: 12),
                        Text(
                          'Send Document',
                              style: GoogleFonts.poppins(
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
              ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      if (isDialogOpen) {
        captionController.dispose();
      }
    });
  }
  
  // Helper method to get color based on file type
  Color _getFileTypeColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Color(0xFFFF5252); // Red for PDF
      case 'doc':
      case 'docx':
        return Color(0xFF2196F3); // Blue for Word documents
      case 'xls':
      case 'xlsx':
        return Color(0xFF4CAF50); // Green for Excel
      case 'ppt':
      case 'pptx':
        return Color(0xFFFF9800); // Orange for PowerPoint
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Color(0xFF9C27B0); // Purple for images
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Color(0xFF673AB7); // Deep purple for audio
      case 'mp4':
      case 'mov':
      case 'avi':
        return Color(0xFFE91E63); // Pink for video
      case 'zip':
      case 'rar':
        return Color(0xFF795548); // Brown for archives
      default:
        return Color(0xFF607D8B); // Blue gray for other files
    }
  }
  
  Future<void> _sendDocumentWithCaption(File documentFile, String fileName, String caption) async {
    if (_receiverId == null) return;
    
    try {
      // Show loading indicator
      _showSendingIndicator(isDocument: true);
      
      await _chatService.sendDocumentMessage(
        roomId: widget.chatRoom.id,
        senderId: _currentUserId,
        receiverId: _receiverId!,
        documentFile: documentFile,
        fileName: fileName,
        caption: caption.trim(),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to send document');
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  void _startRecording() {
    // This would start recording, but for now we'll just show a dialog
    // The record package might need configuration specific to your needs
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
    });
    
    // Simulated timer for recording duration
    Stream.periodic(const Duration(seconds: 1)).listen((event) {
      if (_isRecording) {
        setState(() {
          _recordDuration++;
        });
      }
    });
  }
  
  void _stopRecordingAndSend() {
    // Simulate sending an audio message
    _showErrorSnackBar('Audio message sent (simulated)');
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
  }
  
  void _cancelRecording() {
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });
  }
  
  Future<void> _playAudio(String audioUrl, String messageId) async {
    if (_currentlyPlayingId == messageId) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingId = null;
      });
      return;
    }
    
    // Stop any currently playing audio
    if (_currentlyPlayingId != null) {
      await _audioPlayer.stop();
    }
    
    setState(() {
      _currentlyPlayingId = messageId;
    });
    
    try {
      await _audioPlayer.play(UrlSource(audioUrl));
      
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _currentlyPlayingId = null;
        });
      });
    } catch (e) {
      _showErrorSnackBar('Failed to play audio');
      setState(() {
        _currentlyPlayingId = null;
      });
    }
  }
  
  void _initiateVoiceCall() {
    if (_receiverId == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          chatRoom: widget.chatRoom,
          isDoctor: widget.isDoctor,
          currentUserId: _currentUserId,
          ),
      ),
    );
  }
  
  void _initiateVideoCall() {
    if (_receiverId == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          chatRoom: widget.chatRoom,
          isDoctor: widget.isDoctor,
          currentUserId: _currentUserId,
          ),
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal, size: 22),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: StreamBuilder<bool>(
          stream: _contactOnlineStatusStream,
          builder: (context, onlineSnapshot) {
            final isOnline = onlineSnapshot.data ?? false;
            
            return Row(
          children: [
            Hero(
                  tag: widget.chatRoom.id,
                  child: _buildProfileAvatar(
                    isOnline: isOnline,
                    imageUrl: widget.isDoctor ? widget.chatRoom.patientProfilePic : widget.chatRoom.doctorProfilePic,
                    placeholderIcon: widget.isDoctor ? LucideIcons.user : LucideIcons.stethoscope,
                  ),
            ),
                SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                        widget.isDoctor 
                            ? (widget.chatRoom.patientName ?? 'Patient')
                            : (widget.chatRoom.doctorName ?? 'Doctor'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                      fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                      
                      if (isOnline)
                        // Show online status
                      Text(
                          'Online',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.onlineGreen,
                          fontWeight: FontWeight.w500,
                        ),
                        )
                      else
                        // Show last seen time
                        StreamBuilder<DateTime?>(
                          stream: _contactLastSeenStream,
                          builder: (context, lastSeenSnapshot) {
                            final lastSeen = lastSeenSnapshot.data;
                            return Text(
                              _formatLastSeen(lastSeen),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.lightText,
                      ),
                            );
                          },
                  ),
                ],
              ),
            ),
          ],
            );
          }
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.phone, 
              color: widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal),
            onPressed: _initiateVoiceCall,
            tooltip: 'Voice Call',
          ),
          IconButton(
            icon: Icon(LucideIcons.video, 
              color: widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal),
            onPressed: _initiateVideoCall,
            tooltip: 'Video Call',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(widget.chatRoom.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal
                      ),
                      strokeWidth: 3,
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load messages',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.lightText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() {}),
                          icon: Icon(Icons.refresh, 
                            color: widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal),
                          label: Text(
                            'Tap to retry',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: widget.isDoctor ? AppColors.lightPink : AppColors.lightTeal,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.messageCircle,
                            size: 64,
                            color: widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Start a conversation',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            color: AppColors.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Send a message to begin chatting with ${widget.isDoctor ? widget.chatRoom.patientName : widget.chatRoom.doctorName}',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.lightText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  physics: BouncingScrollPhysics(),
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMyMessage = message.senderId == _currentUserId;
                    
                    // Add date header if needed
                    Widget? dateHeader;
                    if (index == messages.length - 1 || 
                        !_isSameDay(messages[index].timestamp, messages[index + 1].timestamp)) {
                      dateHeader = _buildDateHeader(messages[index].timestamp);
                    }
                    
                    return Column(
                      children: [
                        if (dateHeader != null) dateHeader,
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          child: _buildMessageItem(message, isMyMessage),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // Recording indicator
          if (_isRecording)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPink.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recording...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryPink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(_recordDuration),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.lightText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _stopRecordingAndSend,
                    color: widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _cancelRecording,
                    color: AppColors.primaryPink,
                  ),
                ],
              ),
            ),
          
          // Message input
            Container(
              padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                  color: Colors.grey.shade100,
                    offset: Offset(0, -2),
                  blurRadius: 4,
                  ),
                ],
              ),
                child: Row(
                  children: [
                IconButton(
                  onPressed: () {
                    // Open attachment options
                    _showAttachmentOptions(context);
                  },
                  icon: Icon(
                    LucideIcons.paperclip,
                    color: AppColors.lightText,
                    size: 22,
                  ),
                  padding: EdgeInsets.all(12),
                  constraints: BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade400
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 5,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: IconButton(
                            icon: Icon(LucideIcons.mic),
                            onPressed: _startRecording,
                            color: AppColors.lightText,
                            iconSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                    color: widget.isDoctor 
                        ? AppColors.primaryPink
                        : AppColors.primaryTeal,
                        shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.isDoctor 
                            ? AppColors.primaryPink.withOpacity(0.3)
                            : AppColors.primaryTeal.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                      ),
                      child: IconButton(
                    icon: Icon(LucideIcons.send),
                    onPressed: _sendTextMessage,
                    color: Colors.white,
                    iconSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAttachmentOptions(BuildContext context) {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                offset: Offset(0, -5),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 4,
                margin: EdgeInsets.only(top: 12, bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Share Content",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildAttachmentOption(
                    LucideIcons.image,
                                        'Image',
                    AppColors.primaryTeal,
                                        () {
                                          Navigator.pop(context);
                                          _pickAndSendImage();
                                        },
                                      ),
                                      _buildAttachmentOption(
                    LucideIcons.fileText,
                                        'Document',
                    AppColors.primaryPink,
                                        () {
                                          Navigator.pop(context);
                                          _pickAndSendDocument();
                                        },
                                      ),
                                      _buildAttachmentOption(
                    LucideIcons.camera,
                                        'Camera',
                    Color(0xFF8E44AD), // Purple as accent color
                                        () {
                                          Navigator.pop(context);
                                          _takeAndSendPhoto();
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 30),
                                ],
                            ),
                          );
                        },
    );
  }
  
  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
                          children: [
                    Container(
            width: 60,
            height: 60,
                      decoration: BoxDecoration(
              color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
            child: Icon(
              icon,
              color: color,
              size: 24,
                      ),
                    ),
          SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat.yMMMd().format(date);
    }
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey.shade200,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                dateText,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.lightText,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey.shade200,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageItem(ChatMessage message, bool isMyMessage) {
    final messageTime = DateFormat.jm().format(message.timestamp);
    
    return Container(
      margin: EdgeInsets.only(
        left: isMyMessage ? 80 : 8,
        right: isMyMessage ? 8 : 80,
        bottom: 16,
      ),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.isDoctor 
                  ? AppColors.lightPink 
                  : AppColors.lightTeal,
              child: Icon(
                LucideIcons.user,
                size: 16,
                color: widget.isDoctor 
                    ? AppColors.primaryPink 
                    : AppColors.primaryTeal,
              ),
            ),
            SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isMyMessage
                        ? (widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: isMyMessage ? Radius.circular(20) : Radius.circular(5),
                      bottomRight: isMyMessage ? Radius.circular(5) : Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                    border: isMyMessage
                        ? null
                        : Border.all(color: Colors.grey.shade200),
                  ),
                  child: _buildMessageContentByType(message, isMyMessage),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      messageTime,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.lightText,
                      ),
                    ),
                    if (isMyMessage) ...[
                      SizedBox(width: 4),
                      Icon(
                        message.isRead ? LucideIcons.checkCheck : LucideIcons.check,
                        size: 14,
                        color: message.isRead
                            ? (widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal)
                            : Colors.grey.shade500,
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageContentByType(ChatMessage message, bool isMyMessage) {
    Color primaryColor = widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal;
    
    switch (message.type) {
      case MessageType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            message.content,
            style: GoogleFonts.poppins(
              color: isMyMessage ? Colors.white : AppColors.darkText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        );
        
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
                bottomLeft: message.caption == null || message.caption!.isEmpty
                    ? (isMyMessage ? Radius.circular(20) : Radius.circular(5))
                    : Radius.circular(0),
                bottomRight: message.caption == null || message.caption!.isEmpty
                    ? (isMyMessage ? Radius.circular(5) : Radius.circular(20))
                    : Radius.circular(0),
              ),
              child: message.fileUrl != null
                  ? _buildChatImageWithErrorHandling(
                      message.fileUrl!,
                      message.id,
                      primaryColor
                    )
                  : Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Icon(
                          LucideIcons.image,
                          color: Colors.grey.shade400,
                          size: 32,
                        ),
                        ),
                      ),
                    ),
              // Show caption if it exists
              if (message.caption != null && message.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    message.caption!,
                    style: TextStyle(
                    color: isMyMessage ? Colors.white : AppColors.darkText,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
        );
        
      case MessageType.audio:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  if (message.fileUrl != null) {
                    _playAudio(message.fileUrl!, message.id);
                  }
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isMyMessage ? Colors.white : primaryColor).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _currentlyPlayingId == message.id
                        ? LucideIcons.pause
                        : LucideIcons.play,
                    color: isMyMessage ? Colors.white : primaryColor,
                    size: 18,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: (isMyMessage ? Colors.white : primaryColor).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: _currentlyPlayingId == message.id
                            ? LinearProgressIndicator(
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isMyMessage ? Colors.white : primaryColor,
                                ),
                              )
                            : null,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.mic,
                          size: 14,
                          color: isMyMessage ? Colors.white.withOpacity(0.7) : Colors.grey.shade600,
                        ),
                        SizedBox(width: 4),
                        Text(
                          message.audioDuration != null
                              ? _formatTime(message.audioDuration!)
                              : '0:00',
                          style: TextStyle(
                            color: isMyMessage ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
            ],
          ),
        );
        
      case MessageType.document:
        return Container(
          padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                  color: (isMyMessage ? Colors.white : primaryColor).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getFileIcon(message.content),
                          size: 24,
                  color: isMyMessage ? Colors.white : primaryColor,
                        ),
                      ),
                      SizedBox(width: 12),
              Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.content,
                      style: GoogleFonts.poppins(
                                color: isMyMessage ? Colors.white : Colors.black87,
                                fontSize: 14,
                        fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                                Text(
                      'Document',
                      style: GoogleFonts.poppins(
                        color: isMyMessage 
                            ? Colors.white.withOpacity(0.7) 
                            : Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
              ),
              IconButton(
                icon: Icon(
                  LucideIcons.externalLink,
                  size: 20,
                  color: isMyMessage ? Colors.white : primaryColor,
                ),
                onPressed: () {
                  if (message.fileUrl != null) {
                    _showDocumentOptions(message.fileUrl!, message.content);
                  }
                },
                ),
            ],
          ),
        );
    }
  }
  
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return LucideIcons.fileText;
      case 'doc':
      case 'docx':
        return LucideIcons.fileText;
      case 'xls':
      case 'xlsx':
        return LucideIcons.fileText;
      case 'ppt':
      case 'pptx':
        return LucideIcons.fileText;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return LucideIcons.image;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return LucideIcons.music;
      case 'mp4':
      case 'mov':
      case 'avi':
        return LucideIcons.video;
      case 'zip':
      case 'rar':
        return LucideIcons.file;
      default:
        return LucideIcons.file;
    }
  }
  
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  void _showDocumentOptions(String url, String fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  fileName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: Icon(LucideIcons.fileText, color: Theme.of(context).primaryColor),
                title: Text('Open Document', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _openDocumentUrl(url, fileName);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.download, color: Theme.of(context).primaryColor),
                title: Text('Download', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _downloadDocument(url, fileName);
                },
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
  
  // New methods for document handling
  
  // Open document URL with validation
  void _openDocumentUrl(String url, String fileName) {
    try {
      // Validate and fix URL before attempting to open
      final validatedUrl = _validateAndFixImageUrl(url);
      
      if (validatedUrl.isEmpty) {
        _showErrorSnackBar('Invalid document URL');
        return;
      }
      
      // Here you would typically use url_launcher to open the URL
      // For now, we'll just show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening document: $fileName'),
          duration: Duration(seconds: 2),
        )
      );
    } catch (e) {
      debugPrint('Error opening document: $e');
      _showErrorSnackBar('Failed to open document');
    }
  }
  
  // Download document with validation
  void _downloadDocument(String url, String fileName) {
    try {
      // Validate and fix URL before attempting to download
      final validatedUrl = _validateAndFixImageUrl(url);
      
      if (validatedUrl.isEmpty) {
        _showErrorSnackBar('Invalid document URL');
        return;
      }
      
      // Here you would typically implement download functionality
      // For now, we'll just show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading: $fileName'),
          duration: Duration(seconds: 2),
        )
      );
    } catch (e) {
      debugPrint('Error downloading document: $e');
      _showErrorSnackBar('Failed to download document');
    }
  }
  
  // New methods for profile image handling
  
  // Build profile avatar with error handling
  Widget _buildProfileAvatar({required bool isOnline, String? imageUrl, required IconData placeholderIcon}) {
    final Color primaryColor = widget.isDoctor ? AppColors.primaryPink : AppColors.primaryTeal;
    final ValueNotifier<bool> isImageLoading = ValueNotifier<bool>(true);
    final ValueNotifier<bool> hasImageError = ValueNotifier<bool>(false);
    
    // Skip loading state for empty URLs or asset images
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.startsWith('assets/')) {
      isImageLoading.value = false;
    } else {
      // Setup image loading tracking
      _handleProfileImageLoad(imageUrl, (success) {
        if (!success && mounted) {
          hasImageError.value = true;
        }
        if (mounted) {
          isImageLoading.value = false;
        }
      });
    }
    
    return Stack(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: hasImageError,
          builder: (context, hasError, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: isImageLoading,
              builder: (context, isLoading, _) {
                final bool shouldShowImage = !hasError && imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('assets/');
                final ImageProvider? imageProvider = shouldShowImage ? _getImageProvider(imageUrl) : null;
                
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: widget.isDoctor ? AppColors.lightPink : AppColors.lightTeal,
                  backgroundImage: imageProvider,
                  child: (!shouldShowImage || isLoading)
                      ? (isLoading 
                          ? SizedBox(
                              height: 15,
                              width: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            )
                          : Icon(
                              placeholderIcon,
                              color: primaryColor,
                              size: 18,
                            ))
                      : null,
                );
              }
            );
          }
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.onlineGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  // Track image loading completion
  void _handleProfileImageLoad(String imageUrl, Function(bool) onComplete) {
    if (imageUrl.startsWith('assets/')) {
      onComplete(true);
      return;
    }
    
    try {
      final resolvedImage = _getImageProvider(imageUrl);
      if (resolvedImage == null) {
        onComplete(false);
        return;
      }
      
      final imageStream = resolvedImage.resolve(ImageConfiguration.empty);
      final imageStreamListener = ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {
          // Image loaded successfully
          onComplete(true);
        },
        onError: (exception, stackTrace) {
          // Error loading image
          debugPrint('Error preloading image: $exception');
          onComplete(false);
        },
      );
      
      // Add listener to track when image finishes loading
      imageStream.addListener(imageStreamListener);
      
      // Clean up listener after a timeout (in case image never loads)
      Future.delayed(Duration(seconds: 10), () {
        imageStream.removeListener(imageStreamListener);
      });
    } catch (e) {
      debugPrint('Error handling image load: $e');
      onComplete(false);
    }
  }
  
  // Get image provider with URL validation
  ImageProvider? _getImageProvider(String url) {
    try {
      if (url.isEmpty) return null;
      
      // Handle asset images
      if (url.startsWith('assets/')) {
        return AssetImage(url);
      }
      
      // Validate URL format
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Try to fix Firebase Storage URLs missing protocol
        if (url.contains('firebasestorage.googleapis.com')) {
          url = 'https://$url';
          debugPrint('Fixed Firebase Storage URL: https://$url');
        } else {
          debugPrint('Invalid image URL format: $url');
          return null;
        }
      }
      
      // Clean URL by removing unwanted characters
      if (url.contains(' ') || url.contains("'")) {
        url = url.replaceAll('"', '')
                  .replaceAll("'", '')
                  .replaceAll(' ', '%20');
        debugPrint('Cleaned profile image URL: $url');
      }
      
      return NetworkImage(url);
    } catch (e) {
      debugPrint('Error processing profile image: $e');
      return null;
    }
  }
  
  // New method for handling chat images with error handling
  Widget _buildChatImageWithErrorHandling(String imageUrl, String messageId, Color primaryColor) {
    final ValueNotifier<bool> isImageLoading = ValueNotifier<bool>(true);
    final ValueNotifier<bool> hasImageError = ValueNotifier<bool>(false);
    
    // Validate and fix URL before loading
    imageUrl = _validateAndFixImageUrl(imageUrl);
    
    return ValueListenableBuilder<bool>(
      valueListenable: hasImageError,
      builder: (context, hasError, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isImageLoading,
          builder: (context, isLoading, _) {
            if (hasError) {
              return Container(
                height: 200,
                color: Colors.grey.shade200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.grey.shade400,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Reset loading states
                        hasImageError.value = false;
                        isImageLoading.value = true;
                      },
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  ],
                ),
              );
            }
            
            return GestureDetector(
              onTap: () => _showFullScreenImagePreview(context, imageUrl),
              child: Hero(
                tag: 'chat_image_$messageId',
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    // Update error state using post frame callback
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!hasImageError.value) {
                        hasImageError.value = true;
                        isImageLoading.value = false;
                        debugPrint('Failed to load chat image ($messageId): $error');
                      }
                    });
                    return Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.grey.shade400,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  imageBuilder: (context, imageProvider) {
                    // Update loading state using post frame callback
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (isImageLoading.value) {
                        isImageLoading.value = false;
                      }
                    });
                    return Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200, // Fixed height for consistency
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // Validate and fix image URLs
  String _validateAndFixImageUrl(String url) {
    if (url.isEmpty) return url;
    
    try {      
      // Validate URL format
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Try to fix Firebase Storage URLs missing protocol
        if (url.contains('firebasestorage.googleapis.com')) {
          url = 'https://$url';
          debugPrint('Fixed Firebase Storage URL in message: https://$url');
        }
      }
      
      // Clean URL by removing unwanted characters
      if (url.contains(' ') || url.contains("'") || url.contains('"')) {
        url = url.replaceAll('"', '')
                  .replaceAll("'", '')
                  .replaceAll(' ', '%20');
        debugPrint('Cleaned message image URL: $url');
      }
      
      return url;
    } catch (e) {
      debugPrint('Error processing message image URL: $e');
      return url; // Return original URL if any errors
    }
  }

  void _showFullScreenImagePreview(BuildContext context, String imageUrl) {
    final TransformationController _transformationController = TransformationController();
    bool _isZoomed = false;

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Stack(
        children: [
          // Black semi-transparent background
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.9),
            ),
          ),
          
          // Dismissible area
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Image with InteractiveViewer
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              onInteractionStart: (details) {
                _isZoomed = _transformationController.value.getMaxScaleOnAxis() > 1.0;
              },
              onInteractionEnd: (details) {
                if (!_isZoomed) {
                  _transformationController.value = Matrix4.identity();
                }
              },
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => Container(
                  color: Colors.transparent,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.x,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // Download button
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                // TODO: Implement image download
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloading image...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.download,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 