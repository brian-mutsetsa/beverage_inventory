import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../helpers/security_helper.dart';
import '../models/company.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart' as app_user;
import '../models/audit_log.dart';

/// Service that handles all Supabase cloud CRUD operations.
/// Mirrors the local SQLite DatabaseHelper but targets Supabase PostgreSQL.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  SupabaseClient get _client => Supabase.instance.client;

  // ==================== PRODUCTS ====================

  Future<void> upsertProduct(Product product) async {
    try {
      await _client.from('products').upsert({
        'local_id': product.id,
        'company_id': product.companyId,
        'name': product.name,
        'category': product.category,
        'quantity': product.quantity,
        'min_quantity': product.minQuantity,
        'cost_price': product.costPrice,
        'selling_price': product.sellingPrice,
        'supplier': product.supplier,
        'barcode': product.barcode,
        'image_path': product.imagePath,
        'created_at': product.createdAt,
        'updated_at': product.updatedAt,
      }, onConflict: 'company_id,local_id');
    } catch (e) {
      debugPrint('SupabaseService.upsertProduct error: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(int localId, String companyId) async {
    try {
      await _client
          .from('products')
          .delete()
          .eq('local_id', localId)
          .eq('company_id', companyId);
    } catch (e) {
      debugPrint('SupabaseService.deleteProduct error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getProducts(String companyId) async {
    try {
      final data = await _client
          .from('products')
          .select()
          .eq('company_id', companyId)
          .order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('SupabaseService.getProducts error: $e');
      return [];
    }
  }

  // ==================== SALES ====================

  Future<void> upsertSale(Sale sale) async {
    try {
      await _client.from('sales').upsert({
        'local_id': sale.id,
        'company_id': sale.companyId,
        'product_id': sale.productId,
        'product_name': sale.productName,
        'quantity_sold': sale.quantitySold,
        'unit_price': sale.unitPrice,
        'total_amount': sale.totalAmount,
        'sale_date': sale.saleDate,
        'notes': sale.notes,
      }, onConflict: 'company_id,local_id');
    } catch (e) {
      debugPrint('SupabaseService.upsertSale error: $e');
      rethrow;
    }
  }

  Future<void> deleteSale(int localId, String companyId) async {
    try {
      await _client
          .from('sales')
          .delete()
          .eq('local_id', localId)
          .eq('company_id', companyId);
    } catch (e) {
      debugPrint('SupabaseService.deleteSale error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSales(String companyId) async {
    try {
      final data = await _client
          .from('sales')
          .select()
          .eq('company_id', companyId)
          .order('sale_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('SupabaseService.getSales error: $e');
      return [];
    }
  }

  // ==================== USERS ====================

  Future<void> upsertUser(app_user.User user) async {
    try {
      final data = <String, dynamic>{
        'local_id': user.id,
        'company_id': user.companyId,
        'full_name': user.fullName,
        'role': user.role,
        'phone': user.phone,
        'is_active': user.isActive,
        'created_at': user.createdAt,
        'created_by': user.createdBy,
        'last_login': user.lastLogin,
      };
      // Only push plaintext PINs to Supabase — never push hashes
      if (!SecurityHelper.isAlreadyHashed(user.pin)) {
        data['pin'] = user.pin;
      }
      await _client.from('app_users').upsert(
        data, onConflict: 'company_id,local_id',
      );
    } catch (e) {
      debugPrint('SupabaseService.upsertUser error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUsers(String companyId) async {
    try {
      final data = await _client
          .from('app_users')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('SupabaseService.getUsers error: $e');
      return [];
    }
  }

  // ==================== AUDIT LOGS ====================

  Future<void> insertAuditLog(AuditLog log) async {
    try {
      await _client.from('audit_logs').upsert({
        'local_id': log.id,
        'company_id': log.companyId,
        'user_id': log.userId,
        'user_name': log.userName,
        'action': log.action,
        'details': log.details,
        'timestamp': log.timestamp,
      }, onConflict: 'company_id,local_id');
    } catch (e) {
      debugPrint('SupabaseService.insertAuditLog error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogs(String companyId) async {
    try {
      final data = await _client
          .from('audit_logs')
          .select()
          .eq('company_id', companyId)
          .order('timestamp', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('SupabaseService.getAuditLogs error: $e');
      return [];
    }
  }

  // ==================== COMPANIES ====================

  Future<void> upsertCompany(Company company) async {
    try {
      await _client.from('companies').upsert({
        'company_id': company.companyId,
        'name': company.name,
        'created_by': company.createdBy,
        'created_at': company.createdAt,
      }, onConflict: 'company_id');
    } catch (e) {
      debugPrint('SupabaseService.upsertCompany error: $e');
    }
  }

  Future<Map<String, dynamic>?> getCompany(String companyId) async {
    try {
      final data = await _client
          .from('companies')
          .select()
          .eq('company_id', companyId)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('SupabaseService.getCompany error: $e');
      return null;
    }
  }

  // ==================== REAL-TIME SUBSCRIPTIONS ====================

  /// Subscribe to real-time changes on a table for a given company.
  /// Returns a RealtimeChannel that can be unsubscribed later.
  RealtimeChannel subscribeToTable({
    required String table,
    required String companyId,
    required void Function(PostgresChangePayload payload) onInsert,
    required void Function(PostgresChangePayload payload) onUpdate,
    required void Function(PostgresChangePayload payload) onDelete,
  }) {
    final channel = _client
        .channel('${table}_$companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: onInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: onUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          callback: onDelete,
        )
        .subscribe();

    return channel;
  }

  /// Unsubscribe from a real-time channel.
  Future<void> unsubscribe(RealtimeChannel channel) async {
    try {
      await _client.removeChannel(channel);
    } catch (e) {
      debugPrint('SupabaseService.unsubscribe error: $e');
    }
  }
}
