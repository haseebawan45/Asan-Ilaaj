import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:healthcare/services/admin_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

// Admin theme colors - copied from admin_dashboard.dart for consistency
class AdminTheme {
  static const Color primaryPurple = Color(0xFF6200EA);
  static const Color lightPurple = Color(0xFFB388FF);
  static const Color accentPurple = Color(0xFF9D46FF);
  static const Color darkPurple = Color(0xFF4A148C);
  
  static LinearGradient primaryGradient = LinearGradient(
    colors: [darkPurple, primaryPurple, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppointmentManagement extends StatefulWidget {
  const AppointmentManagement({Key? key}) : super(key: key);

  @override
  State<AppointmentManagement> createState() => _AppointmentManagementState();
}

class _AppointmentManagementState extends State<AppointmentManagement> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Filter values
  String _selectedStatusFilter = 'All';
  String _selectedDoctorFilter = 'All Doctors';
  DateTimeRange? _selectedDateRange;
  
  // Service and data
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  StreamSubscription? _appointmentSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _setupAppointmentListener();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _appointmentSubscription?.cancel();
    super.dispose();
  }
  
  // Set up real-time appointment updates
  void _setupAppointmentListener() {
    try {
      final stream = FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('appointmentDate', descending: true)
          .limit(100)
          .snapshots();
          
      _appointmentSubscription = stream.listen(
        (snapshot) {
          if (!mounted) return;
          
          // Only refresh if we're not already loading
          if (!_isLoading) {
            _loadAppointments();
          }
        },
        onError: (error) {
          debugPrint('Error in appointment listener: $error');
        },
      );
    } catch (e) {
      debugPrint('Error setting up appointment listener: $e');
    }
  }
  
  // Load appointments from AdminService
  Future<void> _loadAppointments() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      debugPrint('📅 Starting to load appointments from Firestore...');
      final appointments = await _adminService.getAllAppointments();
      debugPrint('📅 Successfully loaded ${appointments.length} appointments');
      
      if (appointments.isNotEmpty) {
        debugPrint('Sample appointment: ${appointments.first}');
      }
      
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading appointments: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load appointments: ${e.toString()}';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }
  
  // Refresh appointments
  Future<void> _refreshAppointments() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Clear cache to force fresh data
      _adminService.clearAllCaches();
      await _loadAppointments();
    } catch (e) {
      debugPrint('Error refreshing appointments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing appointments: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
  
  // Filtered appointments based on search and filters
  List<Map<String, dynamic>> get filteredAppointments {
    return _appointments.where((appointment) {
      // Apply status filter
      if (_selectedStatusFilter != 'All' && 
          appointment['status'] != _selectedStatusFilter) {
        return false;
      }
      
      // Apply doctor filter
      if (_selectedDoctorFilter != 'All Doctors' && 
          appointment['doctorName'] != _selectedDoctorFilter) {
        return false;
      }
      
      // Apply date range filter
      if (_selectedDateRange != null) {
        final appointmentDate = appointment['actualDate'] as DateTime;
        if (appointmentDate.isBefore(_selectedDateRange!.start) || 
            appointmentDate.isAfter(_selectedDateRange!.end.add(Duration(days: 1)))) {
          return false;
        }
      }
      
      // Apply search query
      if (_searchQuery.isNotEmpty) {
        final String patientName = appointment['patientName'].toLowerCase();
        final String doctorName = appointment['doctorName'].toLowerCase();
        final String id = appointment['id'].toLowerCase();
        final String hospital = appointment['hospital'].toLowerCase();
        
        final query = _searchQuery.toLowerCase();
        
        return patientName.contains(query) || 
               doctorName.contains(query) || 
               id.contains(query) || 
               hospital.contains(query);
      }
      
      return true;
    }).toList();
  }
  
  // Get a list of all doctors for filtering
  List<String> get _doctorsList {
    final Set<String> doctors = {'All Doctors'};
    for (final appointment in _appointments) {
      doctors.add(appointment['doctorName']);
    }
    return doctors.toList();
  }
  
  // Update appointment status
  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _adminService.updateAppointmentStatus(appointmentId, status);
      
      if (result['success']) {
        // Refresh appointments list
        await _loadAppointments();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appointment status updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Appointment Management',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: AdminTheme.darkPurple,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (_isRefreshing)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AdminTheme.primaryPurple),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: AdminTheme.primaryPurple),
            onPressed: _refreshAppointments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters section
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // More compact search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search appointments...',
                    hintStyle: GoogleFonts.poppins(fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AdminTheme.primaryPurple),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                
                SizedBox(height: 8),
                
                // Filter controls section
                isSmallScreen 
                    ? _buildCompactFiltersMobile() 
                    : _buildCompactFiltersDesktop(),
              ],
            ),
          ),
          
