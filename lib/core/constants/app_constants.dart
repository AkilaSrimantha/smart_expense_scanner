import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Smart Expense Scanner';

  // Expense Categories
  static const List<String> expenseCategories = [
    'Food & Dining',
    'Groceries',
    'Transportation',
    'Utilities & Bills',
    'Shopping',
    'Entertainment',
    'Healthcare',
    'Education',
    'Other',
  ];

  // Default Currency
  static const String defaultCurrency = 'LKR';

  /// Returns an appropriate Material Icon for a category
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Groceries':
        return Icons.local_grocery_store;
      case 'Transportation':
        return Icons.directions_car;
      case 'Utilities & Bills':
        return Icons.receipt_long;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      case 'Healthcare':
        return Icons.medical_services;
      case 'Education':
        return Icons.school;
      default:
        return Icons.payments_outlined;
    }
  }

  /// Returns a themed color for a category
  static Color getCategoryColor(String category) {
    switch (category) {
      case 'Food & Dining':
        return const Color(0xFFE65100); // Deep Orange
      case 'Groceries':
        return const Color(0xFF2E7D32); // Forest Green
      case 'Transportation':
        return const Color(0xFF1565C0); // Cobalt Blue
      case 'Utilities & Bills':
        return const Color(0xFF6A1B9A); // Deep Purple
      case 'Shopping':
        return const Color(0xFFC2185B); // Pink
      case 'Entertainment':
        return const Color(0xFFF57F17); // Amber/Yellow
      case 'Healthcare':
        return const Color(0xFFC62828); // Red
      case 'Education':
        return const Color(0xFF00695C); // Teal
      default:
        return const Color(0xFF455A64); // Blue Grey
    }
  }
}
