import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../models/chat_room_model.dart';
import '../../../../services/chat_service.dart';
import 'chat_detail_screen.dart';

// Use the AppColors class we defined in chat_detail_screen.dart
class AppColors {
  static const Color primaryPink = Color(0xFFFF3F80);  // Bright pink from logo
  static const Color primaryTeal = Color(0xFF30A9C7);  // Teal/blue from logo
  static const Color lightPink = Color(0xFFFFE6F0);    // Light pink for backgrounds
  static const Color lightTeal = Color(0xFFE6F7FB);    // Light teal for backgrounds
  static const Color darkText = Color(0xFF333333);     // Dark text
  static const Color lightText = Color(0xFF6F7478);    // Light text
  static const Color onlineGreen = Color(0xFF4CAF50); // Green for online status
}

class ChatListScreen extends StatefulWidget {
  final bool isDoctor;

  const ChatListScreen({Key? key, required this.isDoctor}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _animationController.forward();
    
    // Set user as online when entering chat
    _setUserOnlineStatus(true);
  }
  
  @override
  void dispose() {
    // Set user as offline when leaving chat
    _setUserOnlineStatus(false);
    _animationController.dispose();
    super.dispose();
  }
  
  void _setUserOnlineStatus(bool isOnline) {
    _chatService.updateOnlineStatus(userId, widget.isDoctor, isOnline);
  }
  
  @override
  Widget build(BuildContext context) {
    // Use our brand colors instead of theme colors
    final primaryColor = widget.isDoctor 
        ? AppColors.primaryPink 
        : AppColors.primaryTeal;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Text(
          'Conversations',
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.search),
            onPressed: () {
              // Implement search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Search functionality coming soon'),
                  backgroundColor: primaryColor,
                )
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar at top
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.onlineGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onlineGreen.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Online',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 20),
                Text(
                  widget.isDoctor ? 'Doctor Mode' : 'Patient Mode',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Chat list
          Expanded(
            child: StreamBuilder<List<ChatRoom>>(
              stream: _chatService.getChatRoomsForUser(userId, widget.isDoctor),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
                          size: 60,
                          color: Colors.red.shade300,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Error loading conversations',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: AppColors.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please try again later',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.lightText,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final chatRooms = snapshot.data ?? [];
                
                if (chatRooms.isEmpty) {
                  return _buildEmptyState(primaryColor);
                }
                
                return ListView.builder(
                  itemCount: chatRooms.length,
                  padding: EdgeInsets.only(top: 16, bottom: 16),
                  itemBuilder: (context, index) {
                    final chatRoom = chatRooms[index];
                    
                    // Determine if this user is the doctor or patient
                    final isCurrentUserDoctor = widget.isDoctor;
                    
                    // Get the other person's name and image based on user type
                    final otherPersonName = isCurrentUserDoctor
                        ? chatRoom.patientName
                        : chatRoom.doctorName;
                    
                    final otherPersonImage = isCurrentUserDoctor
                        ? chatRoom.patientProfilePic
                        : chatRoom.doctorProfilePic;
                    
                    // Get unread count for current user
                    final unreadCount = chatRoom.unreadCount[userId] ?? 0;
                    
                    // Get online status of the other person
                    final isOtherPersonOnline = isCurrentUserDoctor
                        ? chatRoom.isPatientOnline
                        : chatRoom.isDoctorOnline;
                    
                    return AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final delay = index * 0.1;
                        final animation = CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(
                            delay.clamp(0.0, 0.9),
                            (delay + 0.4).clamp(0.0, 1.0),
                            curve: Curves.easeOutQuart,
                          ),
                        );
                        
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0.1, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _buildChatListItem(
                        context,
                        chatRoom,
                        otherPersonName,
                        otherPersonImage,
                        unreadCount,
                        primaryColor,
                        isOtherPersonOnline,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: widget.isDoctor ? AppColors.lightPink : AppColors.lightTeal,
                borderRadius: BorderRadius.circular(75),
              ),
              child: Icon(
                LucideIcons.messageSquare,
                size: 80,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 32),
            Text(
              'No conversations yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.isDoctor
                    ? 'When patients chat with you, they will appear here'
                    : 'Start a conversation with your doctor to ask questions or get help',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.lightText,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                // Return to previous screen
                Navigator.of(context).pop();
              },
              icon: Icon(LucideIcons.arrowLeft),
              label: Text(
                'Return to Dashboard',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatListItem(
    BuildContext context,
    ChatRoom chatRoom,
    String name,
    String imageUrl,
    int unreadCount,
    Color primaryColor,
    bool isOnline,
  ) {
    // Format the last message time
    String formattedTime = chatRoom.lastMessageTime != null
        ? _formatTime(chatRoom.lastMessageTime!)
        : '';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: unreadCount > 0 
                ? primaryColor.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            spreadRadius: unreadCount > 0 ? 2 : 1,
            blurRadius: unreadCount > 0 ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: unreadCount > 0
            ? Border.all(color: primaryColor.withOpacity(0.1), width: 1.5)
            : Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chatRoom: chatRoom,
                isDoctor: widget.isDoctor,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User avatar with online indicator
              Stack(
            children: [
              Hero(
                    tag: chatRoom.id,
                  child: CircleAvatar(
                    radius: 30,
                      backgroundColor: widget.isDoctor 
                          ? AppColors.lightPink 
                          : AppColors.lightTeal,
                    backgroundImage: imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(imageUrl)
                        : null,
                    child: imageUrl.isEmpty
                        ? Icon(
                              widget.isDoctor 
                                  ? LucideIcons.user 
                                  : LucideIcons.stethoscope,
                              color: primaryColor,
                              size: 26,
                          )
                        : null,
                  ),
                ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.onlineGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: unreadCount > 0 ? primaryColor : AppColors.darkText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          formattedTime,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: unreadCount > 0 ? primaryColor : AppColors.lightText,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: chatRoom.lastMessageText != null
                              ? Text(
                                  chatRoom.lastMessageText!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: unreadCount > 0
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                                    fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                )
                              : Text(
                                  'Start a conversation',
                                  style: GoogleFonts.poppins(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                        SizedBox(width: 8),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return DateFormat.jm().format(dateTime); // 5:30 PM
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat.E().format(dateTime); // Mon, Tue, etc.
    } else {
      return DateFormat.MMMd().format(dateTime); // Jan 5, Feb 10, etc.
    }
  }
} 