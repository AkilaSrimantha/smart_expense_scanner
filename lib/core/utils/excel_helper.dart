import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/expense_model.dart';

class ExcelHelper {
  /// Generates an Excel spreadsheet with expenses and saves it locally
  /// Returns the saved file path
  static Future<String?> exportExpensesToExcel(List<ExpenseModel> expenses) async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Expenses';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Header row
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Merchant'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Currency'),
        TextCellValue('Item Count'),
      ]);

      // Data rows
      for (final exp in expenses) {
        sheet.appendRow([
          TextCellValue(exp.date.toIso8601String().split('T').first),
          TextCellValue(exp.merchant),
          TextCellValue(exp.category),
          DoubleCellValue(exp.totalAmount),
          TextCellValue(exp.currency),
          IntCellValue(exp.items.length),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/expenses_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      debugPrint('Excel export error: $e');
      rethrow;
    }
  }
}
