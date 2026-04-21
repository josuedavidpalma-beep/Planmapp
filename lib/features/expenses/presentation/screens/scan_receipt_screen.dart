
import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/presentation/screens/expense_split_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class CollectionMethodInput {
  String method;
  TextEditingController controller;
  CollectionMethodInput(this.method, String initial) : controller = TextEditingController(text: initial);
  Map<String, dynamic> toJson() => {'method': method, 'account': controller.text};
}

class ScanReceiptScreen extends StatefulWidget {
  final String planId;
  final XFile imageFile;

  final bool isImportMode;

  const ScanReceiptScreen({super.key, required this.planId, required this.imageFile, this.isImportMode = false});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final ReceiptScannerService _scannerService = ReceiptScannerService();
  bool _isScanning = true;
  ParsedReceipt? _receipt;
  final _titleController = TextEditingController(); // For the expense title
  
  // Editable state
  List<ParsedItem> _items = [];
  double _total = 0.0;
  double _subtotal = 0.0;
  double _tax = 0.0;
  double _tip = 0.0;
  List<CollectionMethodInput> _collectionMethods = [CollectionMethodInput("Nequi", "")];
  List<String> _availableMethods = ["Nequi", "DaviPlata", "Transferencia Bancaria", "Breve", "Llave", "Efectivo"];

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
  
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _startLoadingAnimation();
    _processImage();
    _loadPaymentMethods();
  }
  
  Future<void> _loadPaymentMethods() async {
      try {
          final uid = Supabase.instance.client.auth.currentUser?.id;
          if (uid == null) return;
          
          final profile = await Supabase.instance.client.from('profiles').select('payment_methods').eq('id', uid).single();
          if (profile['payment_methods'] != null) {
              final methods = List<Map<String, dynamic>>.from(profile['payment_methods'].map((i) => Map<String, dynamic>.from(i)));
              if (methods.isNotEmpty && mounted) {
                  setState(() {
                      // Dispose existing controllers first
                      for (var m in _collectionMethods) { m.controller.dispose(); }
                      
                      _collectionMethods = methods.map((m) {
                          final type = m['type'] ?? "Banco";
                          if (!_availableMethods.contains(type)) _availableMethods.add(type);
                          return CollectionMethodInput(type, m['details'] ?? "");
                      }).toList();
                  });
              }
          }
      } catch (e) {
          // Fallback to default
      }
  }
  
  Future<void> _loadImage() async {
      try {
          final bytes = await widget.imageFile.readAsBytes();
          setState(() {
              _imageBytes = bytes;
          });
      } catch (e) {
          print("Error loading image bytes: $e");
      }
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
        // Warning only on Desktop Windows (Keep original logic roughly but adapted)
        // Check for non-mobile and non-web? Or just checking logical platform


        setState(() {
          _receipt = receipt;
          _items = receipt.items;
          _subtotal = receipt.subtotal ?? receipt.items.fold(0.0, (sum, item) => sum + item.price);
          _tax = receipt.tax ?? 0.0;
          _tip = receipt.tip ?? 0.0;
          _total = receipt.total ?? (_subtotal + _tax + _tip);
          
          // PROTECCIÓN MATEMÁTICA SEGURA PARA SUBTOTAL
          if (_subtotal == 0 && _total > 0) {
              _subtotal = _total - _tax - _tip;
              if (_subtotal < 0) _subtotal = 0;
          }
          
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
          'subtotal': _subtotal,
          'tax_amount': _tax,
          'tip_amount': _tip,
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
    _titleController.dispose();
    for (var m in _collectionMethods) { m.controller.dispose(); }
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

    // Validate transfer data
    for (var m in _collectionMethods) {
        if (m.controller.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Faltan los datos de transferencia en: ${m.method}. Elimina el método si no lo usarás.')));
            return;
        }
    }

    setState(() => _isScanning = true); // Loading state

    try {
        final repo = ExpenseRepository(Supabase.instance.client);
        final paymentMethodsJson = jsonEncode(_collectionMethods.map((m) => m.toJson()).toList());
        
        final expenseData = {
            'plan_id': widget.planId,
            'created_by': currentUid,
            'title': _titleController.text,
            'total_amount': _total,
            'subtotal': _subtotal,
            'tax_amount': _tax,
            'tip_amount': _tip,
            'currency': 'COP',
            'payment_method': paymentMethodsJson,
        };
        
        final itemsData = _items.map((e) => {
            'name': e.name,
            'price': e.price,
            'quantity': e.quantity,
        }).toList();

        final savedExpense = await repo.createDraftExpense(expenseData: expenseData, itemsData: itemsData);

        if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (context) => ExpenseSplitScreen(
                    expenseData: savedExpense.toJson(),
                    initialItems: savedExpense.items ?? [],
                )
            ));
        }
    } catch (e) {
        if (mounted) {
           setState(() => _isScanning = false); 
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error guardando el borrador: $e")));
        }
    }
  }

  void _handleMainAction() {
    if (widget.isImportMode) {
      _saveExpense();
    } else {
      _goToSplit();
    }
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
                  GestureDetector(
                    onTap: () {
                        if (_imageBytes != null) {
                            showDialog(
                                context: context,
                                builder: (c) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    insetPadding: const EdgeInsets.all(16),
                                    child: Stack(
                                        alignment: Alignment.topRight,
                                        children: [
                                            InteractiveViewer(
                                                child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: Image.memory(_imageBytes!),
                                                ),
                                            ),
                                            Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: CircleAvatar(
                                                    backgroundColor: Colors.black54,
                                                    child: IconButton(
                                                        icon: const Icon(Icons.close, color: Colors.white),
                                                        onPressed: () => Navigator.pop(c),
                                                    ),
                                                ),
                                            ),
                                        ],
                                    ),
                                ),
                            );
                        }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey[200],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                            if (_imageBytes != null) 
                                Image.memory(_imageBytes!, fit: BoxFit.cover)
                            else 
                                const Center(child: CircularProgressIndicator()),
                            if (_imageBytes != null)
                                Container(
                                    color: Colors.black.withOpacity(0.3),
                                    child: const Center(
                                        child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                                Icon(Icons.zoom_in, color: Colors.white, size: 32),
                                                Text("Toca para ampliar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                            ],
                                        ),
                                    ),
                                ),
                        ],
                      ),
                    ),
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
                  const Text("Medios de Recaudo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._collectionMethods.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                         padding: const EdgeInsets.only(bottom: 12),
                         child: Row(
                            children: [
                               Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                      value: item.method,
                                      decoration: const InputDecoration(labelText: "Método", border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
                                      items: _availableMethods
                                         .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (v) => setState(() => item.method = v!),
                                  )
                               ),
                               if (item.method != "Efectivo") ...[
                                   const SizedBox(width: 8),
                                   Expanded(
                                      flex: 3,
                                      child: TextField(
                                          controller: item.controller,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                              labelText: "Número/Cuenta",
                                              hintText: "Ej. 30012...",
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)
                                          ),
                                      )
                                   )
                               ],
                               if (_collectionMethods.length > 1) ...[
                                   IconButton(
                                       icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                       padding: EdgeInsets.zero,
                                       onPressed: () => setState(() {
                                           item.controller.dispose();
                                           _collectionMethods.removeAt(index);
                                       })
                                   )
                               ]
                            ]
                         )
                      );
                  }),
                  TextButton.icon(
                      onPressed: () => setState(() => _collectionMethods.add(CollectionMethodInput("DaviPlata", ""))),
                      icon: const Icon(Icons.add),
                      label: const Text("Añadir otro método de recaudo")
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
                    
                  ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      
                      // Using keys to maintain state if reordered (not reordered here but good practice)
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                                children: [
                                    // 1. Qty (Editable)
                                    SizedBox(
                                        width: 40,
                                        child: TextFormField(
                                            initialValue: item.quantity.toString(),
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(labelText: "Cant", border: InputBorder.none, isDense: true),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBrand),
                                            onChanged: (val) {
                                                final q = int.tryParse(val) ?? 1;
                                                setState(() {
                                                    _items[index] = ParsedItem(name: item.name, price: item.price, quantity: q);
                                                    _subtotal = _items.fold(0, (sum, i) => sum + (i.price * i.quantity));
                                                    _total = _subtotal + _tax + _tip;
                                                });
                                            },
                                        )
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // 2. Name (Editable)
                                    Expanded(
                                        child: TextFormField(
                                            initialValue: item.name,
                                            decoration: const InputDecoration(labelText: "Descripción", border: InputBorder.none, isDense: true),
                                            onChanged: (val) {
                                                // We don't need full setState for text, just update object
                                                _items[index] = ParsedItem(name: val, price: item.price, quantity: item.quantity);
                                            },
                                        )
                                    ),
                                    
                                    // 3. Price (Editable)
                                    SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                            initialValue: item.price.toStringAsFixed(0),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.right,
                                            decoration: const InputDecoration(labelText: "Valor Unit", border: InputBorder.none, isDense: true, prefixText: "\$"),
                                            onChanged: (val) {
                                                final p = double.tryParse(val) ?? 0.0;
                                                setState(() {
                                                    _items[index] = ParsedItem(name: item.name, price: p, quantity: item.quantity);
                                                    _subtotal = _items.fold(0, (sum, i) => sum + (i.price * i.quantity));
                                                    _total = _subtotal + _tax + _tip;
                                                });
                                            },
                                        )
                                    ),
                                    
                                    // Delete Action
                                    IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                            setState(() {
                                                _items.removeAt(index);
                                                _subtotal = _items.fold(0, (sum, i) => sum + (i.price * i.quantity));
                                                _total = _subtotal + _tax + _tip;
                                            });
                                        },
                                    )
                                ],
                            ),
                        ),
                      );
                  }),

                  const SizedBox(height: 8),
                  TextButton.icon(
                      onPressed: () {
                          setState(() {
                              _items.add(ParsedItem(name: "Nuevo Ítem", price: 0.0, quantity: 1));
                          });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Añadir otro ítem manualmente")
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Subtotal Edit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const Text("Subtotal", style: TextStyle(fontSize: 16)),
                       Text(CurrencyInputFormatter.format(_subtotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),                // Tax Edit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const Text("Impuestos", style: TextStyle(fontSize: 16, color: Colors.grey)),
                       SizedBox(
                         width: 100,
                         child: TextFormField(
                           initialValue: _tax.toStringAsFixed(0),
                           keyboardType: TextInputType.number,
                           textAlign: TextAlign.right,
                           style: const TextStyle(color: Colors.grey),
                           decoration: const InputDecoration(border: InputBorder.none, prefixText: "\$"),
                           onChanged: (val) => setState(() {
                               _tax = double.tryParse(val) ?? 0.0;
                               _total = _subtotal + _tax + _tip;
                           }),
                         )
                       )
                    ],
                  ),

                  // Tip Edit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       const Text("Propina", style: TextStyle(fontSize: 16, color: Colors.grey)),
                       SizedBox(
                         width: 100,
                         child: TextFormField(
                           initialValue: _tip.toStringAsFixed(0),
                           keyboardType: TextInputType.number,
                           textAlign: TextAlign.right,
                           style: const TextStyle(color: Colors.grey),
                           decoration: const InputDecoration(border: InputBorder.none, prefixText: "\$"),
                           onChanged: (val) => setState(() {
                               _tip = double.tryParse(val) ?? 0.0;
                               _total = _subtotal + _tax + _tip;
                           }),
                         )
                       )
                    ],
                  ),

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
                        child: Text(widget.isImportMode ? "Confirmar Importación" : "Siguiente"),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
