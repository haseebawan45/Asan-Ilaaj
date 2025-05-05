import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  audio,
  document
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? fileUrl;
  final int? audioDuration;
  final String? caption;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.fileUrl,
    this.audioDuration,
    this.caption,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type']}',
        orElse: () => MessageType.text,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      fileUrl: data['fileUrl'],
      audioDuration: data['audioDuration'],
      caption: data['caption'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (audioDuration != null) 'audioDuration': audioDuration,
      if (caption != null && caption!.isNotEmpty) 'caption': caption,
    };
  }
} 