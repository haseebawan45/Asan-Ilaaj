import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../../../../models/chat_room_model.dart';
import '../../../../services/call_service.dart';
import '../../../../utils/agora_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math';

class VideoCallScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final bool isDoctor;
  final String currentUserId;

  const VideoCallScreen({
    Key? key,
    required this.chatRoom,
    required this.isDoctor,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isConnecting = true;
  Set<int> _remoteUids = {};
  int? _remoteUid;

  // Create local video renderer
  final _localRenderer = const SizedBox();
  // Create remote video renderer
  final _remoteRenderer = const SizedBox();
  
  @override
  void initState() {
    super.initState();
    _initializeCall();
  }
  
  Future<void> _initializeCall() async {
    final channelName = AgoraConfig.createChannelName(
      widget.chatRoom.doctorId,
      widget.chatRoom.patientId,
    );
    
    // Use the last 5 digits of the userId as a simple integer uid
    final uidStr = widget.currentUserId.replaceAll(RegExp(r'[^0-9]'), '');
    final uid = int.parse(uidStr.substring(max(0, uidStr.length - 5)));
    
    await _callService.joinVideoCall(
      channelName: channelName,
      uid: uid,
      onUserJoined: (int remoteUid) {
        setState(() {
          _remoteUids.add(remoteUid);
          _remoteUid = remoteUid;
          _isConnecting = false;
        });
      },
      onUserLeft: (int remoteUid) {
        setState(() {
          _remoteUids.remove(remoteUid);
          if (_remoteUids.isEmpty) {
            _remoteUid = null;
            _isConnecting = false;
          }
        });
      },
      onRemoteVideoStateChanged: (state, reason, uid) {
        // Handle remote video state changes
      },
    );
    
    setState(() {
      _isJoined = true;
    });
  }
  
  void _toggleMute() {
    _callService.muteLocalAudioStream(!_isMuted);
    setState(() {
      _isMuted = !_isMuted;
    });
  }
  
  void _toggleCamera() {
    _callService.enableLocalVideo(!_isCameraOff);
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
  }
  
  void _switchCamera() {
    _callService.switchCamera();
  }
  
  void _endCall() {
    _callService.leaveCall();
    Navigator.pop(context);
  }
  
  @override
  void dispose() {
    _callService.leaveCall();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final contactName = widget.isDoctor 
        ? widget.chatRoom.patientName 
        : widget.chatRoom.doctorName;
    
    // Use the same colors as defined in chat screens
    final Color primaryColor = widget.isDoctor 
        ? Color(0xFFFF3F80) // AppColors.primaryPink
        : Color(0xFF30A9C7); // AppColors.primaryTeal
    
    return Scaffold(
      body: Stack(
        children: [
          // This would be the actual video views
          // For simplicity, we'll use placeholders here
          // In a real implementation, replace with AgoraVideoView widgets
          if (_remoteUid != null)
            Container(
              color: Colors.black,
              child: Center(
                child: Text(
                  'Remote Video',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          else
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      radius: 50,
                      child: Icon(
                        widget.isDoctor ? LucideIcons.user : LucideIcons.stethoscope,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      contactName ?? 'User',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _isConnecting 
                          ? 'Connecting...' 
                          : _remoteUids.isEmpty 
                              ? 'Calling...' 
                              : 'In call',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Local video view (would be small overlay box)
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: _isCameraOff
                  ? Center(
                      child: Icon(
                        LucideIcons.videoOff,
                        color: Colors.white70,
                      ),
                    )
                  : Center(
                      child: Text(
                        'Local Video',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ),
          
          // Control buttons at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onPressed: _toggleMute,
                    backgroundColor: _isMuted 
                        ? Colors.white24 
                        : Colors.white24,
                    iconColor: _isMuted ? Colors.red : Colors.white,
                  ),
                  _buildControlButton(
                    icon: LucideIcons.phoneOff,
                    label: 'End',
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    iconColor: Colors.white,
                  ),
                  _buildControlButton(
                    icon: _isCameraOff ? LucideIcons.videoOff : LucideIcons.video,
                    label: _isCameraOff ? 'Camera On' : 'Camera Off',
                    onPressed: _toggleCamera,
                    backgroundColor: Colors.white24,
                    iconColor: _isCameraOff ? Colors.red : Colors.white,
                  ),
                  _buildControlButton(
                    icon: LucideIcons.switchCamera,
                    label: 'Switch',
                    onPressed: _switchCamera,
                    backgroundColor: Colors.white24,
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          
          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: backgroundColor,
            elevation: 0,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
} 