import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:healthcare/utils/app_theme.dart';

// Utility class for responsiveness
class SizeConfig {
  static MediaQueryData? _mediaQueryData;
  static double? screenWidth;
  static double? screenHeight;
  static double? defaultSize;
  static Orientation? orientation;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData!.size.width;
    screenHeight = _mediaQueryData!.size.height;
    orientation = _mediaQueryData!.orientation;
    
    // Default size is calculated based on screen width
    // This provides a way to get relative size values
    defaultSize = orientation == Orientation.landscape
        ? screenHeight! * 0.024
        : screenWidth! * 0.024;
  }
  
  // Get the proportional height according to screen size
  static double getProportionateScreenHeight(double inputHeight) {
    final screenHeight = SizeConfig.screenHeight;
    // 812 is the layout height that designer use
    return (inputHeight / 812.0) * screenHeight!;
  }
  
  // Get the proportional width according to screen size
  static double getProportionateScreenWidth(double inputWidth) {
    final screenWidth = SizeConfig.screenWidth;
    // 375 is the layout width that designer use
    return (inputWidth / 375.0) * screenWidth!;
  }
}

class NursingService {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final double price;
  final String imageUrl;

  NursingService({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.price,
    this.imageUrl = '',
  });
}

class HomeNursingServicesScreen extends StatefulWidget {
  const HomeNursingServicesScreen({Key? key}) : super(key: key);

  @override
  State<HomeNursingServicesScreen> createState() => _HomeNursingServicesScreenState();
}

class _HomeNursingServicesScreenState extends State<HomeNursingServicesScreen> {
  final List<NursingService> _nursingServices = [
    NursingService(
      name: "Wound Dressing",
      description: "Professional wound care and dressing by certified nurses",
      icon: LucideIcons.bandage,
      color: Color(0xFF6A1B9A),
      price: 1500,
    ),
    NursingService(
      name: "Advanced Wound Care",
      description: "Specialized treatment for complex or chronic wounds",
      icon: LucideIcons.scissors,
      color: Color(0xFF1565C0),
      price: 2000,
    ),
    NursingService(
      name: "NG Tube Management",
      description: "Nasogastric tube insertion and care by trained professionals",
      icon: LucideIcons.stethoscope,
      color: Color(0xFF2E7D32),
      price: 3000,
    ),
    NursingService(
      name: "Catheterization",
      description: "Urinary catheter insertion and management at home",
      icon: LucideIcons.thermometer,
      color: Color(0xFFD84315),
      price: 2500,
    ),
    NursingService(
      name: "Physical Therapy",
      description: "Personalized rehabilitation exercises and therapy sessions",
      icon: LucideIcons.activity,
      color: Color(0xFF5E35B1),
      price: 2200,
    ),
    NursingService(
      name: "Blood Collection",
      description: "Professional blood sampling for laboratory tests",
      icon: Icons.bloodtype,
      color: Color(0xFFAD1457),
      price: 1000,
    ),
    NursingService(
      name: "IV Therapy",
      description: "Intravenous medication and fluid administration",
      icon: LucideIcons.droplets,
      color: Color(0xFF00838F),
      price: 2800,
    ),
    NursingService(
      name: "Vital Monitoring",
      description: "Regular monitoring of vital signs by healthcare professionals",
      icon: LucideIcons.heartPulse,
      color: Color(0xFFEF6C00),
      price: 1200,
    ),
  ];

  // Selected service and appointment details
  NursingService? _selectedService;
  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay(hour: 10, minute: 0);
  String? _selectedAddress;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  // User's saved addresses
  List<String> _addresses = [];
  bool _isLoading = true;
  bool _isBookingInProgress = false;
  List<NursingService> _filteredServices = [];
  
  @override
  void initState() {
    super.initState();
    _filteredServices = List.from(_nursingServices);
    _loadUserAddresses();
    
    _searchController.addListener(() {
      _filterServices();
    });
  }
  
