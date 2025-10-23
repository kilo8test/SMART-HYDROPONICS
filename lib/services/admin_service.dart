import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Store admin approval request in database
  static Future<void> createAdminRequest({
    required String userId,
    required String email,
    required String fullName,
    String? password,
  }) async {
    try {
      await _client.from('admin_requests').insert({
        'user_id': userId,
        'email': email,
        'full_name': fullName,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });
      print('✅ Admin request stored in database for: $email');
    } catch (e) {
      print('❌ Error creating admin request: $e');
      throw Exception('Failed to create admin request');
    }
  }

  // Get all pending admin requests
  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final response = await _client
          .from('admin_requests')
          .select()
          .eq('status', 'pending')
          .order('requested_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching pending requests: $e');
      return [];
    }
  }

  // Get admin request for a specific user
  static Future<Map<String, dynamic>?> getUserAdminRequest(String userId) async {
    try {
      final response = await _client
          .from('admin_requests')
          .select()
          .eq('user_id', userId)
          .limit(1);

      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching user admin request: $e');
      return null;
    }
  }

  // Approve admin request
  static Future<void> approveAdminRequest(String requestId, String approvedBy) async {
    try {
      print('🔄 Starting admin approval process for request: $requestId');

      // Get the request details first
      final request = await _client
          .from('admin_requests')
          .select('user_id, email, full_name')
          .eq('id', requestId)
          .single();

      print('📋 Request details: ${request['email']}, user_id: ${request['user_id']}');

      // Create user profile for the approved admin
      print('📝 Creating user profile...');
      await _client.from('user_profiles').insert({
        'id': request['user_id'],
        'email': request['email'],
        'full_name': request['full_name'],
        'role': 'admin',
      });
      print('✅ User profile created');

      // Update admin request status
      print('📝 Updating request status...');
      await _client
          .from('admin_requests')
          .update({
            'status': 'approved',
            'approved_at': DateTime.now().toIso8601String(),
            'approved_by': approvedBy,
          })
          .eq('id', requestId);

      print('✅ Admin request approved for: ${request['email']} - profile created');
    } catch (e) {
      print('❌ Error approving admin request: $e');
      print('🔍 Error type: ${e.runtimeType}');
      print('🔍 Error toString: ${e.toString()}');
      throw Exception('Failed to approve admin request: ${e.toString()}');
    }
  }

  // Reject admin request
  static Future<void> rejectAdminRequest(String requestId, String rejectedBy) async {
    try {
      print('🔄 Starting admin rejection process for request: $requestId');

      // Get the request details first
      final request = await _client
          .from('admin_requests')
          .select('user_id, email')
          .eq('id', requestId)
          .single();

      print('📋 Request details: ${request['email']}, user_id: ${request['user_id']}');

      // Delete from user_profiles if it exists (shouldn't for pending admins, but just in case)
      print('🗑️ Deleting user profile if exists...');
      await _client
          .from('user_profiles')
          .delete()
          .eq('id', request['user_id']);

      // Delete the admin request
      print('🗑️ Deleting admin request...');
      await _client
          .from('admin_requests')
          .delete()
          .eq('id', requestId);

      print('❌ Admin request rejected and deleted for: ${request['email']}');
    } catch (e) {
      print('❌ Error rejecting admin request: $e');
      print('🔍 Error type: ${e.runtimeType}');
      print('🔍 Error toString: ${e.toString()}');
      throw Exception('Failed to reject admin request: ${e.toString()}');
    }
  }

  // Check if user is approved admin
  static Future<bool> isApprovedAdmin(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select('role')
          .eq('id', userId)
          .single();

      return response['role'] == 'admin';
    } catch (e) {
      print('❌ Error checking admin status: $e');
      return false;
    }
  }

  // Check if any approved admins exist in the system
  static Future<bool> hasAnyApprovedAdmins() async {
    try {
      print('🔍 Querying user_profiles for admin role...');
      final response = await _client
          .from('user_profiles')
          .select('id')
          .eq('role', 'admin')
          .limit(1);

      final hasAdmins = response.isNotEmpty;
      print('🔍 hasAnyApprovedAdmins result: $hasAdmins');
      if (hasAdmins) {
        print('🔍 Found admin user ID: ${response[0]['id']}');
      } else {
        print('🔍 No admin users found in user_profiles table');
      }

      return hasAdmins;
    } catch (e) {
      print('❌ Error checking for approved admins: $e');
      print('🔍 Error type: ${e.runtimeType}');
      print('🔍 Error message: ${e.toString()}');
      return false;
    }
  }

  // Check if any admin requests exist in the system (for first admin detection)
  static Future<bool> hasAnyAdminRequests() async {
    try {
      print('🔍 Querying admin_requests table for any requests...');
      final response = await _client
          .from('admin_requests')
          .select('id')
          .limit(1);

      final hasRequests = response.isNotEmpty;
      print('🔍 hasAnyAdminRequests result: $hasRequests');
      if (hasRequests) {
        print('🔍 Found admin request ID: ${response[0]['id']}');
      } else {
        print('🔍 No admin requests found in admin_requests table');
      }

      return hasRequests;
    } catch (e) {
      print('❌ Error checking for admin requests: $e');
      print('🔍 Error type: ${e.runtimeType}');
      print('🔍 Error message: ${e.toString()}');
      return false;
    }
  }

  // Clear all data (for testing) - removes all admin requests and resets user roles
  static Future<void> clearAllData() async {
    try {
      print('🧹 Clearing all admin data...');

      // Delete all admin requests first
      print('🗑️ Deleting all admin requests...');
      await _client.from('admin_requests').delete().neq('id', '00000000-0000-0000-0000-000000000000');

      // Reset all user roles to 'user'
      print('🔄 Resetting all user roles to "user"...');
      await _client
          .from('user_profiles')
          .update({'role': 'user'})
          .neq('role', 'user');

      print('✅ All admin data cleared from database');
      print('🎯 Database is now clean - first @admin.com registration will be auto-approved');
    } catch (e) {
      print('❌ Error clearing admin data: $e');
      print('🔍 Error details: ${e.toString()}');
    }
  }
}