import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:healthcare/models/transaction_model.dart';
import 'package:healthcare/utils/navigation_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:healthcare/services/auth_service.dart';
import 'package:healthcare/services/financial_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthcare/views/screens/bottom_navigation_bar.dart';
import 'package:healthcare/utils/app_theme.dart';

class FinancesScreen extends StatefulWidget {
  const FinancesScreen({Key? key}) : super(key: key);

  @override
  _FinancesScreenState createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> {
  // Loading states
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  
  // Financial data
  List<TransactionItem> _transactions = [];
  double _totalBalance = 0.0;
  double _totalIncome = 0.0;
  double _currentMonthIncome = 0.0;
  
  // Pagination
  int _currentPage = 1;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastTransactionDoc;
  bool _hasMoreTransactions = true;
  bool _isLoadingMoreTransactions = false;
  final int _transactionsPerPage = 10;
  
  // Set to track unique transaction IDs
  final Set<String> _processedTransactionIds = {};
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  late final FinancialRepository _financialRepository;
  
  // Cache key
  static const String _financesCacheKey = 'doctor_finances_data';

  @override
  void initState() {
    super.initState();
    _financialRepository = FinancialRepository();
    _scrollController.addListener(_scrollListener);
    _loadFinancialData();
    
    // Set system UI overlay style for consistent status bar appearance
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppTheme.primaryPink,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // For iOS
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    
    // Reset system UI when leaving
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppTheme.primaryPink,
      statusBarIconBrightness: Brightness.light,
    ));
    super.dispose();
  }

  // Scroll listener to detect when user scrolls to bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMoreTransactions &&
        _hasMoreTransactions) {
      _loadMoreTransactions();
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMoreTransactions || !_hasMoreTransactions) return;
    
    setState(() {
      _isLoadingMoreTransactions = true;
    });
    
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoadingMoreTransactions = false;
        });
        return;
      }
      
      // Load more transactions
      await _loadTransactions(currentUser.uid, isFirstLoad: false);
      
      // Recalculate financial summaries
      _calculateFinancialSummaries();
    } catch (e) {
      print('Error loading more transactions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreTransactions = false;
        });
      }
    }
  }

  Future<void> _loadFinancialData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    // First load cached data
    bool hasCachedData = await _loadCachedData();
    
    // Only clear and refresh if no cached data or cache is old
    if (!hasCachedData) {
      if (mounted) {
        setState(() {
          // Reset pagination data on fresh load
          _lastTransactionDoc = null;
          _hasMoreTransactions = true;
          _transactions.clear();
        });
      }
      // Then start background refresh
      _refreshData();
    } else {
      // If we have cached data, do a background refresh after a delay
      Future.delayed(Duration(seconds: 30), () {
        if (mounted) {
          _refreshData();
        }
      });
    }
  }

  // Load cached data first
  Future<bool> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(_financesCacheKey);
      
      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        
        // Check if cache is not too old (24 hours)
        final lastUpdated = DateTime.parse(data['lastUpdated'] ?? DateTime.now().toIso8601String());
        final now = DateTime.now();
        final difference = now.difference(lastUpdated);
        
        if (difference.inHours < 24) {
          if (mounted) {
            setState(() {
              _totalBalance = (data['totalBalance'] as num?)?.toDouble() ?? 0.0;
              _totalIncome = (data['totalIncome'] as num?)?.toDouble() ?? 0.0;
              _currentMonthIncome = (data['currentMonthIncome'] as num?)?.toDouble() ?? 0.0;
              
              // Load cached transactions
              if (data.containsKey('transactions')) {
                _transactions = (data['transactions'] as List)
                    .map((item) => TransactionItem(
                          item['transactionId'],
                          item['title'],
                          (item['amount'] as num).toDouble(),
                          item['date'],
                          _convertTransactionType(item['type']),
                        ))
                    .toList();
              }
              
              _isLoading = false;
            });
          }
          return true;
        }
      }
    } catch (e) {
      print('Error loading cached finances data: $e');
    }
    return false;
  }

  // Refresh data in background
  Future<void> _refreshData() async {
    if (!mounted) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Store current transactions in case we need to revert
      final previousTransactions = List<TransactionItem>.from(_transactions);
      
      // Load transactions
      bool success = await _loadTransactionsFromRepository();
      
      // If repository load fails, use fallback
      if (!success) {
        await _loadTransactions(currentUser.uid, isFirstLoad: true);
      }
      
      // Calculate financial summaries
      _calculateFinancialSummaries();
      
      // Save to cache only if we successfully loaded new data
      if (_transactions.isNotEmpty) {
        await _saveToCache();
      } else {
        // Revert to previous transactions if new load failed
        setState(() {
          _transactions = previousTransactions;
        });
      }
      
    } catch (e) {
      print('Error refreshing financial data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _isLoading = false;
        });
      }
    }
  }

  // Save current data to cache
  Future<void> _saveToCache() async {
    try {
      final Map<String, dynamic> cacheData = {
        'totalBalance': _totalBalance,
        'totalIncome': _totalIncome,
        'currentMonthIncome': _currentMonthIncome,
        'lastUpdated': DateTime.now().toIso8601String(),
        'transactions': _transactions.map((item) => {
          'transactionId': item.transactionId,
          'title': item.title,
          'amount': item.amount,
          'date': item.date,
          'type': item.type == TransactionType.income ? 'income' : 'expense',
        }).toList(),
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_financesCacheKey, json.encode(cacheData));
      print('Saved ${_transactions.length} transactions to cache');
    } catch (e) {
      print('Error saving finances to cache: $e');
    }
  }

  void _calculateTotals() {
    _totalIncome = _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    _totalBalance = _totalIncome;
  }

  List<TransactionItem> _generateMockTransactions() {
    final random = DateTime.now();
    return List.generate(10, (i) {
      final isIncome = i % 3 == 0;
      return TransactionItem(
        'mock_${i}_${DateTime.now().millisecondsSinceEpoch}',
        isIncome ? 'Payment Received' : 'Purchase',
        (i + 1) * 100.0,
        DateFormat('dd MMM, yyyy').format(random.subtract(Duration(days: i))),
        isIncome ? TransactionType.income : TransactionType.expense,
      );
    });
  }

  // Attempt to load transactions using the FinancialRepository
  Future<bool> _loadTransactionsFromRepository() async {
    try {
      // Clear existing transactions if first load
      if (_lastTransactionDoc == null) {
        _transactions.clear();
      }
      
      // Get transactions stream from the repository
      final transactionsStream = _financialRepository.getTransactions(limit: _transactionsPerPage);
      
      // Convert stream to list
      final transactionsList = await transactionsStream.first;
      
      // If no transactions, return false to use fallback
      if (transactionsList.isEmpty) {
        return false;
      }
      
      // Convert FinancialTransaction to TransactionItem
      for (var transaction in transactionsList) {
        _transactions.add(TransactionItem(
          transaction.id,
          transaction.title,
          transaction.amount,
          DateFormat('dd MMM, yyyy').format(transaction.date),
          _convertTransactionType(transaction.type),
        ));
      }
      
      return true;
    } catch (e) {
      print('Error loading from repository: $e');
      return false;
    }
  }
  
  // Helper method to convert between TransactionType enums
  TransactionType _convertTransactionType(dynamic modelType) {
    if (modelType == null) return TransactionType.income;
    
    // Check if it's a string first
    if (modelType is String) {
      return modelType == 'expense' ? TransactionType.expense : TransactionType.income;
    }
    
    // Handle the case where it's the model's TransactionType enum
    try {
      final typeValue = modelType.toString().split('.').last;
      return typeValue == 'expense' ? TransactionType.expense : TransactionType.income;
    } catch (e) {
      return TransactionType.income;
    }
  }
  
  // Load transactions from Firestore
  Future<void> _loadTransactions(String userId, {required bool isFirstLoad}) async {
    try {
      // Clear existing transactions if first load
      if (isFirstLoad) {
        _transactions.clear();
        _lastTransactionDoc = null;
        _processedTransactionIds.clear();
      }
      
      // Create base query
      Query query = _firestore
          .collection('transactions')
          .where('doctorId', isEqualTo: userId)
          .where('type', isEqualTo: 'payment')
          .where('status', isEqualTo: 'completed')
          .orderBy('date', descending: true);
      
      // Apply pagination
      if (_lastTransactionDoc != null) {
        query = query.startAfterDocument(_lastTransactionDoc!);
      }
      
      // Limit results
      query = query.limit(_transactionsPerPage);
      
      // Execute query
      final transactionsSnapshot = await query.get();
      
      // Update pagination info
      _hasMoreTransactions = transactionsSnapshot.docs.length >= _transactionsPerPage;
      
      if (transactionsSnapshot.docs.isNotEmpty) {
        _lastTransactionDoc = transactionsSnapshot.docs.last;
      }
      
      // If no transactions found on first load, try loading from appointments
      if (transactionsSnapshot.docs.isEmpty && isFirstLoad) {
        await _loadTransactionsFromAppointments(userId, isFirstLoad: true);
      } else {
        // Process transactions
        for (var doc in transactionsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String transactionId = doc.id;
          
          // Skip if already processed
          if (_processedTransactionIds.contains(transactionId)) {
            continue;
          }
          
          // Get patient name for better description
          String patientName = "Patient";
          if (data['patientId'] != null) {
            try {
              final patientDoc = await _firestore
                  .collection('users')
                  .doc(data['patientId'])
                  .get();
              
              if (patientDoc.exists && patientDoc.data() != null) {
                patientName = patientDoc.data()!['fullName'] ?? "Patient";
              }
            } catch (e) {
              print('Error fetching patient name: $e');
            }
          }

          String title = data['title'] ?? 'Payment Received';
          String description = data['description'] ?? 'Payment from $patientName';
          double amount = data['amount'] is num ? (data['amount'] as num).toDouble() : 0.0;
          DateTime date = data['date'] is Timestamp 
              ? (data['date'] as Timestamp).toDate() 
              : DateTime.now();
          
          // For doctors, all payments received are considered income
          _transactions.add(TransactionItem(
            transactionId,
            description,
            amount,
            DateFormat('dd MMM, yyyy').format(date),
            TransactionType.income,
          ));
          
          // Mark as processed
          _processedTransactionIds.add(transactionId);
        }
      }
    } catch (e) {
      print('Error loading transactions: $e');
      // If there was an error on first load, try appointments as fallback
      if (isFirstLoad) {
        await _loadTransactionsFromAppointments(userId, isFirstLoad: true);
      }
    }
  }
  
  // Load transactions from appointments as an alternative source
  Future<void> _loadTransactionsFromAppointments(String userId, {required bool isFirstLoad}) async {
    try {
      // Clear existing transactions if this is first load
      if (isFirstLoad) {
        _transactions.clear();
        _lastTransactionDoc = null;
        _processedTransactionIds.clear();
      }
      
      // Create base query
      Query query = _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: userId)
          .where('status', isEqualTo: 'confirmed')
          .where('paymentStatus', isEqualTo: 'completed')
          .orderBy('paymentDate', descending: true);
      
      // Apply pagination
      if (_lastTransactionDoc != null) {
        query = query.startAfterDocument(_lastTransactionDoc!);
      }
      
      // Limit results
      query = query.limit(_transactionsPerPage);
      
      // Execute query
      final appointmentsSnapshot = await query.get();
      
      // Update pagination info
      _hasMoreTransactions = appointmentsSnapshot.docs.length >= _transactionsPerPage;
      
      if (appointmentsSnapshot.docs.isNotEmpty) {
        _lastTransactionDoc = appointmentsSnapshot.docs.last;
      }
      
      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String appointmentId = doc.id;
        
        // Skip if already processed
        if (_processedTransactionIds.contains(appointmentId)) {
          continue;
        }
        
        // Get patient name
        String patientName = "Patient";
        if (data.containsKey('patientId')) {
          try {
            final patientDoc = await _firestore
                .collection('users')
                .doc(data['patientId'])
                .get();
            
            if (patientDoc.exists && patientDoc.data() != null) {
              final patientData = patientDoc.data()! as Map<String, dynamic>;
              patientName = patientData['fullName'] ?? "Patient";
            }
          } catch (e) {
            print('Error fetching patient: $e');
          }
        }
        
        // Prepare transaction data
        String title = "Payment from $patientName";
        double amount = data['fee'] is num ? (data['fee'] as num).toDouble() : 0.0;
        DateTime date = data['paymentDate'] is Timestamp 
            ? (data['paymentDate'] as Timestamp).toDate() 
            : (data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now());
        
        // For doctors, all appointment payments are income
        _transactions.add(TransactionItem(
          appointmentId,
          title,
          amount,
          DateFormat('dd MMM, yyyy').format(date),
          TransactionType.income,
        ));
        
        // Mark as processed
        _processedTransactionIds.add(appointmentId);
      }
    } catch (e) {
      print('Error loading transactions from appointments: $e');
    }
  }
  
  // Calculate financial summaries based on loaded transactions
  void _calculateFinancialSummaries() {
    _totalIncome = 0.0;
    _currentMonthIncome = 0.0;
    
    // Track processed transaction IDs to prevent duplicates
    Set<String> processedIds = {};
    
    // Get current month and year
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    print('Calculating totals for ${_transactions.length} transactions');
    print('Current month/year: $currentMonth/$currentYear');
    
    for (var transaction in _transactions) {
      // Skip duplicates
      if (processedIds.contains(transaction.transactionId)) {
        print('Skipping duplicate transaction: ${transaction.transactionId}');
        continue;
      }
      processedIds.add(transaction.transactionId);
      
      // Calculate totals based on transaction type
      if (transaction.type == TransactionType.income) {
        _totalIncome += transaction.amount;
        
        // Try to parse the date string
        DateTime? transactionDate;
        try {
          // Handle different date formats
          if (transaction.date.contains(',')) {
            // Format like "15 Mar, 2023"
            transactionDate = DateFormat('dd MMM, yyyy').parse(transaction.date);
          } else if (transaction.date.contains('/')) {
            // Format like "15/03/2023"
            transactionDate = DateFormat('dd/MM/yyyy').parse(transaction.date);
          } else if (transaction.date.contains('-')) {
            // Format like "2023-03-15"
            transactionDate = DateTime.parse(transaction.date);
          }
          
          if (transactionDate != null) {
            print('Transaction date: ${transaction.date} parsed as ${transactionDate.toString()}');
            if (transactionDate.month == currentMonth && transactionDate.year == currentYear) {
              print('Adding ${transaction.amount} to current month income');
              _currentMonthIncome += transaction.amount;
            }
          }
        } catch (e) {
          print('Error parsing date ${transaction.date}: $e');
        }
      }
    }
    
    // Total balance is just income for doctors
    _totalBalance = _totalIncome;
    
    print('Total income: $_totalIncome');
    print('Current month income: $_currentMonthIncome');
  }

  @override
  Widget build(BuildContext context) {
    // Ensure consistent status bar appearance on every build
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppTheme.primaryPink,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    
    return WillPopScope(
      onWillPop: () async {
        // Navigate to Home tab on back press
        NavigationHelper.navigateToTab(context, 0);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryPink,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Loading financial data...",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppTheme.mediumText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: AppTheme.primaryTeal,
              child: Stack(
                children: [
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Custom app bar with matching style to analytics.dart
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back button
                              GestureDetector(
                                onTap: () {
                                  NavigationHelper.navigateToTab(context, 0);
                                },
                                child: Icon(
                                  LucideIcons.arrowLeft,
                                  color: Colors.white,
                                ),
                              ),
                              
                              // Title
                              Text(
                                "Finances",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              
                              // Filter icon
                              GestureDetector(
                                onTap: () {
                                  // Future implementation for date filters
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Date filtering coming soon")),
                                  );
                                },
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.calendarDays,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Scrollable content
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Main financial summary card
                                Container(
                                  margin: EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPink,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryPink.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: Offset(0, 10),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top row with title and settings
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Card title with icon
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  LucideIcons.wallet,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                "Total Earnings",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          // Refresh button
                                          InkWell(
                                            onTap: _refreshData,
                                            borderRadius: BorderRadius.circular(30),
                                            child: Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _isRefreshing 
                                                  ? LucideIcons.loader 
                                                  : LucideIcons.refreshCw,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      SizedBox(height: 24),
                                      
                                      // Total balance amount
                                      Text(
                                        "Rs ${_totalIncome.toStringAsFixed(0)}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                      
                                      SizedBox(height: 6),
                                      
                                      // Subtitle
                                      Row(
                                        children: [
                                          Icon(
                                            LucideIcons.trendingUp,
                                            color: Colors.greenAccent,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            "All time earnings",
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.white.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      SizedBox(height: 24),
                  
                                      // Financial metrics row
                                      Row(
                                        children: [
                                          // Monthly earnings metric
                                          Expanded(
                                            child: _buildFinanceMetric(
                                              "This Month",
                                              "Rs ${_currentMonthIncome.toStringAsFixed(0)}",
                                              LucideIcons.calendar,
                                            ),
                                          ),
                                          
                                          Container(
                                            height: 40,
                                            width: 1,
                                            color: Colors.white.withOpacity(0.2),
                                            margin: EdgeInsets.symmetric(horizontal: 12),
                                          ),
                  
                                          // Transactions metric
                                          Expanded(
                                            child: _buildFinanceMetric(
                                              "Transactions",
                                              "${_transactions.length}",
                                              LucideIcons.fileText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Transactions section header
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Recent Transactions",
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.darkText,
                                        ),
                                      ),
                                      
                                      // Filter chip - currently just decorative
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.lightTeal,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppTheme.primaryTeal.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.arrowDownUp,
                                              size: 14,
                                              color: AppTheme.primaryTeal,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              "All",
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.primaryTeal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                  
                                // Transactions list
                                _transactions.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: AppTheme.lightTeal,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              LucideIcons.receipt,
                                              size: 40,
                                              color: AppTheme.primaryTeal,
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            "No transactions yet",
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.darkText,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "Your earnings will appear here",
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: AppTheme.mediumText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _transactions.length + (_hasMoreTransactions ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index == _transactions.length) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                                            child: Center(
                                              child: Container(
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.lightPink,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppTheme.primaryPink,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return _buildTransactionCard(_transactions[index]);
                                      },
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bottom loading indicator
                  if (_isRefreshing)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryTeal,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Updating your finances...",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.darkText,
                                ),
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

  // Finance metric widget for the top card
  Widget _buildFinanceMetric(String title, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Keep the stat card widget but we're not using it in the new design
  Widget _buildStatCard(String title, String value, Color bgColor, IconData icon, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionItem transaction) {
    // Convert date string to DateTime for relative time
    DateTime? transactionDate;
    try {
      final parts = transaction.date.split(" ");
      if (parts.length >= 3) {
        final day = int.parse(parts[0]);
        final monthStr = parts[1].toLowerCase();
        final year = int.parse(parts[2].replaceAll(",", ""));
        
        final Map<String, int> months = {
          "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
          "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
        };
        
        final month = months[monthStr.substring(0, 3)] ?? 1;
        transactionDate = DateTime(year, month, day);
      }
    } catch (e) {
      print("Error parsing date: $e");
    }
    
    // Generate relative time string
    String relativeTime = transaction.date;
    if (transactionDate != null) {
      final now = DateTime.now();
      final difference = now.difference(transactionDate);
      
      if (difference.inDays == 0) {
        relativeTime = "Today";
      } else if (difference.inDays == 1) {
        relativeTime = "Yesterday";
      } else if (difference.inDays < 7) {
        relativeTime = "${difference.inDays} days ago";
      } else {
        relativeTime = transaction.date;
      }
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Show transaction details in the future
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Transaction icon with status indicator
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.lightTeal,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        LucideIcons.wallet,
                        color: AppTheme.primaryTeal,
                        size: 22,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.plus,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(width: 16),
                
                // Transaction details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 12,
                            color: AppTheme.lightText,
                          ),
                          SizedBox(width: 4),
                          Text(
                            relativeTime,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.mediumText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Amount
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Rs ${transaction.amount.toStringAsFixed(0)}",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum TransactionType { income, expense }

class TransactionItem {
  final String transactionId;
  final String title;
  final double amount;
  final String date;
  final TransactionType type;

  TransactionItem(this.transactionId, this.title, this.amount, this.date, this.type);
}
