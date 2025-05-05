import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../utils/agora_config.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  RtcEngine? _engine;
  bool _initialized = false;

  Future<bool> initializeEngine() async {
    if (_initialized) return true;
    
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
      ));
      _initialized = true;
      return true;
    } catch (e) {
      print('Error initializing Agora: $e');
      return false;
    }
  }

  Future<void> joinVoiceCall({
    required String channelName,
    required int uid,
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserLeft,
  }) async {
    await _requestPermissions(isVideo: false);
    
    if (!await initializeEngine()) return;
    
    // Configure for audio call
    await _engine!.enableAudio();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    
    // Register event handlers
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        onUserJoined(remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        onUserLeft(remoteUid);
      },
      onLeaveChannel: (connection, stats) {},
    ));
    
    // Join channel
    await _engine!.joinChannel(
      token: AgoraConfig.generateToken(
        channelName: channelName,
        uid: uid.toString(),
      ),
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> joinVideoCall({
    required String channelName,
    required int uid,
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserLeft,
    required Function(RemoteVideoState state, RemoteVideoStateReason reason, int uid) onRemoteVideoStateChanged,
  }) async {
    await _requestPermissions(isVideo: true);
    
    if (!await initializeEngine()) return;
    
    // Configure for video call
    await _engine!.enableVideo();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    
    // Register event handlers
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        onUserJoined(remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        onUserLeft(remoteUid);
      },
      onLeaveChannel: (connection, stats) {},
      onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
        onRemoteVideoStateChanged(state, reason, remoteUid);
      },
    ));
    
    // Join channel
    await _engine!.joinChannel(
      token: AgoraConfig.generateToken(
        channelName: channelName,
        uid: uid.toString(),
      ),
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }
  
  // Audio control methods
  Future<void> muteLocalAudioStream(bool mute) async {
    if (_engine != null) {
      await _engine!.muteLocalAudioStream(mute);
    }
  }
  
  Future<void> setEnableSpeakerphone(bool enable) async {
    if (_engine != null) {
      await _engine!.setEnableSpeakerphone(enable);
    }
  }

  // Video control methods
  Future<void> enableLocalVideo(bool enable) async {
    if (_engine != null) {
      await _engine!.enableLocalVideo(enable);
    }
  }
  
  Future<void> switchCamera() async {
    if (_engine != null) {
      await _engine!.switchCamera();
    }
  }

  Future<void> leaveCall() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
    }
  }

  Future<void> _requestPermissions({required bool isVideo}) async {
    await Permission.microphone.request();
    if (isVideo) {
      await Permission.camera.request();
    }
  }

  void dispose() {
    if (_engine != null) {
      _engine!.release();
      _engine = null;
      _initialized = false;
    }
  }
} 