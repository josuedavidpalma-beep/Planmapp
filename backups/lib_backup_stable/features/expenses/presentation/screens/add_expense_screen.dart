
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/presentation/screens/scan_receipt_screen.dart';
import 'package:planmapp/features/expenses/presentation/widgets/manual_expense_form.dart';

class AddExpenseScreen extends StatefulWidget {
  final String planId;

  const AddExpenseScreen({super.key, required this.planId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuevo Gasto"),
      ),
      body: ManualExpenseForm(planId: widget.planId),
    );
  }
}
