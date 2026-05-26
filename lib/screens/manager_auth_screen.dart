import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/company.dart';
import '../models/user.dart' as app_user;
import '../services/supabase_config.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../helpers/security_helper.dart';
import 'login_screen.dart';

class ManagerAuthScreen extends StatefulWidget {
  const ManagerAuthScreen({super.key});

  @override
  State<ManagerAuthScreen> createState() => _ManagerAuthScreenState();
}

class _ManagerAuthScreenState extends State<ManagerAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String _joinStatus = '';

  String _generateManagerPin(String companyName) {
    String prefix = companyName
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toUpperCase();
    if (prefix.length < 3) {
      prefix = prefix.padRight(3, 'X');
    } else {
      prefix = prefix.substring(0, 3);
    }
    String randomDigits = (100 + Random().nextInt(900)).toString(); // 100-999
    return prefix + randomDigits;
  }

  String _generateCompanyId(String companyName) {
    var slug = companyName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (slug.isEmpty) slug = 'company';
    if (slug.length > 20) slug = slug.substring(0, 20);
    final suffix = (1000 + Random().nextInt(9000)).toString();
    return 'company_${slug}_$suffix';
  }

  Future<String> _generateUniqueCompanyId(String companyName) async {
    final dbHelper = DatabaseHelper.instance;
    for (int i = 0; i < 20; i++) {
      final candidate = _generateCompanyId(companyName);
      final local = await dbHelper.getCompany(candidate);
      if (local != null) continue;

      if (SupabaseConfig.isConfigured) {
        try {
          final remote = await SupabaseService.instance.getCompany(candidate);
          if (remote != null) continue;
        } catch (_) {
          // If remote check fails, fall back to local uniqueness only.
        }
      }
      return candidate;
    }
    throw Exception('Could not generate a unique company ID. Try again.');
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final companyName = _companyController.text.trim();
      final managerName = _nameController.text.trim();

      final companyId = await _generateUniqueCompanyId(companyName);
      final generatedPin = _generateManagerPin(companyName);

      // Save global company context (secure + shared prefs for backward compat)
      await prefs.setString('companyId', companyId);
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'companyId', value: companyId);
      final dbHelper = DatabaseHelper.instance;
      dbHelper.currentCompanyId = companyId;

      // Create company record
      final company = Company(
        companyId: companyId,
        name: companyName,
        createdBy: managerName,
        createdAt: DateTime.now().toIso8601String(),
      );
      await dbHelper.createCompany(company);

      // Ensure manager exists in local DB
      final newManager = app_user.User(
        companyId: companyId,
        pin: generatedPin,
        fullName: managerName,
        role: 'manager',
        createdAt: DateTime.now().toIso8601String(),
      );
      await dbHelper.createUser(newManager);

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog(generatedPin, companyId, companyName, managerName);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String pin, String companyId, String companyName, String managerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFFFB300), size: 48),
            const SizedBox(height: 16),
            Text(
              'Company Registered!',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Your company "$companyName" has been set up successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            Text(
              'COMPANY ID',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                companyId,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'YOUR LOGIN ID',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB300)),
              ),
              child: Text(
                pin,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFB300),
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please write this down. You will use this 6-character code to log into the app as a Manager.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Go to Login',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinExistingCompany() async {
    final joinController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Join Existing Company',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the Company ID provided by your manager.',
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: joinController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. company_aura_demo',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
                ),
                prefixIcon: Icon(Icons.vpn_key_outlined, color: Colors.grey[500], size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Join', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final companyId = joinController.text.trim();
    joinController.dispose();
    if (companyId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!SupabaseConfig.isConfigured) {
        throw Exception('Supabase is not configured. Please set up your API keys.');
      }

      // Ensure Supabase is initialized (may have failed silently in main())
      SupabaseClient client;
      try {
        client = Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
        client = Supabase.instance.client;
      }

      const kTimeout = Duration(seconds: 15);

      // 1. Verify company exists in Supabase
      debugPrint('[Join] Verifying company: $companyId');
      final remoteCompany = await client
          .from('companies')
          .select()
          .eq('company_id', companyId)
          .maybeSingle()
          .timeout(kTimeout, onTimeout: () => throw Exception('Connection timed out. Check your internet and try again.'));

      if (remoteCompany == null) {
        throw Exception('No company found with ID: $companyId');
      }
      debugPrint('[Join] Company found: ${remoteCompany['name']}');

      // 2. Fetch users (skip gracefully if table missing)
      List<dynamic> remoteUsers = [];
      try {
        setState(() => _joinStatus = 'Fetching team members...');
        remoteUsers = await client
            .from('app_users')
            .select()
            .eq('company_id', companyId)
            .timeout(kTimeout);
        debugPrint('[Join] Fetched ${remoteUsers.length} users');
      } catch (e) {
        debugPrint('[Join] Users table unavailable, skipping: $e');
      }

      // 3. Fetch products
      setState(() => _joinStatus = 'Syncing products...');
      final remoteProducts = await client
          .from('products')
          .select()
          .eq('company_id', companyId)
          .timeout(kTimeout, onTimeout: () => throw Exception('Products sync timed out. Try again.'));
      debugPrint('[Join] Fetched ${remoteProducts.length} products');

      // 4. Fetch sales (last 90 days only)
      setState(() => _joinStatus = 'Syncing recent sales...');
      final cutoff = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
      final remoteSales = await client
          .from('sales')
          .select()
          .eq('company_id', companyId)
          .gte('sale_date', cutoff)
          .timeout(kTimeout, onTimeout: () => throw Exception('Sales sync timed out. Try again.'));
      debugPrint('[Join] Fetched ${remoteSales.length} sales');

      // 5. Fetch audit logs
      setState(() => _joinStatus = 'Syncing audit logs...');
      List<dynamic> remoteLogs = [];
      try {
        remoteLogs = await client
            .from('audit_logs')
            .select()
            .eq('company_id', companyId)
            .timeout(kTimeout);
        debugPrint('[Join] Fetched ${remoteLogs.length} audit logs');
      } catch (e) {
        debugPrint('[Join] Audit logs fetch failed, skipping: $e');
      }

      // 6. Save company context locally
      setState(() => _joinStatus = 'Saving locally...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('companyId', companyId);
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'companyId', value: companyId);
      final dbHelper = DatabaseHelper.instance;
      dbHelper.currentCompanyId = companyId;
      final db = await dbHelper.database;

      // 7. Write everything in a single transaction (much faster than individual inserts)
      int usersInserted = 0;
      int productsInserted = 0;
      int salesInserted = 0;

      await db.transaction((txn) async {
        // Company
        await txn.insert('companies', {
          'companyId': remoteCompany['company_id'],
          'name': remoteCompany['name'],
          'createdBy': remoteCompany['created_by'],
          'createdAt': remoteCompany['created_at'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // Users
        for (final remote in remoteUsers) {
          final rawPin = remote['pin'] as String? ?? '';
          final safePin = rawPin.isEmpty ? rawPin
              : (SecurityHelper.isAlreadyHashed(rawPin) ? rawPin : SecurityHelper.hashPin(rawPin));
          await txn.insert('users', {
            'id': remote['local_id'],
            'companyId': remote['company_id'],
            'pin': safePin,
            'fullName': remote['full_name'],
            'role': remote['role'],
            'phone': remote['phone'],
            'isActive': remote['is_active'] ?? 1,
            'createdAt': remote['created_at'],
            'createdBy': remote['created_by'],
            'lastLogin': remote['last_login'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          usersInserted++;
        }

        // Products
        for (final remote in remoteProducts) {
          await txn.insert('products', {
            'companyId': remote['company_id'],
            'name': remote['name'],
            'category': remote['category'],
            'quantity': remote['quantity'],
            'minQuantity': remote['min_quantity'],
            'costPrice': remote['cost_price'],
            'sellingPrice': remote['selling_price'],
            'supplier': remote['supplier'],
            'barcode': remote['barcode'],
            'imagePath': remote['image_path'],
            'createdAt': remote['created_at'],
            'updatedAt': remote['updated_at'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          productsInserted++;
        }

        // Sales
        for (final remote in remoteSales) {
          await txn.insert('sales', {
            'companyId': remote['company_id'],
            'productId': remote['product_id'],
            'productName': remote['product_name'],
            'quantitySold': remote['quantity_sold'],
            'unitPrice': remote['unit_price'],
            'totalAmount': remote['total_amount'],
            'saleDate': remote['sale_date'],
            'notes': remote['notes'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          salesInserted++;
        }

        // Audit logs
        for (final remote in remoteLogs) {
          await txn.insert('audit_logs', {
            'companyId': remote['company_id'],
            'userId': remote['user_id'],
            'userName': remote['user_name'],
            'action': remote['action'],
            'details': remote['details'],
            'timestamp': remote['timestamp'],
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      debugPrint('[Join] DB transaction complete: $usersInserted users, $productsInserted products, $salesInserted sales');

      // Start real-time listeners
      SyncService.instance.startListening(companyId);

      setState(() { _isLoading = false; _joinStatus = ''; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced: $usersInserted users, $productsInserted products, $salesInserted sales'),
            backgroundColor: Colors.green[700],
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('[Join] ERROR: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 24.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/icon.png',
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.business,
                        size: 80,
                        color: Color(0xFFFFB300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Setup Company',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Register your business and generate your Manager ID.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          color: Colors.red[800],
                          fontSize: 13,
                        ),
                      ),
                    ),

                  _buildTextField(
                    controller: _companyController,
                    label: 'Company Name',
                    icon: Icons.business,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter company name' : null,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Manager Full Name',
                    icon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter your name' : null,
                  ),

                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.black87,
                            )
                          : Text(
                              'Generate Manager ID',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // Show join progress status when loading
                  if (_isLoading && _joinStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _joinStatus,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Toggle to Login if already have an account setup
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Already set up? ',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFFB300),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Join existing company (for staff on a second device)
                  TextButton(
                    onPressed: _isLoading ? null : _joinExistingCompany,
                    child: RichText(
                      text: TextSpan(
                        text: 'Have a Company ID? ',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                        children: [
                          TextSpan(
                            text: 'Join Company',
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      textCapitalization: textCapitalization,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red[300]!, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}
