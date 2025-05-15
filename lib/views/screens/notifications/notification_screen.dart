import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/utils/ui_helper.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    // Register observer to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Apply status bar style immediately
    UIHelper.applyPinkStatusBar();
    
    // Add post-frame callback to apply the style after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UIHelper.applyPinkStatusBar();
    });
    
    _loadNotifications();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes from background, ensure status bar is correct
    if (state == AppLifecycleState.resumed) {
      UIHelper.applyPinkStatusBar();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Apply status bar style when dependencies change
    UIHelper.applyPinkStatusBar();
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user type from Firestore
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final String userType = userDoc.data()?['type'] ?? 'Patient';

      // Query notifications based on user type and ID
      final QuerySnapshot notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> notifications = [];
      for (var doc in notificationsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        notifications.add({
          'id': doc.id,
          'title': data['title'] ?? 'Notification',
          'message': data['message'] ?? '',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'type': data['type'] ?? 'general',
          'isRead': data['isRead'] ?? false,
        });
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'appointment':
        return AppTheme.primaryTeal;
      case 'payment':
        return AppTheme.success;
      case 'reminder':
        return AppTheme.warning;
      case 'alert':
        return AppTheme.error;
      default:
        return AppTheme.mediumText;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'appointment':
        return Icons.calendar_today;
      case 'payment':
        return Icons.payment;
      case 'reminder':
        return Icons.alarm;
      case 'alert':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply pink status bar on every build
    UIHelper.applyPinkStatusBar();
    
    return UIHelper.ensureStatusBarStyle(
      style: UIHelper.pinkStatusBarStyle,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              // Custom app bar with gradient
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPink.withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Notifications",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    GestureDetector(
                      onTap: _loadNotifications,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _isLoading
                ? Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPink,
                      ),
                    ),
                  )
                : _notifications.isEmpty
                    ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No notifications yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: AppTheme.mediumText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'You\'ll see your notifications here',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppTheme.lightText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: AppTheme.primaryPink,
                          child: ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notification = _notifications[index];
                              final timestamp = notification['timestamp'] as Timestamp;
                              final DateTime date = timestamp.toDate();
                              final bool isToday = DateTime.now().difference(date).inDays == 0;
                              final String formattedDate = isToday
                                  ? 'Today ${DateFormat('h:mm a').format(date)}'
                                  : DateFormat('MMM d, h:mm a').format(date);

                              return Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () => _markAsRead(notification['id']),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        if (!notification['isRead'])
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryPink,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: _getNotificationColor(notification['type'])
                                                      .withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  _getNotificationIcon(notification['type']),
                                                  color: _getNotificationColor(notification['type']),
                                                  size: 24,
                                                ),
                                              ),
                                              SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      notification['title'],
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.darkText,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      notification['message'],
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        color: AppTheme.mediumText,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      formattedDate,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color: AppTheme.lightText,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }
} 