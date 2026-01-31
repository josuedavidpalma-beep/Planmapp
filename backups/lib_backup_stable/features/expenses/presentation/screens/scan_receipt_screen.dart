
import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/presentation/screens/expense_split_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanReceiptScreen extends StatefulWidget {
  final String planId;
  final File imageFile;

  final bool isImportMode;

  const ScanReceiptScreen({super.key, required this.planId, required this.imageFile, this.isImportMode = false});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  // ... existing code ...
  
  // Existing init and process code ...

  // Modified Save/Action Logic
  Future<void> _handleMainAction() async {
      if (widget.isImportMode) {
          // Return the items to the caller
          Navigator.pop(context, {
              'items': _items,
              'total': _total,
              'title': _titleController.text.isNotEmpty ? _titleController.text : null
          });
          return;
      }
      
      // Original logic for "Go to Split" (Legacy or Direct mode)
       _goToSplit();
  }
  
  // Override _goToSplit or just use _handleMainAction in the button
  
  // ... existing code ...
  final ReceiptScannerService _scannerService = ReceiptScannerService();
  bool _isScanning = true;
  ParsedReceipt? _receipt;
  final _titleController = TextEditingController(); // For the expense title
  
  // Editable state
  List<ParsedItem> _items = [];
  double _total = 0.0;
  String _paymentMethod = "Efectivo";
  
  // Loading Animation
  int _loadingIndex = 0;
  late Timer _timer;
  final List<String> _loadingMessages = [
      "Analizando imagen...",
      "Detectando texto...",
      "Identificando precios...",
      "Organizando ítems...",
      "Casi listo..."
  ];

  @override
  void initState() {
    super.initState();
    _startLoadingAnimation();
    _processImage();
  }
  
  void _startLoadingAnimation() {
      _timer = Timer.periodic(const Duration(milliseconds: 800), (t) {
          if (mounted) {
              setState(() {
                  _loadingIndex = (_loadingIndex + 1) % _loadingMessages.length;
              });
          }
      });
  }

  Future<void> _processImage() async {
    try {
      final receipt = await _scannerService.scanReceipt(widget.imageFile);
      if (mounted) {
        if (!Platform.isAndroid && !Platform.isIOS) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("⚠️ Modo Windows: Usando recibo de ejemplo (El escaner real requiere Móvil)"),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 4),
                )
             );
        }

        setState(() {
          _receipt = receipt;
          _items = receipt.items;
          _total = receipt.total ?? receipt.items.fold(0.0, (sum, item) => sum + item.price);
          _isScanning = false;
        });
        _timer.cancel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning: $e')));
        setState(() => _isScanning = false);
        _timer.cancel();
      }
    }
  }
  
  Future<void> _saveExpense() async {
    if (_titleController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, dale un nombre al gasto')));
        return;
    }
    
    // Save to Supabase
     try {
        final repo = ExpenseRepository(Supabase.instance.client);
        final user = Supabase.instance.client.auth.currentUser;

        if (user == null) throw Exception("No user found");
        
        // 1. Prepare Data
        final expenseData = {
          'plan_id': widget.planId,
          'created_by': user.id,
          'title': _titleController.text,
          'total_amount': _total,
          'currency': 'COP',
        };
        
        final itemsData = _items.map((e) => {
            'name': e.name,
            'price': e.price,
            'quantity': 1,
        }).toList();

        await repo.createFullExpense(expenseData: expenseData, itemsData: itemsData);

        if (mounted) {
          // Double pop: Close Scan Screen AND Add Expense Screen to go back to Plan Detail
           Navigator.of(context)..pop()..pop();
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gasto escaneado guardado correctamente!")),
          );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error guardando: $e")),
          );
        }
      }
  }

  @override
  void dispose() {
    _scannerService.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _goToSplit() async {
    if (_titleController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, dale un nombre al gasto')));
        return;
    }
    
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (currentUid == null) return;

    // Convert parsed items to ExpenseItems
    final expenseItems = _items.map((e) => ExpenseItem(
        id: 'scan_${e.name}', // Temp ID
        expenseId: 'temp',
        name: e.name,
        price: e.price,
        quantity: 1
    )).toList();

    final expenseData = {
        'plan_id': widget.planId,
        'created_by': currentUid,
        'title': _titleController.text,
        'total_amount': _total,
        'currency': 'COP',
        'payment_method': _paymentMethod,
    };
    
    // Navigate to Split Screen
    // We replace the current route so back button goes to Add Screen or Plan Detail
    Navigator.push(context, MaterialPageRoute(
        builder: (context) => ExpenseSplitScreen(
            expenseData: expenseData,
            initialItems: expenseItems
        )
    )).then((saved) {
        if (saved == true && mounted) {
            Navigator.of(context)..pop()..pop(); // Close Scan and Add Screen
        }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Revisar Factura")),
      body: _isScanning
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const CircularProgressIndicator(),
                   const SizedBox(height: 24),
                   AnimatedSwitcher(
                       duration: const Duration(milliseconds: 500),
                       child: Text(
                           _loadingMessages[_loadingIndex],
                           key: ValueKey(_loadingIndex),
                           style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey)
                       ),
                   ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Preview
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[200],
                        image: DecorationImage(image: FileImage(widget.imageFile), fit: BoxFit.cover)),
                  ),
                  const SizedBox(height: 24),
                  
                  // Main Info
                  TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                          labelText: "Nombre del Gasto (Ej. Almuerzo)",
                          border: OutlineInputBorder(),
                      ),
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                     value: _paymentMethod,
                     decoration: const InputDecoration(labelText: "Medio de Pago", border: OutlineInputBorder()),
                     items: ["Efectivo", "Nequi/Daviplata", "Tarjeta Crédito", "Transferencia", "Otro"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                     onChanged: (v) => setState(() => _paymentMethod = v!),
                 ),

                  const SizedBox(height: 24),
                  const Text("Ítems Detectados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  // Items List
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No detectamos ítems automáticamente. Puedes continuar y agregarlos manualmente luego."),
                    ),
                    
                  ..._items.map((item) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(item.name),
                      trailing: Text("\$${item.price.toStringAsFixed(0)}"),
                    ),
                  )),

                  const SizedBox(height: 16),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const Text("TOTAL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                       Text(
                        "\$${_total.toStringAsFixed(0)}", 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBrand),
                       ),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                   SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _handleMainAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBrand,
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(widget.isImportMode ? "Confirmar Importación" : "Siguiente: Repartir"),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
