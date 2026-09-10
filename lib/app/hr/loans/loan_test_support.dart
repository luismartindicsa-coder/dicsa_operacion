part of '../human_resources_loans_page.dart';

@visibleForTesting
Widget hrLoanCreateFormForTesting({
  required List<Map<String, dynamic>> employees,
  required Future<String> Function(Map<String, dynamic>) onSave,
}) => _HrLoanCreateDialog(
  employees: employees,
  availableCents: 1500000,
  onSave: onSave,
);

@visibleForTesting
Widget hrLoanCashFormForTesting({
  required HrLoan loan,
  required int balanceCents,
  required Future<void> Function(Map<String, dynamic>) onSave,
}) => _HrLoanCashDialog(loan: loan, balanceCents: balanceCents, onSave: onSave);

@visibleForTesting
Widget hrLoanChannelFormForTesting({
  required HrLoan loan,
  required Future<void> Function(Map<String, dynamic>) onSave,
}) => _HrLoanChannelDialog(loan: loan, onSave: onSave);
