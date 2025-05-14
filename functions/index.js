const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Send chat notification when a new message is added
exports.sendChatNotification = functions.firestore
  .document('chatRooms/{roomId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const roomId = context.params.roomId;
      
      // If there's no recipient, exit
      if (!messageData.receiverId) {
        console.log('No receiver ID found in message');
        return null;
      }

      // Get the chat room document
      const roomSnapshot = await admin.firestore().collection('chatRooms').doc(roomId).get();
      
      if (!roomSnapshot.exists) {
        console.log('Chat room not found');
        return null;
      }
      
      const roomData = roomSnapshot.data();
      
      // Determine if sender is doctor or patient
      const isSenderDoctor = messageData.senderId === roomData.doctorId;
      
      // Get sender name
      const senderName = isSenderDoctor ? roomData.doctorName : roomData.patientName;
      
      // Get FCM token for recipient
      const tokenDoc = await admin.firestore()
        .collection('userTokens')
        .doc(messageData.receiverId)
        .get();
        
      if (!tokenDoc.exists || !tokenDoc.data().token) {
        console.log('No token found for user:', messageData.receiverId);
        return null;
      }
      
      const token = tokenDoc.data().token;
      
      // Prepare notification message
      let body;
      switch (messageData.type) {
        case 'text':
          body = messageData.content;
          break;
        case 'image':
          body = messageData.caption
            ? `Photo: ${messageData.caption}`
            : 'Sent you a photo';
          break;
        case 'audio':
          body = 'Sent you a voice message';
          break;
        case 'document':
          body = `Sent you a document: ${messageData.content}`;
          break;
        default:
          body = 'New message';
      }
      
      // Limit notification text length
      if (body.length > 100) {
        body = body.substring(0, 97) + '...';
      }
      
      // Create notification message
      const payload = {
        notification: {
          title: senderName,
          body: body,
          sound: 'default',
        },
        data: {
          chatRoomId: roomId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          messageType: messageData.type,
          senderId: messageData.senderId
        },
      };
      
      // Send notification
      const response = await admin.messaging().sendToDevice(token, payload);
      
      console.log('Notification sent successfully:', response);
      return null;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

// Update user online status when they login/logout
exports.updateOnlineStatus = functions.database
  .ref('/userStatus/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const newStatus = change.after.val();
    
    if (!newStatus) {
      return null;
    }
    
    // Get all chatrooms for this user (either as doctor or patient)
    const chatRooms = await admin.firestore()
      .collection('chatRooms')
      .where('doctorId', '==', userId)
      .get();
      
    const chatRooms2 = await admin.firestore()
      .collection('chatRooms')
      .where('patientId', '==', userId)
      .get();
    
    const batch = admin.firestore().batch();
    
    // Update doctor status
    chatRooms.forEach(doc => {
      batch.update(doc.ref, { 
        isDoctorOnline: newStatus.isOnline,
        doctorLastSeen: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    // Update patient status
    chatRooms2.forEach(doc => {
      batch.update(doc.ref, { 
        isPatientOnline: newStatus.isOnline,
        patientLastSeen: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    return batch.commit();
  }); 