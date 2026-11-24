import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/excel_helper.dart';
import '../../core/utils/pdf_helper.dart';
import '../../models/expense_model.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../auth/login_screen.dart';
import '../scanner/scanner_screen.dart';
import '../../services/budget_service.dart';
import 'manual_expense_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;

  const DashboardScreen({super.key, this.userId = 'guest_user'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  List<ExpenseModel> _currentExpenses = [];
  String _selectedCategory = 'All';
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _showAllMonths = false;
  double _monthlyBudget = BudgetService.defaultBudget;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBudget() async {
    final b = await BudgetService.getBudget(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    if (mounted) setState(() => _monthlyBudget = b);
  }

  void _exportOptions(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export!')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('Export to PDF'),
                  subtitle: const Text('Download or share expense summary'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final path = await PdfHelper.exportExpensesToPdf(
                      expenses,
                      reportTitle:
                          'Expenses - ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                    );
                    if (path != null && mounted) {
                      _showShareOrOpenDialog(path, 'PDF Report');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Export to Excel (.xlsx)'),
                  subtitle: const Text('Export full dataset for spreadsheet apps'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final path = await ExcelHelper.exportExpensesToExcel(expenses);
                    if (path != null && mounted) {
                      _showShareOrOpenDialog(path, 'Excel File');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShareOrOpenDialog(String filePath, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title Ready'),
        content: Text('File saved successfully to:\n$filePath'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              OpenFilex.open(filePath);
            },
            child: const Text('Open'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(filePath)], text: 'My Expense Report');
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  /// Displays detailed line-item breakdown of a scanned receipt
  void _showExpenseDetails(ExpenseModel exp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final catColor = AppConstants.getCategoryColor(exp.category);
        final catIcon = AppConstants.getCategoryIcon(exp.category);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: catColor.withOpacity(0.15),
                        child: Icon(catIcon, color: catColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp.merchant,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, d MMM yyyy').format(exp.date),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          exp.category,
                          style: TextStyle(
                            color: catColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Total Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Bill Amount',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${exp.currency} ${exp.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Line Items Section
                  Text(
                    'Extracted Line Items (${exp.items.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (exp.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          'No individual item breakdown available for this receipt.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  else
                    ...exp.items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Qty: ${item.quantity}  ×  ${exp.currency} ${item.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${exp.currency} ${(item.price * item.quantity).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Actions: Share & Delete
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final text =
                                'Receipt from ${exp.merchant}\nDate: ${DateFormat('yyyy-MM-dd').format(exp.date)}\nTotal: ${exp.currency} ${exp.totalAmount.toStringAsFixed(2)}\nCategory: ${exp.category}';
                            Share.share(text);
                          },
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmDelete(exp),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(ExpenseModel exp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
          'Are you sure you want to delete the expense from "${exp.merchant}" (${exp.currency} ${exp.totalAmount.toStringAsFixed(2)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close bottom sheet
              await _supabaseService.deleteExpense(exp.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense deleted successfully'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadBudget();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadBudget();
  }

  void _showSetBudgetDialog() {
    final controller = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.savings, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              '${DateFormat('MMMM').format(_selectedMonth)} Budget',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your spending limit for this month:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: 'LKR ',
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                hintText: '50000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final amount =
                  double.tryParse(controller.text.trim().replaceAll(',', ''));
              if (amount != null && amount > 0) {
                await BudgetService.setBudget(
                  _selectedMonth.year,
                  _selectedMonth.month,
                  amount,
                );
                setState(() => _monthlyBudget = amount);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    final authService = AuthService();
    final user = authService.currentUser;
    final userEmail = user?.email ??
        (widget.userId == 'guest_user' ? 'Guest User (Demo)' : widget.userId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Text('Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signed in as:',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 6),
            Text(userEmail,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await authService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Expense Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Reports',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportOptions(_currentExpenses),
          ),
          IconButton(
            tooltip: 'Profile & Account',
            icon: const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, size: 18, color: AppColors.primary),
            ),
            onPressed: _showProfileDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: _supabaseService.getExpensesStream(widget.userId),
        builder: (context, snapshot) {
          final allExpenses = snapshot.data ?? [];

          // Filter by selected month or All Time
          final monthExpenses = _showAllMonths
              ? allExpenses
              : allExpenses.where((exp) {
                  return exp.date.year == _selectedMonth.year &&
                      exp.date.month == _selectedMonth.month;
                }).toList();

          // Filter by category and search query
          final filteredExpenses = monthExpenses.where((exp) {
            final matchesCategory =
                _selectedCategory == 'All' || exp.category == _selectedCategory;
            if (!matchesCategory) return false;

            if (_searchQuery.trim().isEmpty) return true;
            final query = _searchQuery.trim().toLowerCase();
            final matchesMerchant = exp.merchant.toLowerCase().contains(query);
            final matchesCategoryName = exp.category.toLowerCase().contains(query);
            final matchesItem =
                exp.items.any((item) => item.name.toLowerCase().contains(query));
            return matchesMerchant || matchesCategoryName || matchesItem;
          }).toList();

          _currentExpenses = filteredExpenses;

          final totalSpent = monthExpenses.fold<double>(
            0.0,
            (sum, item) => sum + item.totalAmount,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month Selector Bar with All Time Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_showAllMonths)
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _previousMonth,
                          tooltip: 'Previous Month',
                        )
                      else
                        const SizedBox(width: 48),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showAllMonths = !_showAllMonths;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              _showAllMonths
                                  ? Icons.all_inclusive
                                  : Icons.calendar_month,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showAllMonths
                                  ? 'All Time Expenses'
                                  : DateFormat('MMMM yyyy').format(_selectedMonth),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showAllMonths = !_showAllMonths;
                              });
                            },
                            child: Text(
                              _showAllMonths ? 'Monthly' : 'All',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          if (!_showAllMonths)
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _nextMonth,
                              tooltip: 'Next Month',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Info banner if there are expenses in other months
                if (!_showAllMonths && monthExpenses.isEmpty && allExpenses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt, color: Colors.amber, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You have ${allExpenses.length} receipt(s) in other months',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'e.g. ${allExpenses.first.merchant} (${DateFormat('d MMM yyyy').format(allExpenses.first.date)})',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _showAllMonths = true;
                            });
                          },
                          child: const Text('View All',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                // Total Spent Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: AppColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _showAllMonths
                                  ? 'All Time Spending'
                                  : '${DateFormat('MMMM').format(_selectedMonth)} Spending',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'LKR ${totalSpent.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${monthExpenses.length} Receipts Processed',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Monthly Budget Tracker Card
                _buildBudgetCard(totalSpent),
                const SizedBox(height: 16),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: _selectedCategory == 'All',
                          label: const Text('All'),
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = 'All';
                            });
                          },
                        ),
                      ),
                      ...AppConstants.expenseCategories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: isSelected,
                            avatar: Icon(
                              AppConstants.getCategoryIcon(cat),
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : AppConstants.getCategoryColor(cat),
                            ),
                            label: Text(cat),
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = isSelected ? 'All' : cat;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Category Pie Chart (fl_chart)
                if (monthExpenses.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Category Breakdown',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_buildCategoryTotals(monthExpenses).length} Categories',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _buildChartSections(monthExpenses),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Legend
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: _buildCategoryTotals(monthExpenses)
                                .entries
                                .map((entry) {
                              final color =
                                  AppConstants.getCategoryColor(entry.key);
                              final pct = ((entry.value / totalSpent) * 100)
                                  .toStringAsFixed(0);
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry.key} ($pct%)',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search merchant, item, or category...',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Recent Expenses List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == 'All'
                          ? (_searchQuery.isNotEmpty
                              ? 'Search Results (${filteredExpenses.length})'
                              : 'Recent Expenses')
                          : '$_selectedCategory Expenses',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (filteredExpenses.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _exportOptions(filteredExpenses),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Export'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (filteredExpenses.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No expenses matching "$_searchQuery".'
                                : (monthExpenses.isEmpty
                                    ? (_showAllMonths
                                        ? 'No expenses recorded yet.\nTap below to add manually or scan a receipt!'
                                        : 'No expenses recorded in ${DateFormat('MMMM yyyy').format(_selectedMonth)}.\nTap below to add manually or switch to All Time!')
                                    : 'No expenses in "$_selectedCategory" category.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final exp = filteredExpenses[index];
                      final catColor =
                          AppConstants.getCategoryColor(exp.category);
                      final catIcon = AppConstants.getCategoryIcon(exp.category);

                      return Dismissible(
                        key: Key(exp.id.isNotEmpty
                            ? exp.id
                            : '${exp.merchant}_${exp.date.millisecondsSinceEpoch}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Expense?'),
                              content: Text('Delete "${exp.merchant}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) {
                          _supabaseService.deleteExpense(exp.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Expense deleted'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _showExpenseDetails(exp),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: catColor.withOpacity(0.12),
                                    child: Icon(catIcon, color: catColor),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exp.merchant,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              exp.category,
                                              style: TextStyle(
                                                color: catColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Text(' • ',
                                                style: TextStyle(
                                                    color: Colors.grey)),
                                            Text(
                                              DateFormat('d MMM').format(exp.date),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (exp.items.isNotEmpty) ...[
                                              const Text(' • ',
                                                  style: TextStyle(
                                                      color: Colors.grey)),
                                              Text(
                                                '${exp.items.length} items',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${exp.currency} ${exp.totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_manual',
            onPressed: () {
              ManualExpenseSheet.show(context, widget.userId);
            },
            icon: const Icon(Icons.edit_note, color: AppColors.primary),
            label: const Text(
              'Add Manually',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 3,
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'fab_scan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScannerScreen(userId: widget.userId),
                ),
              );
            },
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text(
              'Scan AI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.primary,
            elevation: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(double totalSpent) {
    final hasBudget = _monthlyBudget > 0;
    final ratio =
        hasBudget ? (totalSpent / _monthlyBudget).clamp(0.0, 1.0) : 0.0;
    final pct = hasBudget ? ((totalSpent / _monthlyBudget) * 100) : 0.0;
    final isOverBudget = totalSpent > _monthlyBudget && hasBudget;
    final isWarning = pct >= 80 && !isOverBudget;
    final statusColor = isOverBudget
        ? AppColors.error
        : (isWarning ? AppColors.warning : AppColors.success);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOverBudget
                            ? Icons.warning_amber_rounded
                            : (isWarning
                                ? Icons.info_outline
                                : Icons.savings_outlined),
                        color: statusColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Monthly Budget',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _showSetBudgetDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'LKR ${_monthlyBudget.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined,
                            size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOverBudget
                      ? '⚠️ Over budget by LKR ${(totalSpent - _monthlyBudget).toStringAsFixed(2)}'
                      : 'LKR ${(_monthlyBudget - totalSpent).toStringAsFixed(2)} remaining',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}% used',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> _buildCategoryTotals(List<ExpenseModel> expenses) {
    final Map<String, double> categoryTotals = {};
    for (var exp in expenses) {
      categoryTotals[exp.category] =
          (categoryTotals[exp.category] ?? 0) + exp.totalAmount;
    }
    return categoryTotals;
  }

  List<PieChartSectionData> _buildChartSections(List<ExpenseModel> expenses) {
    final categoryTotals = _buildCategoryTotals(expenses);
    final totalSpent = expenses.fold<double>(
      0.0,
      (sum, item) => sum + item.totalAmount,
    );

    return categoryTotals.entries.map((entry) {
      final color = AppConstants.getCategoryColor(entry.key);
      final pct = (entry.value / totalSpent) * 100;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 46,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}
