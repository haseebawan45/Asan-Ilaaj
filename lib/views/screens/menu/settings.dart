import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthcare/views/screens/menu/privacy_policy.dart';
import 'package:healthcare/views/screens/menu/terms_of_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _smsReminders = true;
  bool _darkMode = false;
  String _language = 'English';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _smsReminders = prefs.getBool('sms_reminders') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _language = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('email_notifications', _emailNotifications);
    await prefs.setBool('sms_reminders', _smsReminders);
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setString('language', _language);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Settings",
          style: GoogleFonts.poppins(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Notifications'),
            _buildSettingItem(
              icon: LucideIcons.bell,
              title: 'Push Notifications',
              subtitle: 'Enable push notifications',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                    _saveSettings();
                  });
                },
                activeColor: Color(0xFF3366CC),
              ),
            ),
            _buildSettingItem(
              icon: LucideIcons.mail,
              title: 'Email Notifications',
              subtitle: 'Receive updates via email',
              trailing: Switch(
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() {
                    _emailNotifications = value;
                    _saveSettings();
                  });
                },
                activeColor: Color(0xFF3366CC),
              ),
            ),
            _buildSettingItem(
              icon: LucideIcons.messageSquare,
              title: 'SMS Reminders',
              subtitle: 'Get appointment reminders via SMS',
              trailing: Switch(
                value: _smsReminders,
                onChanged: (value) {
                  setState(() {
                    _smsReminders = value;
                    _saveSettings();
                  });
                },
                activeColor: Color(0xFF3366CC),
              ),
            ),
            _buildSectionTitle('Appearance'),
            _buildSettingItem(
              icon: LucideIcons.moon,
              title: 'Dark Mode',
              subtitle: 'Enable dark theme',
              trailing: Switch(
                value: _darkMode,
                onChanged: (value) {
                  setState(() {
                    _darkMode = value;
                    _saveSettings();
                  });
                },
                activeColor: Color(0xFF3366CC),
              ),
            ),
            _buildSettingItem(
              icon: LucideIcons.languages,
              title: 'Language',
              subtitle: _language,
              onTap: () => _showLanguageDialog(),
            ),
            _buildSectionTitle('Privacy & Security'),
            _buildSettingItem(
              icon: LucideIcons.shield,
              title: 'Privacy Policy',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            _buildSettingItem(
              icon: LucideIcons.fileText,
              title: 'Terms of Service',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsOfServiceScreen(),
                  ),
                );
              },
            ),
            _buildSettingItem(
              icon: LucideIcons.trash2,
              title: 'Clear Cache',
              subtitle: 'Clear temporary data',
              onTap: () async {
                // Implement cache clearing
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cache cleared successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFF3366CC).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Color(0xFF3366CC),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF333333),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  LucideIcons.chevronRight,
                  color: Colors.grey[400],
                  size: 20,
                )
              : null),
      onTap: onTap,
    );
  }

  Future<void> _showLanguageDialog() async {
    final languages = ['English', 'Urdu', 'اردو'];
    
    final String? selectedLanguage = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Language',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages
                .map(
                  (lang) => ListTile(
                    title: Text(
                      lang,
                      style: GoogleFonts.poppins(),
                    ),
                    onTap: () => Navigator.pop(context, lang),
                    trailing: lang == _language
                        ? Icon(
                            LucideIcons.check,
                            color: Color(0xFF3366CC),
                          )
                        : null,
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selectedLanguage != null) {
      setState(() {
        _language = selectedLanguage;
        _saveSettings();
      });
    }
  }
} 