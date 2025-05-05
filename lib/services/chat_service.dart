import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/chat_message_model.dart';
import '../models/chat_room_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Collection references
  final CollectionReference _chatRoomsCollection = 
      FirebaseFirestore.instance.collection('chatRooms');
  
  // Get chat room between doctor and patient
  Future<ChatRoom?> getChatRoom(String doctorId, String patientId) async {
    final query = await _chatRoomsCollection
        .where('doctorId', isEqualTo: doctorId)
        .where('patientId', isEqualTo: patientId)
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      return ChatRoom.fromFirestore(query.docs.first);
    }
    return null;
  }
  
  // Create a new chat room
  Future<ChatRoom> createChatRoom({
    required String doctorId,
    required String patientId,
    required String doctorName,
    required String patientName,
    required String doctorProfilePic,
    required String patientProfilePic,
  }) async {
    // Check if room already exists
    final existingRoom = await getChatRoom(doctorId, patientId);
    if (existingRoom != null) {
      return existingRoom;
    }
    
    // Create new room with unique ID
    final String roomId = const Uuid().v4();
    final Map<String, int> unreadCount = {
      doctorId: 0,
      patientId: 0,
    };
    
    final chatRoom = ChatRoom(
      id: roomId,
      doctorId: doctorId,
      patientId: patientId,
      createdAt: DateTime.now(),
      doctorName: doctorName,
      patientName: patientName,
      doctorProfilePic: doctorProfilePic,
      patientProfilePic: patientProfilePic,
      unreadCount: unreadCount,
      isDoctorOnline: false,
      isPatientOnline: false,
      doctorLastSeen: DateTime.now(),
      patientLastSeen: DateTime.now(),
    );
    
    await _chatRoomsCollection.doc(roomId).set(chatRoom.toFirestore());
    return chatRoom;
  }
  
  // Get all chat rooms for a user (doctor or patient)
  Stream<List<ChatRoom>> getChatRoomsForUser(String userId, bool isDoctor) {
    String field = isDoctor ? 'doctorId' : 'patientId';
    
    return _chatRoomsCollection
        .where(field, isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList());
  }
  
  // New method: Update online status
  Future<void> updateOnlineStatus(String userId, bool isDoctor, bool isOnline) async {
    // Get all chat rooms where this user is a participant
    final field = isDoctor ? 'doctorId' : 'patientId';
    final query = await _chatRoomsCollection
        .where(field, isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();
    
    // Create a batch to update all rooms at once
    final batch = _firestore.batch();
    
    for (var doc in query.docs) {
      final statusField = isDoctor ? 'isDoctorOnline' : 'isPatientOnline';
      final lastSeenField = isDoctor ? 'doctorLastSeen' : 'patientLastSeen';
      
      Map<String, dynamic> updates = {
        statusField: isOnline,
      };
      
      // If going offline, update last seen timestamp
      if (!isOnline) {
        updates[lastSeenField] = FieldValue.serverTimestamp();
      }
      
      batch.update(doc.reference, updates);
    }
    
    await batch.commit();
  }
  
  // New method: Get contact online status
  Stream<bool> getContactOnlineStatus(String roomId, bool isCheckingDoctor) {
    // If isCheckingDoctor is true, we want to check the doctor's status
    // Otherwise, we check the patient's status
    final field = isCheckingDoctor ? 'isDoctorOnline' : 'isPatientOnline';
    
    return _chatRoomsCollection
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() as Map<String, dynamic>?;
          return data != null ? data[field] as bool? ?? false : false;
        });
  }
  
  // New method: Get contact last seen
  Stream<DateTime?> getContactLastSeen(String roomId, bool isCheckingDoctor) {
    final field = isCheckingDoctor ? 'doctorLastSeen' : 'patientLastSeen';
    
    return _chatRoomsCollection
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null && data[field] != null) {
            return (data[field] as Timestamp).toDate();
          }
          return null;
        });
  }
  
  // Send a text message
  Future<ChatMessage> sendTextMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final messageId = const Uuid().v4();
    final timestamp = DateTime.now();
    
    final message = ChatMessage(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      type: MessageType.text,
      timestamp: timestamp,
    );
    
    // Add to messages subcollection
    await _chatRoomsCollection
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .set(message.toFirestore());
    
    // Update chat room with last message
    await _updateChatRoomWithLastMessage(
      roomId, 
      content, 
      timestamp, 
      receiverId
    );
    
    return message;
  }
  
  // Send an image message
  Future<ChatMessage> sendImageMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required File imageFile,
    String caption = '',
  }) async {
    final messageId = const Uuid().v4();
    final timestamp = DateTime.now();
    
    // Upload image to Firebase Storage
    final fileExtension = path.extension(imageFile.path);
    final storagePath = 'chat_images/$roomId/$messageId$fileExtension';
    
    final uploadTask = _storage.ref(storagePath).putFile(imageFile);
    final snapshot = await uploadTask;
    final fileUrl = await snapshot.ref.getDownloadURL();
    
    final message = ChatMessage(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      content: caption.isNotEmpty ? caption : 'Image',
      type: MessageType.image,
      timestamp: timestamp,
      fileUrl: fileUrl,
    );
    
    // Add to messages subcollection
    await _chatRoomsCollection
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .set(message.toFirestore());
    
    // Update chat room with last message
    final lastMessageText = caption.isNotEmpty ? 'Photo: $caption' : 'Photo';
    await _updateChatRoomWithLastMessage(
      roomId, 
      lastMessageText, 
      timestamp, 
      receiverId
    );
    
    return message;
  }
  
  // Send an audio message
  Future<ChatMessage> sendAudioMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required File audioFile,
    required int audioDuration,
  }) async {
    final messageId = const Uuid().v4();
    final timestamp = DateTime.now();
    
    // Upload audio to Firebase Storage
    final storagePath = 'chat_audio/$roomId/$messageId.m4a';
    
    final uploadTask = _storage.ref(storagePath).putFile(audioFile);
    final snapshot = await uploadTask;
    final fileUrl = await snapshot.ref.getDownloadURL();
    
    final message = ChatMessage(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      content: 'Audio',
      type: MessageType.audio,
      timestamp: timestamp,
      fileUrl: fileUrl,
      audioDuration: audioDuration,
    );
    
    // Add to messages subcollection
    await _chatRoomsCollection
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .set(message.toFirestore());
    
    // Update chat room with last message
    await _updateChatRoomWithLastMessage(
      roomId, 
      'Audio', 
      timestamp, 
      receiverId
    );
    
    return message;
  }
  
  // Send a document message
  Future<ChatMessage> sendDocumentMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required File documentFile,
    required String fileName,
    String caption = '',
  }) async {
    final messageId = const Uuid().v4();
    final timestamp = DateTime.now();
    
    // Upload document to Firebase Storage
    final fileExtension = path.extension(documentFile.path);
    final storagePath = 'chat_documents/$roomId/$messageId$fileExtension';
    
    final uploadTask = _storage.ref(storagePath).putFile(documentFile);
    final snapshot = await uploadTask;
    final fileUrl = await snapshot.ref.getDownloadURL();
    
    final message = ChatMessage(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      content: fileName,
      type: MessageType.document,
      timestamp: timestamp,
      fileUrl: fileUrl,
      caption: caption,
    );
    
    // Add to messages subcollection
    await _chatRoomsCollection
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .set(message.toFirestore());
    
    // Update chat room with last message
    final lastMessageText = caption.isNotEmpty 
        ? 'Document: $fileName ($caption)' 
        : 'Document: $fileName';
    
    await _updateChatRoomWithLastMessage(
      roomId, 
      lastMessageText, 
      timestamp, 
      receiverId
    );
    
    return message;
  }
  
  // Get messages for a chat room
  Stream<List<ChatMessage>> getMessages(String roomId) {
    return _chatRoomsCollection
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }
  
  // Mark messages as read
  Future<void> markMessagesAsRead(String roomId, String userId) async {
    // Get unread messages
    final unreadMessages = await _chatRoomsCollection
        .doc(roomId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    
    // Update each message
    final batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    // Reset unread count for this user
    final roomDoc = await _chatRoomsCollection.doc(roomId).get();
    final roomData = roomDoc.data() as Map<String, dynamic>;
    final unreadCount = Map<String, dynamic>.from(roomData['unreadCount'] ?? {});
    unreadCount[userId] = 0;
    
    batch.update(roomDoc.reference, {'unreadCount': unreadCount});
    await batch.commit();
  }
  
  // Update chat room with last message
  Future<void> _updateChatRoomWithLastMessage(
    String roomId,
    String lastMessageText,
    DateTime timestamp,
    String receiverId,
  ) async {
    // Get the chat room
    final roomDoc = await _chatRoomsCollection.doc(roomId).get();
    final roomData = roomDoc.data() as Map<String, dynamic>;
    
    // Update unread count
    final unreadCount = Map<String, dynamic>.from(roomData['unreadCount'] ?? {});
    unreadCount[receiverId] = (unreadCount[receiverId] ?? 0) + 1;
    
    // Update room
    await _chatRoomsCollection.doc(roomId).update({
      'lastMessageText': lastMessageText,
      'lastMessageTime': Timestamp.fromDate(timestamp),
      'unreadCount': unreadCount,
    });
  }
  
  // Delete chat message
  Future<void> deleteMessage(String roomId, String messageId) async {
    await _chatRoomsCollection
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
  
  // Archive/deactivate chat room
  Future<void> archiveChatRoom(String roomId) async {
    await _chatRoomsCollection.doc(roomId).update({'isActive': false});
  }
} 