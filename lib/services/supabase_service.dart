import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';

class SupabaseService {
  static const String tableName = 'expenses';

  bool get isConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory fallback data when Supabase credentials are not yet entered
  static final List<ExpenseModel> _mockExpenses = [
    ExpenseModel(
      id: 'local_1',
      userId: 'guest_user',
      merchant: 'Keells Super',
      category: 'Groceries',
      totalAmount: 4250.00,
      currency: 'LKR',
      date: DateTime.now().subtract(const Duration(hours: 3)),
      items: [
        ExpenseItem(name: 'Fresh Milk 1L', price: 520, quantity: 2),
        ExpenseItem(name: 'Whole Wheat Bread', price: 210, quantity: 1),
        ExpenseItem(name: 'Eggs (Pack of 10)', price: 650, quantity: 1),
      ],
    ),
    ExpenseModel(
      id: 'local_2',
      userId: 'guest_user',
      merchant: 'Perera & Sons',
      category: 'Food & Dining',
      totalAmount: 1150.00,
      currency: 'LKR',
      date: DateTime.now().subtract(const Duration(days: 1)),
      items: [
        ExpenseItem(name: 'Chicken Pastry', price: 220, quantity: 2),
        ExpenseItem(name: 'Iced Coffee', price: 350, quantity: 2),
      ],
    ),
    ExpenseModel(
      id: 'local_3',
      userId: 'guest_user',
      merchant: 'Ceypetco Fuel Station',
      category: 'Transportation',
      totalAmount: 3500.00,
      currency: 'LKR',
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  static final StreamController<List<ExpenseModel>> _mockController =
      StreamController<List<ExpenseModel>>.broadcast();

  /// Add new expense
  Future<String> addExpense(ExpenseModel expense) async {
    final client = _client;
    if (client != null) {
      try {
        final row = {
          'user_id': expense.userId,
          'merchant': expense.merchant,
          'category': expense.category,
          'total_amount': expense.totalAmount,
          'currency': expense.currency,
          'date': expense.date.toIso8601String(),
          'image_url': expense.imageUrl,
          'items': expense.items.map((i) => i.toMap()).toList(),
        };

        final response =
            await client.from(tableName).insert(row).select().single();
        return response['id'].toString();
      } catch (e) {
        debugPrint('Supabase addExpense error: $e');
        rethrow;
      }
    } else {
      // Local in-memory fallback
      final newExpense = ExpenseModel(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        userId: expense.userId,
        merchant: expense.merchant,
        category: expense.category,
        totalAmount: expense.totalAmount,
        currency: expense.currency,
        date: expense.date,
        imageUrl: expense.imageUrl,
        items: expense.items,
        createdAt: expense.createdAt,
      );
      _mockExpenses.insert(0, newExpense);
      _mockController.add(List.from(_mockExpenses));
      return newExpense.id;
    }
  }

  /// Update existing expense
  Future<void> updateExpense(ExpenseModel expense) async {
    final client = _client;
    if (client != null) {
      try {
        await client.from(tableName).update({
          'merchant': expense.merchant,
          'category': expense.category,
          'total_amount': expense.totalAmount,
          'currency': expense.currency,
          'date': expense.date.toIso8601String(),
          'items': expense.items.map((i) => i.toMap()).toList(),
        }).eq('id', expense.id);
      } catch (e) {
        debugPrint('Supabase updateExpense error: $e');
        rethrow;
      }
    } else {
      final index = _mockExpenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _mockExpenses[index] = expense;
        _mockController.add(List.from(_mockExpenses));
      }
    }
  }

  /// Delete expense by ID
  Future<void> deleteExpense(String expenseId) async {
    final client = _client;
    if (client != null) {
      try {
        await client.from(tableName).delete().eq('id', expenseId);
      } catch (e) {
        debugPrint('Supabase deleteExpense error: $e');
        rethrow;
      }
    } else {
      _mockExpenses.removeWhere((e) => e.id == expenseId);
      _mockController.add(List.from(_mockExpenses));
    }
  }

  /// Real-time stream of expenses for a specific user
  Stream<List<ExpenseModel>> getExpensesStream(String userId) async* {
    final client = _client;
    if (client != null) {
      // 1. Initial REST fetch for instant, reliable loading without waiting for websocket
      try {
        final initialRows = await client
            .from(tableName)
            .select()
            .eq('user_id', userId)
            .order('date', ascending: false);
        yield (initialRows as List)
            .map((row) => ExpenseModel.fromMap(row, row['id'].toString()))
            .toList();
      } catch (e) {
        debugPrint('Supabase initial fetch error: $e');
      }

      // 2. Realtime replication stream
      try {
        yield* client
            .from(tableName)
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('date', ascending: false)
            .map((rows) {
              return rows
                  .map((row) => ExpenseModel.fromMap(row, row['id'].toString()))
                  .toList();
            });
      } catch (e) {
        debugPrint('Supabase stream error: $e');
      }
    } else {
      // Return local data immediately
      yield List.from(_mockExpenses);
      yield* _mockController.stream;
    }
  }
}
