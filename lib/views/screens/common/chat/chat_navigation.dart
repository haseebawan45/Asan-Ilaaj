import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../models/chat_room_model.dart';
import '../../../../services/chat_service.dart';
import 'chat_list_screen.dart';
import 'chat_detail_screen.dart';

/// Helper functions for navigating to chat screens
class ChatNavigation {
  /// Navigate to the list of all conversations
  static void navigateToChatList(BuildContext context, bool isDoctor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListScreen(
          isDoctor: isDoctor,
        ),
      ),
    );
  }
  
  /// Navigate directly to a chat with a specific doctor/patient
  static Future<void> navigateToChat(
    BuildContext context, {
    required bool isDoctor,
    required String otherUserId,
    required String otherUserName,
    required String otherUserProfilePic,
    required String currentUserName,
    required String currentUserProfilePic,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    
    final chatService = ChatService();
    
    // Determine doctor and patient IDs based on who's accessing
    final String doctorId = isDoctor ? currentUserId : otherUserId;
    final String patientId = isDoctor ? otherUserId : currentUserId;
    final String doctorName = isDoctor ? currentUserName : otherUserName;
    final String patientName = isDoctor ? otherUserName : currentUserName;
    final String doctorProfilePic = isDoctor ? currentUserProfilePic : otherUserProfilePic;
    final String patientProfilePic = isDoctor ? otherUserProfilePic : currentUserProfilePic;
    
    // Get existing chat room or create new one
    ChatRoom? chatRoom = await chatService.getChatRoom(doctorId, patientId);
    
    if (chatRoom == null) {
      // Create a new chat room
      chatRoom = await chatService.createChatRoom(
        doctorId: doctorId,
        patientId: patientId,
        doctorName: doctorName,
        patientName: patientName,
        doctorProfilePic: doctorProfilePic,
        patientProfilePic: patientProfilePic,
      );
    }
    
    // Navigate to chat detail screen
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            chatRoom: chatRoom!,
            isDoctor: isDoctor,
          ),
        ),
      );
    }
  }
  
  /// Build a chat button to be included in a profile or appointment card
  static Widget buildChatButton({
    required BuildContext context,
    required bool isDoctor,
    required String otherUserId,
    required String otherUserName,
    required String otherUserProfilePic,
    required String currentUserName,
    required String currentUserProfilePic,
  }) {
    return IconButton(
      icon: const Icon(Icons.chat_bubble_outline),
      tooltip: 'Chat',
      onPressed: () => navigateToChat(
        context,
        isDoctor: isDoctor,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserProfilePic: otherUserProfilePic,
        currentUserName: currentUserName,
        currentUserProfilePic: currentUserProfilePic,
      ),
    );
  }
} 