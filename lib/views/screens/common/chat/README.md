# Doctor-Patient Chat Implementation

This directory contains the implementation of the chat feature between doctors and patients for the appointment booking app.

## Architecture

The chat system uses Firestore for messaging, which keeps the app size minimal while providing real-time communication capabilities. Voice and video calls are planned to use Agora.

## Components

1. **Models**:
   - `ChatMessage`: Represents a single message (text, image, audio, document)
   - `ChatRoom`: Represents a conversation between a doctor and patient

2. **Services**:
   - `ChatService`: Handles all Firebase operations for messaging (sending/receiving messages, creating rooms, etc.)

3. **UI Components**:
   - `ChatListScreen`: Displays all conversations for a user
   - `ChatDetailScreen`: Shows the individual chat conversation with message history

## Implementation Details

### Data Storage

Messages are stored in Firestore with the following structure:
- `chatRooms` collection: Contains all chat rooms
  - Each chat room has a subcollection `messages` containing all messages

### Media Handling

- Images are uploaded to Firebase Storage in the `chat_images` folder
- Audio messages are stored in the `chat_audio` folder
- Documents are stored in the `chat_documents` folder

### Real-time Updates

- The chat uses Firestore streams to provide real-time message updates
- Unread message counts are tracked per user in each chat room

### Audio Recording

For a production implementation, the `record` package should be properly configured with the correct parameters. The current implementation simulates recording to avoid package-specific issues during development.

### Voice & Video Calls

Agora will be used for voice and video calls, with the configuration in `utils/agora_config.dart`. You'll need to:
1. Add your Agora App ID
2. Implement proper token generation
3. Complete the call functionality in a real deployment

## Next Steps

1. Complete the audio recording implementation with the appropriate package configuration
2. Integrate the Agora SDK for voice and video calls
3. Implement push notifications for new messages
4. Add message deletion and editing features
5. Implement message search functionality 