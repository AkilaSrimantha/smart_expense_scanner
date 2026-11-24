import 'package:shared_preferences/shared_preferences.dart';

class BudgetService {
  static const String _budgetKeyPrefix = 'monthly_budget_';
  static const double defaultBudget = 50000.0;

  /// Retrieves the budget for the specified year and month (e.g., 2026_11)
  static Future<double> getBudget(int year, int month) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_budgetKeyPrefix${year}_$month';
      return prefs.getDouble(key) ??
          prefs.getDouble('${_budgetKeyPrefix}default') ??
          defaultBudget;
    } catch (_) {
      return defaultBudget;
    }
  }

  /// Saves the budget for the specified year and month
  static Future<void> setBudget(int year, int month, double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_budgetKeyPrefix${year}_$month';
      await prefs.setDouble(key, amount);
      await prefs.setDouble('${_budgetKeyPrefix}default', amount);
    } catch (_) {}
  }
}
