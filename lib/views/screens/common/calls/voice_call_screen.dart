import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../../../../models/chat_room_model.dart';
import '../../../../services/call_service.dart';
import '../../../../utils/agora_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math';

class VoiceCallScreen extends StatefulWidget {
  final ChatRoom chatRoom;
  final bool isDoctor;
  final String currentUserId;

  const VoiceCallScreen({
    Key? key,
    required this.chatRoom,
    required this.isDoctor,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final CallService _callService = CallService();
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnecting = true;
  Set<int> _remoteUids = {};
  
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
    
    await _callService.joinVoiceCall(
      channelName: channelName,
      uid: uid,
      onUserJoined: (int remoteUid) {
        setState(() {
          _remoteUids.add(remoteUid);
          _isConnecting = false;
        });
      },
      onUserLeft: (int remoteUid) {
        setState(() {
          _remoteUids.remove(remoteUid);
          if (_remoteUids.isEmpty) {
            _isConnecting = false;
          }
        });
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
  
  void _toggleSpeaker() {
    _callService.setEnableSpeakerphone(!_isSpeakerOn);
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
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
    
    final Color lightColor = widget.isDoctor 
        ? Color(0xFFFFE6F0) // AppColors.lightPink
        : Color(0xFFE6F7FB); // AppColors.lightTeal
    
    return Scaffold(
      backgroundColor: lightColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 50,
                      child: Icon(
                        widget.isDoctor ? LucideIcons.user : LucideIcons.stethoscope,
                        color: primaryColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      contactName ?? 'User',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnecting 
                          ? 'Connecting...' 
                          : _remoteUids.isEmpty 
                              ? 'Calling...' 
                              : 'In call',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onPressed: _toggleMute,
                    backgroundColor: Colors.grey.shade100,
                    iconColor: _isMuted ? Colors.red : primaryColor,
                  ),
                  _buildControlButton(
                    icon: LucideIcons.phoneOff,
                    label: 'End',
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    iconColor: Colors.white,
                  ),
                  _buildControlButton(
                    icon: _isSpeakerOn ? LucideIcons.volume2 : LucideIcons.volume1,
                    label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
                    onPressed: _toggleSpeaker,
                    backgroundColor: Colors.grey.shade100,
                    iconColor: _isSpeakerOn ? primaryColor : Colors.black,
                  ),
                ],
              ),
            ),
          ],
        ),
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
            elevation: 2,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12),
        ),
      ],
    );
  }
} 