          // Divider
          Divider(height: 1),
          
          // Appointments list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AdminTheme.primaryPurple),
                    )
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : filteredAppointments.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: filteredAppointments.length,
                            itemBuilder: (context, index) {
                              final appointment = filteredAppointments[index];
                              return _buildAppointmentCard(appointment);
                            },
                          ),
          ),
        ],
      ),
    );
  }
  
  // New helper methods for responsive filters
  Widget _buildCompactFiltersMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & reset row
        Row(
          children: [
            Icon(Icons.filter_list, size: 16, color: AdminTheme.primaryPurple),
            SizedBox(width: 4),
            Text(
              'Filters:',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            SizedBox(width: 4),
            InkWell(
              onTap: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedStatusFilter = 'All';
                  _selectedDoctorFilter = 'All Doctors';
                  _selectedDateRange = null;
                });
              },
              child: Text(
                'Reset',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AdminTheme.primaryPurple,
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 8),
        
        // Stacked filters in mobile view
        _buildCompactFilterDropdown(
          label: 'Status',
          value: _selectedStatusFilter,
          items: ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedStatusFilter = value;
              });
            }
          },
        ),
        
        SizedBox(height: 8),
        
        _buildCompactFilterDropdown(
          label: 'Doctor',
          value: _selectedDoctorFilter,
          items: _doctorsList,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedDoctorFilter = value;
              });
            }
          },
        ),
        
        SizedBox(height: 8),
        
        _buildCompactDateRangeFilter(),
      ],
    );
  }
  
  Widget _buildCompactFiltersDesktop() {
    return Row(
      children: [
        // Compact title & reset
        Container(
          margin: EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Icon(Icons.filter_list, size: 16, color: AdminTheme.primaryPurple),
              SizedBox(width: 4),
              Text(
                'Filters:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 4),
              InkWell(
                onTap: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedStatusFilter = 'All';
                    _selectedDoctorFilter = 'All Doctors';
                    _selectedDateRange = null;
                  });
                },
                child: Text(
                  'Reset',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AdminTheme.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Horizontal scrollable filters for desktop
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCompactFilterDropdown(
                  label: 'Status',
                  value: _selectedStatusFilter,
                  items: ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    }
                  },
                ),
                
                SizedBox(width: 8),
                
                _buildCompactFilterDropdown(
                  label: 'Doctor',
                  value: _selectedDoctorFilter,
                  items: _doctorsList,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedDoctorFilter = value;
                      });
                    }
                  },
                ),
                
                SizedBox(width: 8),
                
                _buildCompactDateRangeFilter(),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCompactFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 2),
          DropdownButton<String>(
            value: value,
            icon: Icon(Icons.arrow_drop_down, size: 16, color: AdminTheme.primaryPurple),
            iconSize: 16,
            underline: SizedBox(),
            isDense: true,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 150),
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactDateRangeFilter() {
    final String displayText = _selectedDateRange != null
        ? '${DateFormat('MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('MM/dd').format(_selectedDateRange!.end)}'
        : 'Date Range';
    
    return InkWell(
      onTap: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2022),
          lastDate: DateTime.now().add(Duration(days: 365)),
          initialDateRange: _selectedDateRange ?? DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 30)),
            end: DateTime.now(),
          ),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AdminTheme.primaryPurple,
                ),
              ),
              child: child!,
            );
          },
        );
        
        if (picked != null) {
          setState(() {
            _selectedDateRange = picked;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 14,
              color: AdminTheme.primaryPurple,
            ),
            SizedBox(width: 4),
            Text(
              displayText,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (_selectedDateRange != null) ...[
              SizedBox(width: 4),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Re-added error state widget
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'Failed to load appointments',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade600,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _errorMessage ?? 'An unknown error occurred',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            onPressed: _loadAppointments,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Re-added empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No appointments found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('Reset Filters'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedStatusFilter = 'All';
                _selectedDoctorFilter = 'All Doctors';
                _selectedDateRange = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Improved appointment card with better spacing, layouts, and responsiveness
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    Color statusColor;
    switch (appointment['status']) {
      case 'Confirmed':
        statusColor = Color(0xFF4CAF50);
        break;
      case 'Pending':
        statusColor = Color(0xFFFFC107);
        break;
      case 'Completed':
        statusColor = AdminTheme.primaryPurple;
        break;
      case 'Cancelled':
        statusColor = Color(0xFFFF5722);
        break;
      default:
        statusColor = Colors.grey;
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header with status badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ID: ${appointment['id']}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    appointment['status'],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Appointment details
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor and patient info - adaptive for small screens
                isSmallScreen
                    ? _buildAppointmentInfoMobile(appointment)
                    : _buildAppointmentInfoDesktop(appointment),
                
                SizedBox(height: 16),
                
                // Action buttons - adaptive for small screens
                isSmallScreen
                    ? _buildAppointmentActionsMobile(appointment)
                    : _buildAppointmentActionsDesktop(appointment),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // New helper methods for responsive appointment cards
  Widget _buildAppointmentInfoMobile(Map<String, dynamic> appointment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doctor info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Doctor avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AdminTheme.lightPurple.withOpacity(0.5),
              child: Text(
                appointment['doctorName'].substring(0, 1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.primaryPurple,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment['doctorName'],
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    appointment['specialty'] ?? 'Doctor',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Patient info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                appointment['patientName'].substring(0, 1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment['patientName'],
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Patient ID: ${appointment['patientId']}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16),
        
        // Appointment details in grid form
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildDetailChip(
              icon: Icons.event,
              label: 'Date',
              value: appointment['date'],
            ),
            _buildDetailChip(
              icon: Icons.access_time,
              label: 'Time',
              value: appointment['time'],
            ),
            _buildDetailChip(
              icon: Icons.local_hospital,
              label: 'Hospital',
              value: appointment['hospital'],
              maxWidth: 150,
            ),
            _buildDetailChip(
              icon: Icons.payment,
              label: 'Fee',
              value: appointment['displayAmount'] ?? 'Not specified',
            ),
            _buildDetailChip(
              icon: Icons.category,
              label: 'Type',
              value: appointment['type'] ?? 'In-person',
            ),
            _buildDetailChip(
              icon: Icons.description,
              label: 'Reason',
              value: appointment['reason'],
              maxWidth: 150,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildAppointmentInfoDesktop(Map<String, dynamic> appointment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: Doctor avatar and info
        Expanded(
          flex: 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AdminTheme.lightPurple.withOpacity(0.5),
                child: Text(
                  appointment['doctorName'].substring(0, 1),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.primaryPurple,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['doctorName'],
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      appointment['specialty'] ?? 'Doctor',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    _buildDetailItem(
                      'Date',
                      appointment['date'],
                    ),
                    SizedBox(height: 4),
                    _buildDetailItem(
                      'Time',
                      appointment['time'],
                    ),
                    SizedBox(height: 4),
                    _buildDetailItem(
                      'Hospital',
                      appointment['hospital'],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(width: 24),
        
        // Right column: Patient and other details
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      appointment['patientName'].substring(0, 1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment['patientName'],
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Patient ID: ${appointment['patientId']}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              // Additional details
              _buildDetailItem(
                'Fee',
                appointment['displayAmount'] ?? 'Not specified',
              ),
              SizedBox(height: 4),
              _buildDetailItem(
                'Type',
                appointment['type'] ?? 'In-person',
              ),
              SizedBox(height: 4),
              _buildDetailItem(
                'Reason',
                appointment['reason'],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Detail chip for mobile view
  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required String value,
    double? maxWidth,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          SizedBox(width: 4),
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Action buttons for mobile view (stacked)
  Widget _buildAppointmentActionsMobile(Map<String, dynamic> appointment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appointment['status'] == 'Pending') ...[
          ElevatedButton.icon(
            icon: Icon(Icons.check_circle),
            label: Text('Confirm'),
            onPressed: () => _showConfirmationDialog(
              appointment['id'],
              'Are you sure you want to confirm this appointment?',
              'confirmed',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          SizedBox(height: 8),
        ],
        
        if (appointment['status'] != 'Cancelled' && 
            appointment['status'] != 'Completed') ...[
          OutlinedButton.icon(
            icon: Icon(Icons.cancel),
            label: Text('Cancel'),
            onPressed: () => _showConfirmationDialog(
              appointment['id'],
              'Are you sure you want to cancel this appointment?',
              'cancelled',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFFFF5722),
              side: BorderSide(color: Color(0xFFFF5722)),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          SizedBox(height: 8),
        ],
        
        if (appointment['status'] == 'Confirmed') ...[
          OutlinedButton.icon(
            icon: Icon(Icons.done_all),
            label: Text('Complete'),
            onPressed: () => _showConfirmationDialog(
              appointment['id'],
              'Are you sure you want to mark this appointment as completed?',
              'completed',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTheme.primaryPurple,
              side: BorderSide(color: AdminTheme.primaryPurple),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          SizedBox(height: 8),
        ],
        
        ElevatedButton.icon(
          icon: Icon(Icons.visibility),
          label: Text('Details'),
          onPressed: () => _showAppointmentDetails(appointment),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.primaryPurple,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
  
  // Action buttons for desktop view (horizontal)
  Widget _buildAppointmentActionsDesktop(Map<String, dynamic> appointment) {
    return Row(
      children: [
        if (appointment['status'] == 'Pending') ...[
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.check_circle),
              label: Text('Confirm'),
              onPressed: () => _showConfirmationDialog(
                appointment['id'],
                'Are you sure you want to confirm this appointment?',
                'confirmed',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
        
        if (appointment['status'] != 'Cancelled' && 
            appointment['status'] != 'Completed') ...[
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(Icons.cancel),
              label: Text('Cancel'),
              onPressed: () => _showConfirmationDialog(
                appointment['id'],
                'Are you sure you want to cancel this appointment?',
                'cancelled',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFFFF5722),
                side: BorderSide(color: Color(0xFFFF5722)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
        
        if (appointment['status'] == 'Confirmed') ...[
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(Icons.done_all),
              label: Text('Complete'),
              onPressed: () => _showConfirmationDialog(
                appointment['id'],
                'Are you sure you want to mark this appointment as completed?',
                'completed',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminTheme.primaryPurple,
                side: BorderSide(color: AdminTheme.primaryPurple),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
        
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(Icons.visibility),
            label: Text('Details'),
            onPressed: () => _showAppointmentDetails(appointment),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primaryPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
  
  // Improved dialog UI
  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 600 ? screenWidth * 0.98 : 700.0;
    
    // Determine status color
    Color statusColor;
    IconData statusIcon;
    switch (appointment['status']) {
      case 'Confirmed':
        statusColor = Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        break;
      case 'Pending':
        statusColor = Color(0xFFFFC107);
        statusIcon = Icons.pending;
        break;
      case 'Completed':
        statusColor = AdminTheme.primaryPurple;
        statusIcon = Icons.task_alt;
        break;
      case 'Cancelled':
        statusColor = Color(0xFFFF5722);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.question_mark;
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 5,
        child: Container(
          width: dialogWidth,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Container(
                width: double.infinity,
                color: statusColor.withOpacity(0.1),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appointment Details',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 3),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: statusColor, width: 1),
                            ),
                            child: Text(
                              appointment['status'],
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 18,
                      tooltip: 'Close',
                      color: Colors.black54,
                      padding: EdgeInsets.all(6),
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ID section
                        _buildInfoSection(
                          title: 'Appointment ID',
                          content: Text(
                            appointment['id'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          padding: EdgeInsets.all(12),
                        ),
                        
                        SizedBox(height: 12),
                        
                        // People section
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabeledInfo(
                                'Doctor',
                                appointment['doctorName'],
                                subtitle: appointment['specialty'] ?? 'Not specified',
                                icon: Icons.medical_services,
                                iconColor: AdminTheme.primaryPurple,
                                iconSize: 14,
                                labelFontSize: 11,
                                valueFontSize: 13,
                                subtitleFontSize: 11,
                              ),
                              SizedBox(height: 12),
                              _buildLabeledInfo(
                                'Patient',
                                appointment['patientName'],
                                icon: Icons.person,
                                iconColor: Colors.blue.shade700,
                                iconSize: 14,
                                labelFontSize: 11,
                                valueFontSize: 13,
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Date and Time section
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildLabeledInfo(
                                  'Date',
                                  appointment['date'],
                                  icon: Icons.calendar_today,
                                  iconColor: Colors.green.shade700,
                                  iconSize: 14,
                                  labelFontSize: 11,
                                  valueFontSize: 13,
                                ),
                              ),
                              Container(
                                height: 35,
                                width: 1,
                                color: Colors.grey.shade300,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildLabeledInfo(
                                  'Time',
                                  appointment['time'],
                                  icon: Icons.access_time,
                                  iconColor: Colors.orange.shade700,
                                  iconSize: 14,
                                  labelFontSize: 11,
                                  valueFontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Location section
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabeledInfo(
                                'Hospital',
                                appointment['hospital'],
                                icon: Icons.local_hospital,
                                iconColor: Colors.red.shade700,
                                iconSize: 14,
                                labelFontSize: 11,
                                valueFontSize: 13,
                              ),
                              SizedBox(height: 12),
                              _buildLabeledInfo(
                                'Type',
                                appointment['type'] ?? 'In-person',
                                icon: appointment['type'] == 'Video Consultation' 
                                    ? Icons.videocam 
                                    : Icons.person,
                                iconColor: Colors.purple.shade700,
                                iconSize: 14,
                                labelFontSize: 11,
                                valueFontSize: 13,
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Details section
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabeledInfo(
                                'Reason',
                                appointment['reason'],
                                icon: Icons.description,
                                iconColor: Colors.teal.shade700,
                                iconSize: 14,
                                labelFontSize: 11,
                                valueFontSize: 13,
                              ),
                              SizedBox(height: 12),
                              _buildLabeledInfo(
                                'Fee',
                                appointment['displayAmount'] ?? 'Not specified',
                                icon: Icons.payments,
                                iconColor: Colors.green.shade700,
                                iconSize: 14,
                                labelFontSize: 11,
                                valueFontSize: 13,
                              ),
                              SizedBox(height: 12),
                              _buildLabeledInfo(
                                'Payment Status',
                                appointment['paymentStatus'] ?? 'Not specified',
                                icon: Icons.payment,
                                iconColor: appointment['paymentStatus'] == 'Paid'
                                    ? Colors.green
                                    : appointment['paymentStatus'] == 'Pending'
                                        ? Colors.orange
                                        : Colors.grey.shade700,
                                iconSize: 14,
                                labelFontSize: 11,
                                valueFontSize: 13,
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Action buttons
                        Row(
                          children: [
                            if (appointment['status'] == 'Pending')
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.check_circle, size: 16),
                                  label: Text('Confirm', style: TextStyle(fontSize: 13)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showConfirmationDialog(
                                      appointment['id'],
                                      'Are you sure you want to confirm this appointment?',
                                      'confirmed',
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF4CAF50),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              )
                            else if (appointment['status'] == 'Confirmed')
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.done_all, size: 16),
                                  label: Text('Complete', style: TextStyle(fontSize: 13)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showConfirmationDialog(
                                      appointment['id'],
                                      'Are you sure you want to mark this appointment as completed?',
                                      'completed',
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.primaryPurple,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.primaryPurple,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text('Close', style: TextStyle(fontSize: 13)),
                                ),
                              ),
                              
                            if (appointment['status'] == 'Pending' || appointment['status'] == 'Confirmed') ...[
                              SizedBox(width: 12),
                              if (appointment['status'] == 'Pending' || appointment['status'] == 'Confirmed')
                                Expanded(
                                  child: appointment['status'] == 'Pending' || appointment['status'] == 'Confirmed'
                                    ? OutlinedButton.icon(
                                        icon: Icon(Icons.cancel, size: 16),
                                        label: Text('Cancel', style: TextStyle(fontSize: 13)),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showConfirmationDialog(
                                            appointment['id'],
                                            'Are you sure you want to cancel this appointment?',
                                            'cancelled',
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Color(0xFFFF5722),
                                          side: BorderSide(color: Color(0xFFFF5722)),
                                          padding: EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AdminTheme.primaryPurple,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text('Close', style: TextStyle(fontSize: 13)),
                                      ),
                                ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper widgets for appointment details dialog
  Widget _buildInfoSection({
    required String title,
    required Widget content,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 6),
          content,
        ],
      ),
    );
  }
  
  Widget _buildLabeledInfo(
    String label, 
    String value, {
    IconData? icon, 
    Color? iconColor,
    String? subtitle,
    double iconSize = 16,
    double labelFontSize = 12,
    double valueFontSize = 15,
    double subtitleFontSize = 13,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (iconColor ?? Colors.grey).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: subtitleFontSize,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  void _showConfirmationDialog(String appointmentId, String message, String status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Action'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateAppointmentStatus(appointmentId, status);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'cancelled' 
                ? Color(0xFFFF5722) 
                : status == 'completed'
                  ? AdminTheme.primaryPurple
                  : Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 