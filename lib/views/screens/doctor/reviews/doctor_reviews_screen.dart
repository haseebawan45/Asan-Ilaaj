import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:healthcare/utils/app_theme.dart';
import 'package:healthcare/utils/ui_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DoctorReviewsScreen extends StatefulWidget {
  final String? doctorId;

  const DoctorReviewsScreen({Key? key, this.doctorId}) : super(key: key);

  @override
  _DoctorReviewsScreenState createState() => _DoctorReviewsScreenState();
}

class _DoctorReviewsScreenState extends State<DoctorReviewsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  double _averageRating = 0.0;
  String _doctorId = "";
  String _errorMessage = "";
  
  // Filter options
  String _selectedFilter = "All Reviews";
  final List<String> _filterOptions = [
    "All Reviews",
    "Highest Rating",
    "Lowest Rating",
    "Most Recent",
    "Oldest"
  ];

  // Cache key
  static const String _reviewsCacheKey = 'doctor_reviews_cache_';

  @override
  void initState() {
    super.initState();
    
    // Apply appropriate status bar style for this screen
    UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
    
    _doctorId = widget.doctorId ?? _auth.currentUser?.uid ?? "";
    _loadData();
  }

  // New method to handle the data loading flow
  Future<void> _loadData() async {
    // First load data from cache (if available)
    bool hasCachedData = await _loadFromCache();
    
    // Then fetch fresh data from Firebase in background
    if (hasCachedData) {
      _refreshData();
    } else {
      // If no cached data, perform a normal data load
      await _loadReviews();
    }
  }

  // Load data from cache
  Future<bool> _loadFromCache() async {
    if (_doctorId.isEmpty) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String cacheKey = _reviewsCacheKey + _doctorId + "_" + _selectedFilter;
      final String? cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        
        // Check if cache is not too old (24 hours)
        final lastUpdated = DateTime.parse(data['lastUpdated'] ?? DateTime.now().toIso8601String());
        final now = DateTime.now();
        final difference = now.difference(lastUpdated);
        
        if (difference.inHours < 24) {
          if (mounted) {
            setState(() {
              _reviews = List<Map<String, dynamic>>.from(data['reviews'].map((item) {
                // Convert the timestamp string back to DateTime for proper display
                DateTime timestamp;
                try {
                  timestamp = DateTime.parse(item['timestamp']);
                } catch (e) {
                  timestamp = DateTime.now();
                }
                
                return {
                  'id': item['id'],
                  'patientName': item['patientName'],
                  'rating': item['rating'].toDouble(),
                  'feedback': item['feedback'],
                  'timestamp': timestamp,
                };
              }));
              _averageRating = data['averageRating'].toDouble();
              _isLoading = false;
            });
          }
          return true;
        }
      }
    } catch (e) {
      print('Error loading reviews from cache: $e');
    }
    return false;
  }

  // Save data to cache
  Future<void> _saveToCache(List<Map<String, dynamic>> reviews, double averageRating) async {
    if (_doctorId.isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String cacheKey = _reviewsCacheKey + _doctorId + "_" + _selectedFilter;
      
      // Convert reviews to a cacheable format
      final List<Map<String, dynamic>> cachableReviews = reviews.map((review) {
        return {
          'id': review['id'],
          'patientName': review['patientName'],
          'rating': review['rating'],
          'feedback': review['feedback'],
          'timestamp': (review['timestamp'] as DateTime).toIso8601String(),
        };
      }).toList();
      
      final Map<String, dynamic> cacheData = {
        'reviews': cachableReviews,
        'averageRating': averageRating,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(cacheKey, json.encode(cacheData));
      print('Saved ${reviews.length} reviews to cache');
    } catch (e) {
      print('Error saving reviews to cache: $e');
    }
  }

  // Background refresh - get fresh data without blocking UI
  Future<void> _refreshData() async {
    if (!mounted) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      await _loadReviews(silent: true);
    } catch (e) {
      print('Error refreshing reviews: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadReviews({bool silent = false}) async {
    // Apply pink status bar to ensure it's maintained during loading
    UIHelper.applyPinkStatusBar();
    
    if (_doctorId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Doctor ID not found";
      });
      return;
    }

    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = "";
      });
    }

    try {
      // Query doctor reviews from Firestore
      Query query = _firestore
          .collection('doctor_reviews')
          .where('doctorId', isEqualTo: _doctorId);

      // Apply sorting based on filter
      switch (_selectedFilter) {
        case "Highest Rating":
          query = query.orderBy('rating', descending: true);
          break;
        case "Lowest Rating":
          query = query.orderBy('rating', descending: false);
          break;
        case "Most Recent":
          query = query.orderBy('timestamp', descending: true);
          break;
        case "Oldest":
          query = query.orderBy('timestamp', descending: false);
          break;
        default:
          query = query.orderBy('timestamp', descending: true);
      }

      final QuerySnapshot reviewsSnapshot = await query.get();
      
      if (reviewsSnapshot.docs.isEmpty) {
        setState(() {
          _reviews = [];
          _averageRating = 0.0;
          if (!silent) _isLoading = false;
        });
        
        // Save empty results to cache as well
        _saveToCache([], 0.0);
        return;
      }

      // Process reviews
      double totalRating = 0;
      List<Map<String, dynamic>> reviews = [];

      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        double rating = 0.0;
        
        // Extract rating
        if (data.containsKey('rating')) {
          if (data['rating'] is num) {
            rating = (data['rating'] as num).toDouble();
            totalRating += rating;
          }
        }
        
        // Extract patient name
        String patientName = "Anonymous Patient";
        if (data.containsKey('patientName')) {
          patientName = data['patientName'] ?? "Anonymous Patient";
        }
        
        // Extract feedback/comment
        String feedback = "No feedback provided";
        if (data.containsKey('feedback')) {
          feedback = data['feedback'] ?? "No feedback provided";
        } else if (data.containsKey('comment')) {
          feedback = data['comment'] ?? "No feedback provided";
        }
        
        // Extract timestamp
        DateTime timestamp = DateTime.now();
        if (data.containsKey('timestamp') && data['timestamp'] != null) {
          if (data['timestamp'] is Timestamp) {
            timestamp = (data['timestamp'] as Timestamp).toDate();
          } else if (data['timestamp'] is String) {
            try {
              timestamp = DateTime.parse(data['timestamp']);
            } catch (e) {
              print('Error parsing timestamp: $e');
            }
          }
        }
        
        reviews.add({
          'id': doc.id,
          'patientName': patientName,
          'rating': rating,
          'feedback': feedback,
          'timestamp': timestamp,
        });
      }

      // Calculate average rating
      double averageRating = totalRating / reviewsSnapshot.docs.length;

      // Save to cache
      _saveToCache(reviews, averageRating);

      setState(() {
        _reviews = reviews;
        _averageRating = averageRating;
        if (!silent) _isLoading = false;
      });
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() {
        if (!silent) {
          _isLoading = false;
          _errorMessage = "Error loading reviews. Please try again later.";
        }
      });
    } finally {
      // Ensure status bar style is maintained after loading completes
      if (mounted) {
        UIHelper.applyPinkStatusBar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    
    return WillPopScope(
      onWillPop: () async {
        // Ensure pink status bar is applied when returning to home screen
        UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
        return true;
      },
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Reviews & Ratings",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.primaryPink,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: Colors.white),
            onPressed: () {
              // Apply pink status bar before popping
              UIHelper.applyPinkStatusBar(withPostFrameCallback: true);
              Navigator.pop(context);
            },
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            color: AppTheme.primaryPink,
            child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 4,
                        child: LinearProgressIndicator(
                          color: AppTheme.primaryPink,
                          backgroundColor: AppTheme.primaryPink.withOpacity(0.2),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Loading reviews...",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppTheme.mediumText,
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: AppTheme.error,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: () => _loadReviews(),
                            icon: Icon(Icons.refresh_rounded),
                            label: Text("Try Again"),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryPink,
                              backgroundColor: AppTheme.primaryPink.withOpacity(0.1),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // Rating summary section
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPink,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPink.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _averageRating.toStringAsFixed(1),
                                        style: GoogleFonts.poppins(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(
                                          5,
                                          (index) => Icon(
                                            index < _averageRating
                                                ? Icons.star_rounded
                                                : index < _averageRating + 0.5
                                                    ? Icons.star_half_rounded
                                                    : Icons.star_border_rounded,
                                            color: Colors.amber,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "${_reviews.length} ${_reviews.length == 1 ? 'Review' : 'Reviews'}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Filter section
                          Container(
                            padding: EdgeInsets.all(16),
                            color: Colors.white,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPink.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.filter_list_rounded,
                                        color: AppTheme.primaryPink,
                                        size: 20,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Filter Reviews",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.darkText,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _filterOptions.map((filter) {
                                      final bool isSelected = _selectedFilter == filter;
                                      return GestureDetector(
                                        onTap: () {
                                          if (_selectedFilter != filter) {
                                            setState(() {
                                              _selectedFilter = filter;
                                            });
                                            _loadReviews();
                                          }
                                        },
                                        child: Container(
                                          margin: EdgeInsets.only(right: 12),
                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppTheme.primaryPink : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected ? AppTheme.primaryPink : Colors.grey[300]!,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: AppTheme.primaryPink.withOpacity(0.2),
                                                      blurRadius: 8,
                                                      offset: Offset(0, 4),
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _getFilterIcon(filter),
                                                color: isSelected ? Colors.white : AppTheme.mediumText,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                filter,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                  color: isSelected ? Colors.white : AppTheme.darkText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Reviews list
                          _reviews.isEmpty
                              ? Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: AppTheme.lightPink,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            LucideIcons.messageSquare,
                                            size: 48,
                                            color: AppTheme.primaryPink,
                                          ),
                                        ),
                                        SizedBox(height: 24),
                                        Text(
                                          "No Reviews Yet",
                                          style: GoogleFonts.poppins(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.darkText,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 40),
                                          child: Text(
                                            "Reviews will appear here as patients provide feedback",
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: AppTheme.mediumText,
                                              height: 1.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    children: _reviews.map((review) => _buildReviewCard(review, screenWidth)).toList(),
                                  ),
                                ),
                        ],
                        ),
                      ),
                  ),
            // Bottom refresh indicator
            if (_isRefreshing)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  ),
                ),
              ),
        ],
      ),
    ));
  }

  Widget _buildReviewCard(Map<String, dynamic> review, double screenWidth) {
    final double rating = review['rating'] as double;
    final DateTime timestamp = review['timestamp'] as DateTime;
    final String formattedDate = DateFormat('MMM d, yyyy').format(timestamp);
    
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: Offset(0, 5),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with patient info and rating
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Patient avatar
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryPink,
                            AppTheme.primaryPink.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPink.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(14),
                      child: Text(
                        review['patientName'].substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review['patientName'],
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: AppTheme.lightText,
                            ),
                            SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppTheme.lightText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // Rating badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getRatingColor(rating).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _getRatingColor(rating).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: _getRatingColor(rating),
                      ),
                      SizedBox(width: 6),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _getRatingColor(rating),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Feedback content
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Feedback header
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: AppTheme.primaryPink.withOpacity(0.3),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Patient Feedback",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Review content
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.chat_rounded,
                          size: 18,
                          color: AppTheme.primaryPink,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          review['feedback'],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.darkText,
                            height: 1.6,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Feedback indicators - visual elements only
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Helpful/thank you indicator
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.thumb_up_alt_rounded,
                              size: 14,
                              color: AppTheme.primaryPink,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Helpful",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryPink,
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
        ],
      ),
    );
  }
  
  // Modified rating color function for better visual feedback
  Color _getRatingColor(double rating) {
    if (rating >= 4.5) {
      return Color(0xFF43A047); // Dark green for excellent
    } else if (rating >= 4) {
      return Color(0xFF7CB342); // Green for very good
    } else if (rating >= 3) {
      return Color(0xFFFFA000); // Amber for average
    } else if (rating >= 2) {
      return Color(0xFFFF6D00); // Orange for below average
    } else {
      return Color(0xFFE53935); // Red for poor
    }
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case "All Reviews":
        return Icons.format_list_bulleted_rounded;
      case "Highest Rating":
        return Icons.star_rounded;
      case "Lowest Rating":
        return Icons.star_border_rounded;
      case "Most Recent":
        return Icons.access_time_rounded;
      case "Oldest":
        return Icons.history_rounded;
      default:
        return Icons.filter_list_rounded;
    }
  }

  @override
  void dispose() {
    // Ensure pink status bar is applied when the screen is disposed
    UIHelper.applyPinkStatusBar();
    super.dispose();
  }
} 