/// This file will handle Agora configuration for voice and video calls
/// You'll need to add your own Agora App ID and generate temp tokens
/// For a production app, you should generate tokens on your server

class AgoraConfig {
  // Replace with your Agora App ID
  static const String appId = '231a9a726f634546b766da5f51886a11';
  
  // In production, generate tokens on your server
  // For testing, you can generate temp tokens from Agora Console
  static String generateToken({
    required String channelName,
    required String uid,
  }) {
    // In a real implementation, you would call your backend to generate a token
    // For now, this is just a placeholder
    return '';
  }
  
  // Helper to create a unique channel name for a chat between doctor and patient
  static String createChannelName(String doctorId, String patientId) {
    // Create a consistent channel name regardless of who initiates the call
    final List<String> ids = [doctorId, patientId];
    ids.sort(); // Sort to ensure same channel name regardless of order
    return 'channel_${ids[0]}_${ids[1]}';
  }
} 