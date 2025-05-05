import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String doctorId;
  final String patientId;
  final DateTime createdAt;
  final DateTime? lastMessageTime;
  final String? lastMessageText;
  final String doctorName;
  final String patientName;
  final String doctorProfilePic;
  final String patientProfilePic;
  final bool isActive;
  final Map<String, int> unreadCount;
  final bool isDoctorOnline;
  final bool isPatientOnline;
  final DateTime? doctorLastSeen;
  final DateTime? patientLastSeen;

  ChatRoom({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.createdAt,
    this.lastMessageTime,
    this.lastMessageText,
    required this.doctorName,
    required this.patientName,
    required this.doctorProfilePic,
    required this.patientProfilePic,
    this.isActive = true,
    required this.unreadCount,
    this.isDoctorOnline = false,
    this.isPatientOnline = false,
    this.doctorLastSeen,
    this.patientLastSeen,
  });

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    Map<String, int> unreadMap = {};
    if (data['unreadCount'] != null) {
      (data['unreadCount'] as Map<String, dynamic>).forEach((key, value) {
        unreadMap[key] = value as int;
      });
    }
    
    return ChatRoom(
      id: doc.id,
      doctorId: data['doctorId'] ?? '',
      patientId: data['patientId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessageTime: data['lastMessageTime'] != null 
          ? (data['lastMessageTime'] as Timestamp).toDate() 
          : null,
      lastMessageText: data['lastMessageText'],
      doctorName: data['doctorName'] ?? '',
      patientName: data['patientName'] ?? '',
      doctorProfilePic: data['doctorProfilePic'] ?? '',
      patientProfilePic: data['patientProfilePic'] ?? '',
      isActive: data['isActive'] ?? true,
      unreadCount: unreadMap,
      isDoctorOnline: data['isDoctorOnline'] ?? false,
      isPatientOnline: data['isPatientOnline'] ?? false,
      doctorLastSeen: data['doctorLastSeen'] != null 
          ? (data['doctorLastSeen'] as Timestamp).toDate() 
          : null,
      patientLastSeen: data['patientLastSeen'] != null 
          ? (data['patientLastSeen'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'doctorId': doctorId,
      'patientId': patientId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'lastMessageText': lastMessageText,
      'doctorName': doctorName,
      'patientName': patientName,
      'doctorProfilePic': doctorProfilePic,
      'patientProfilePic': patientProfilePic,
      'isActive': isActive,
      'unreadCount': unreadCount,
      'isDoctorOnline': isDoctorOnline,
      'isPatientOnline': isPatientOnline,
      'doctorLastSeen': doctorLastSeen != null ? Timestamp.fromDate(doctorLastSeen!) : null,
      'patientLastSeen': patientLastSeen != null ? Timestamp.fromDate(patientLastSeen!) : null,
    };
  }
} 