  void _filterServices() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredServices = List.from(_nursingServices);
      });
      return;
    }
    
    setState(() {
      _filteredServices = _nursingServices
          .where((service) => service.name
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()) ||
              service.description
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }
  
  Future<void> _loadUserAddresses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data['address'] != null) {
            _addresses = [data['address'].toString()];
            
            // If additional addresses are stored in an array
            if (data['additionalAddresses'] != null) {
              final additionalAddresses = List<String>.from(data['additionalAddresses']);
              _addresses.addAll(additionalAddresses);
            }
            
            // Set the first address as initial value if available
            if (_addresses.isNotEmpty) {
              _addressController.text = _addresses[0];
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading addresses: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryPink,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryPink,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  Future<void> _bookService() async {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a service'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[400],
        )
      );
      return;
    }
    
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your address'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[400],
        )
      );
      return;
    }
    
    // Show confirmation bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: SizeConfig.getProportionateScreenWidth(24),
            right: SizeConfig.getProportionateScreenWidth(24),
            top: SizeConfig.getProportionateScreenWidth(24),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(SizeConfig.getProportionateScreenWidth(24)),
              topRight: Radius.circular(SizeConfig.getProportionateScreenWidth(24)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Booking Summary',
                          style: GoogleFonts.poppins(
                            fontSize: SizeConfig.getProportionateScreenWidth(20),
                            fontWeight: FontWeight.w600,
                            color: _selectedService!.color,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        color: Colors.grey[700],
                        iconSize: SizeConfig.getProportionateScreenWidth(22),
                      ),
                    ],
                  ),
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(20)),
                  
                  // Service details
                  Container(
                    padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16)),
                    decoration: BoxDecoration(
                      color: _selectedService!.color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(12)),
                      border: Border.all(
                        color: _selectedService!.color.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(10)),
                          decoration: BoxDecoration(
                            color: _selectedService!.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _selectedService!.icon,
                            color: _selectedService!.color,
                            size: SizeConfig.getProportionateScreenWidth(24),
                          ),
                        ),
                        SizedBox(width: SizeConfig.getProportionateScreenWidth(16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedService!.name,
                                style: GoogleFonts.poppins(
                                  fontSize: SizeConfig.getProportionateScreenWidth(16),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: SizeConfig.getProportionateScreenHeight(4)),
                              Text(
                                'Rs. ${_selectedService!.price.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: SizeConfig.getProportionateScreenWidth(15),
                                  fontWeight: FontWeight.w600,
                                  color: _selectedService!.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(20)),
                  
                  // Booking details
                  _buildSummaryItem(
                    icon: LucideIcons.calendar,
                    title: 'Date',
                    value: DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    color: _selectedService!.color,
                  ),
                  Divider(height: SizeConfig.getProportionateScreenHeight(24)),
                  
                  _buildSummaryItem(
                    icon: LucideIcons.clock,
                    title: 'Time',
                    value: _selectedTime.format(context),
                    color: _selectedService!.color,
                  ),
                  Divider(height: SizeConfig.getProportionateScreenHeight(24)),
                  
                  _buildSummaryItem(
                    icon: LucideIcons.mapPin,
                    title: 'Location',
                    value: _addressController.text,
                    color: _selectedService!.color,
                  ),
                  
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(30)),
                  
                  // Notes if present
                  if (_notesController.text.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16)),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(8)),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: GoogleFonts.poppins(
                              fontSize: SizeConfig.getProportionateScreenWidth(14),
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: SizeConfig.getProportionateScreenHeight(8)),
                          Text(
                            _notesController.text,
                            style: GoogleFonts.poppins(
                              fontSize: SizeConfig.getProportionateScreenWidth(14),
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: SizeConfig.getProportionateScreenHeight(30)),
                  ],
                  
                  // Payment summary
                  Container(
                    padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16)),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(12)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Service Fee',
                              style: GoogleFonts.poppins(
                                fontSize: SizeConfig.getProportionateScreenWidth(14),
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              'Rs. ${_selectedService!.price.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: SizeConfig.getProportionateScreenWidth(14),
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: SizeConfig.getProportionateScreenHeight(8)),
                        Divider(),
                        SizedBox(height: SizeConfig.getProportionateScreenHeight(8)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: GoogleFonts.poppins(
                                fontSize: SizeConfig.getProportionateScreenWidth(16),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Rs. ${_selectedService!.price.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: SizeConfig.getProportionateScreenWidth(16),
                                fontWeight: FontWeight.w600,
                                color: _selectedService!.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(24)),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: SizeConfig.getProportionateScreenHeight(12)
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(12)),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: SizeConfig.getProportionateScreenWidth(16),
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: SizeConfig.getProportionateScreenWidth(16)),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _processBooking();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedService!.color,
                            padding: EdgeInsets.symmetric(
                              vertical: SizeConfig.getProportionateScreenHeight(12)
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(12)),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Confirm',
                            style: GoogleFonts.poppins(
                              fontSize: SizeConfig.getProportionateScreenWidth(16),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Add bottom padding to account for keyboard and safe area
                  SizedBox(height: MediaQuery.of(context).padding.bottom + SizeConfig.getProportionateScreenHeight(12)),
                ],
              );
            }
          ),
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(8)),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: SizeConfig.getProportionateScreenWidth(18),
          ),
        ),
        SizedBox(width: SizeConfig.getProportionateScreenWidth(16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: SizeConfig.getProportionateScreenWidth(12),
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: SizeConfig.getProportionateScreenWidth(14),
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<void> _processBooking() async {
    setState(() {
      _isBookingInProgress = true;
    });
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Create a new document in nursingBookings collection
      await FirebaseFirestore.instance.collection('nursingBookings').add({
        'patientId': userId,
        'service': _selectedService!.name,
        'price': _selectedService!.price,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'time': '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        'address': _addressController.text,
        'notes': _notesController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Show success dialog
      if (context.mounted) {
        // Show success animation
        _showSuccessDialog();
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        setState(() {
          _isBookingInProgress = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book service: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red[400],
          )
        );
      }
    }
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(20)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: SizeConfig.getProportionateScreenWidth(80),
                    height: SizeConfig.getProportionateScreenWidth(80),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: AppTheme.success,
                      size: SizeConfig.getProportionateScreenWidth(60),
                    ),
                  ),
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(24)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Booking Confirmed!',
                      style: GoogleFonts.poppins(
                        fontSize: SizeConfig.getProportionateScreenWidth(20),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(16)),
                  Text(
                    'Your nursing service has been booked successfully.',
                    style: GoogleFonts.poppins(
                      fontSize: SizeConfig.getProportionateScreenWidth(14),
                      color: AppTheme.darkText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(8)),
                  Text(
                    'Our staff will call you shortly to confirm the appointment.',
                    style: GoogleFonts.poppins(
                      fontSize: SizeConfig.getProportionateScreenWidth(14),
                      color: AppTheme.mediumText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(24)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context); // Return to previous screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedService?.color ?? AppTheme.primaryTeal,
                        padding: EdgeInsets.symmetric(
                          vertical: SizeConfig.getProportionateScreenHeight(12)
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(12)),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.poppins(
                          fontSize: SizeConfig.getProportionateScreenWidth(16),
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      ),
    ).then((_) {
      setState(() {
        _isBookingInProgress = false;
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterServices);
    _searchController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Initialize SizeConfig to provide access to screen dimensions
    SizeConfig.init(context);
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.primaryPink,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: SizeConfig.getProportionateScreenHeight(20)),
                  Text(
                    'Loading services...',
                    style: GoogleFonts.poppins(
                      color: AppTheme.mediumText,
                      fontSize: SizeConfig.getProportionateScreenWidth(16),
                    ),
                  ),
                ],
              ),
            )
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(child: _buildHeroSection()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: SizeConfig.getProportionateScreenWidth(16.0),
                          vertical: SizeConfig.getProportionateScreenHeight(8.0)
                        ),
                        child: _buildSearchBar(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: SizeConfig.getProportionateScreenWidth(20.0), 
                          top: SizeConfig.getProportionateScreenHeight(16.0), 
                          bottom: SizeConfig.getProportionateScreenHeight(12.0)
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Available Services',
                            style: GoogleFonts.poppins(
                              fontSize: SizeConfig.getProportionateScreenWidth(18),
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _selectedService == null
                        ? SliverToBoxAdapter(child: _buildServicesGrid())
                        : SliverToBoxAdapter(
                            child: Column(
                              children: [
                                _buildSelectedServiceCard(),
                                _buildBookingForm(),
                              ],
                            ),
                          ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: SizeConfig.getProportionateScreenHeight(30)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leadingWidth: SizeConfig.getProportionateScreenWidth(48),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppTheme.primaryPink,
          size: SizeConfig.getProportionateScreenWidth(22),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Home Nursing',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryPink,
            fontSize: SizeConfig.getProportionateScreenWidth(20),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            LucideIcons.bell,
            color: AppTheme.primaryPink,
            size: SizeConfig.getProportionateScreenWidth(22),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: SizeConfig.getProportionateScreenWidth(8),
          ),
          onPressed: () {},
        ),
      ],
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.getProportionateScreenWidth(12), 
        vertical: SizeConfig.getProportionateScreenHeight(6)
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: AppTheme.mediumText,
            size: SizeConfig.getProportionateScreenWidth(20),
          ),
          SizedBox(width: SizeConfig.getProportionateScreenWidth(10)),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(
                fontSize: SizeConfig.getProportionateScreenWidth(16),
              ),
              decoration: InputDecoration(
                hintText: 'Search nursing services...',
                hintStyle: GoogleFonts.poppins(
                  color: AppTheme.lightText,
                  fontSize: SizeConfig.getProportionateScreenWidth(16),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: SizeConfig.getProportionateScreenHeight(12)
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
              },
              child: Icon(
                Icons.close,
                color: AppTheme.mediumText,
                size: SizeConfig.getProportionateScreenWidth(20),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildServicesGrid() {
    if (_filteredServices.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(
          vertical: SizeConfig.getProportionateScreenHeight(40), 
          horizontal: SizeConfig.getProportionateScreenWidth(20)
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: SizeConfig.getProportionateScreenWidth(60),
              color: AppTheme.lightText,
            ),
            SizedBox(height: SizeConfig.getProportionateScreenHeight(16)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'No services found',
                style: GoogleFonts.poppins(
                  fontSize: SizeConfig.getProportionateScreenWidth(18),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mediumText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: SizeConfig.getProportionateScreenHeight(8)),
            Text(
              'Try different search terms or browse all services',
              style: GoogleFonts.poppins(
                fontSize: SizeConfig.getProportionateScreenWidth(14),
                color: AppTheme.mediumText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.getProportionateScreenWidth(16.0)
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine number of grid columns based on screen width
          final double availableWidth = constraints.maxWidth;
          final int crossAxisCount = availableWidth > 600 ? 3 : 2;
          final double childAspectRatio = availableWidth > 600 ? 0.85 : 0.75;
          
          return GridView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: SizeConfig.getProportionateScreenWidth(15),
              mainAxisSpacing: SizeConfig.getProportionateScreenHeight(15),
            ),
            itemCount: _filteredServices.length,
            itemBuilder: (context, index) {
              final service = _filteredServices[index];
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedService = service;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(16)),
                    boxShadow: [
                      BoxShadow(
                        color: service.color.withOpacity(0.1),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service image area with icon
                      AspectRatio(
                        aspectRatio: 16/9,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                service.color.withOpacity(0.8),
                                service.color,
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(SizeConfig.getProportionateScreenWidth(16)),
                              topRight: Radius.circular(SizeConfig.getProportionateScreenWidth(16)),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              service.icon,
                              color: Colors.white,
                              size: SizeConfig.getProportionateScreenWidth(50),
                            ),
                          ),
                        ),
                      ),
                      
                      // Service details
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(12.0)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: GoogleFonts.poppins(
                                  fontSize: SizeConfig.getProportionateScreenWidth(16),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: SizeConfig.getProportionateScreenHeight(4)),
                              Expanded(
                                child: Text(
                                  service.description,
                                  style: GoogleFonts.poppins(
                                    fontSize: SizeConfig.getProportionateScreenWidth(12),
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Rs. ${service.price.toStringAsFixed(0)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: SizeConfig.getProportionateScreenWidth(16),
                                        fontWeight: FontWeight.w600,
                                        color: service.color,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(5)),
                                    decoration: BoxDecoration(
                                      color: service.color.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: service.color,
                                      size: SizeConfig.getProportionateScreenWidth(14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
      ),
    );
  }
  
  Widget _buildBookingForm() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        SizeConfig.getProportionateScreenWidth(16), 
        0, 
        SizeConfig.getProportionateScreenWidth(16), 
        SizeConfig.getProportionateScreenWidth(16)
      ),
      padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final isWideScreen = maxWidth > 600;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Schedule Your Service',
                  style: GoogleFonts.poppins(
                    fontSize: SizeConfig.getProportionateScreenWidth(18),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: SizeConfig.getProportionateScreenHeight(20)),
              
              // Date and time selection
              Text(
                'When do you need this service?',
                style: GoogleFonts.poppins(
                  fontSize: SizeConfig.getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: SizeConfig.getProportionateScreenHeight(12)),
              
              Container(
                padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16)),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(12)),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(8)),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: SizeConfig.getProportionateScreenWidth(16), 
                                vertical: SizeConfig.getProportionateScreenHeight(12)
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(8)),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.calendar,
                                    color: _selectedService?.color ?? AppTheme.primaryTeal,
                                    size: SizeConfig.getProportionateScreenWidth(20),
                                  ),
                                  SizedBox(width: SizeConfig.getProportionateScreenWidth(10)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Date',
                                          style: GoogleFonts.poppins(
                                            fontSize: SizeConfig.getProportionateScreenWidth(12),
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            DateFormat('EEE, MMM d').format(_selectedDate),
                                            style: GoogleFonts.poppins(
                                              fontSize: SizeConfig.getProportionateScreenWidth(14),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: SizeConfig.getProportionateScreenWidth(12)),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(context),
                            borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(8)),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: SizeConfig.getProportionateScreenWidth(16), 
                                vertical: SizeConfig.getProportionateScreenHeight(12)
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(8)),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.clock,
                                    color: _selectedService?.color ?? AppTheme.primaryTeal,
                                    size: SizeConfig.getProportionateScreenWidth(20),
                                  ),
                                  SizedBox(width: SizeConfig.getProportionateScreenWidth(10)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Time',
                                          style: GoogleFonts.poppins(
                                            fontSize: SizeConfig.getProportionateScreenWidth(12),
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _selectedTime.format(context),
                                            style: GoogleFonts.poppins(
                                              fontSize: SizeConfig.getProportionateScreenWidth(14),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: SizeConfig.getProportionateScreenHeight(24)),
              
              // Address selection
              Text(
                'Where do you need the service?',
                style: GoogleFonts.poppins(
                  fontSize: SizeConfig.getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: SizeConfig.getProportionateScreenHeight(12)),
              
              if (_addresses.isEmpty)
                Container(
                  padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16)),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(8)),
                    border: Border.all(color: Color(0xFFFFE0B2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Color(0xFFE65100),
                        size: SizeConfig.getProportionateScreenWidth(20),
                      ),
                      SizedBox(width: SizeConfig.getProportionateScreenWidth(12)),
                      Expanded(
                        child: Text(
                          'No addresses found. Please update your profile with your address.',
                          style: GoogleFonts.poppins(
                            color: Color(0xFFE65100),
                            fontSize: SizeConfig.getProportionateScreenWidth(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.getProportionateScreenWidth(16), 
                    vertical: SizeConfig.getProportionateScreenHeight(5)
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(8)),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _addressController,
                    style: GoogleFonts.poppins(
                      fontSize: SizeConfig.getProportionateScreenWidth(14),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your full address',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[400],
                        fontSize: SizeConfig.getProportionateScreenWidth(14),
                      ),
                      helperText: 'Include street, building, city and postcode',
                      helperStyle: GoogleFonts.poppins(
                        fontSize: SizeConfig.getProportionateScreenWidth(12),
                        color: Colors.grey[600],
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        LucideIcons.mapPin,
                        color: _selectedService?.color ?? AppTheme.primaryTeal,
                        size: SizeConfig.getProportionateScreenWidth(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: SizeConfig.getProportionateScreenHeight(12)
                      ),
                    ),
                  ),
                ),
              
              SizedBox(height: SizeConfig.getProportionateScreenHeight(24)),
              
              // Additional notes
              Text(
                'Additional Notes',
                style: GoogleFonts.poppins(
                  fontSize: SizeConfig.getProportionateScreenWidth(15),
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: SizeConfig.getProportionateScreenHeight(12)),
              
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SizeConfig.getProportionateScreenWidth(16), 
                  vertical: SizeConfig.getProportionateScreenHeight(5)
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(8)),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _notesController,
                  style: GoogleFonts.poppins(
                    fontSize: SizeConfig.getProportionateScreenWidth(14),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Any specific requirements or conditions...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: SizeConfig.getProportionateScreenWidth(14),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: SizeConfig.getProportionateScreenHeight(12)
                    ),
                  ),
                  maxLines: 3,
                ),
              ),
              
              SizedBox(height: SizeConfig.getProportionateScreenHeight(32)),
              
              // Book button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isBookingInProgress ? null : _bookService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedService?.color ?? AppTheme.primaryTeal,
                    padding: EdgeInsets.symmetric(
                      vertical: SizeConfig.getProportionateScreenHeight(16)
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(12)),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isBookingInProgress
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: SizeConfig.getProportionateScreenWidth(20),
                              height: SizeConfig.getProportionateScreenWidth(20),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                            SizedBox(width: SizeConfig.getProportionateScreenWidth(12)),
                            Text(
                              'Processing...',
                              style: GoogleFonts.poppins(
                                fontSize: SizeConfig.getProportionateScreenWidth(16),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Book Now',
                          style: GoogleFonts.poppins(
                            fontSize: SizeConfig.getProportionateScreenWidth(16),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              
              SizedBox(height: SizeConfig.getProportionateScreenHeight(8)),
              
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedService = null;
                    });
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: SizeConfig.getProportionateScreenWidth(14),
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        SizeConfig.getProportionateScreenWidth(16), 
        SizeConfig.getProportionateScreenHeight(12), 
        SizeConfig.getProportionateScreenWidth(16), 
        SizeConfig.getProportionateScreenHeight(16)
      ),
      height: SizeConfig.getProportionateScreenHeight(180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryPink,
            AppTheme.primaryTeal,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth;
          final double maxHeight = constraints.maxHeight;
          
          return Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -maxHeight * 0.15,
                right: -maxWidth * 0.08,
                child: Container(
                  width: maxWidth * 0.25,
                  height: maxWidth * 0.25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -maxHeight * 0.2,
                left: -maxWidth * 0.05,
                child: Container(
                  width: maxWidth * 0.3,
                  height: maxWidth * 0.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(20.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Professional Care',
                                  style: GoogleFonts.poppins(
                                    fontSize: SizeConfig.getProportionateScreenWidth(24),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'At Your Doorstep',
                                  style: GoogleFonts.poppins(
                                    fontSize: SizeConfig.getProportionateScreenWidth(20),
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                              SizedBox(height: SizeConfig.getProportionateScreenHeight(12)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: SizeConfig.getProportionateScreenWidth(12), 
                                  vertical: SizeConfig.getProportionateScreenHeight(6)
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(30)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield,
                                      color: Colors.white,
                                      size: SizeConfig.getProportionateScreenWidth(16),
                                    ),
                                    SizedBox(width: SizeConfig.getProportionateScreenWidth(6)),
                                    Text(
                                      'Licensed Professionals',
                                      style: GoogleFonts.poppins(
                                        fontSize: SizeConfig.getProportionateScreenWidth(12),
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: SizeConfig.getProportionateScreenWidth(70),
                          height: SizeConfig.getProportionateScreenWidth(70),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              LucideIcons.heartPulse,
                              color: Colors.white,
                              size: SizeConfig.getProportionateScreenWidth(36),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSelectedServiceCard() {
    if (_selectedService == null) return SizedBox();
    
    return Container(
      margin: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Padding(
            padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16.0)),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedService = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(30)),
                  child: Container(
                    padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(8)),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      size: SizeConfig.getProportionateScreenWidth(20),
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(width: SizeConfig.getProportionateScreenWidth(12)),
                Text(
                  'Selected Service',
                  style: GoogleFonts.poppins(
                    fontSize: SizeConfig.getProportionateScreenWidth(18),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // Service details
          Container(
            padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16)),
            margin: EdgeInsets.symmetric(
              horizontal: SizeConfig.getProportionateScreenWidth(16)
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _selectedService!.color.withOpacity(0.8),
                  _selectedService!.color,
                ],
              ),
              borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(SizeConfig.getProportionateScreenWidth(16)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedService!.icon,
                    color: Colors.white,
                    size: SizeConfig.getProportionateScreenWidth(30),
                  ),
                ),
                SizedBox(width: SizeConfig.getProportionateScreenWidth(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedService!.name,
                        style: GoogleFonts.poppins(
                          fontSize: SizeConfig.getProportionateScreenWidth(18),
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: SizeConfig.getProportionateScreenHeight(4)),
                      Text(
                        _selectedService!.description,
                        style: GoogleFonts.poppins(
                          fontSize: SizeConfig.getProportionateScreenWidth(14),
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      SizedBox(height: SizeConfig.getProportionateScreenHeight(8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: SizeConfig.getProportionateScreenWidth(12), 
                          vertical: SizeConfig.getProportionateScreenHeight(6)
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(SizeConfig.getProportionateScreenWidth(20)),
                        ),
                        child: Text(
                          'Rs. ${_selectedService!.price.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: SizeConfig.getProportionateScreenWidth(14),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: SizeConfig.getProportionateScreenHeight(16)),
        ],
      ),
    );
  }
} 