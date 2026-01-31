
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/presentation/screens/expense_split_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/scan_receipt_screen.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManualExpenseForm extends StatefulWidget {
  final String planId;

  const ManualExpenseForm({super.key, required this.planId});

  @override
  State<ManualExpenseForm> createState() => _ManualExpenseFormState();
}

class _ManualExpenseFormState extends State<ManualExpenseForm> {
  final _titleController = TextEditingController();
  final _paymentInstructionsCtrl = TextEditingController(); // New
  final ImagePicker _picker = ImagePicker();
  
  // Dynamic Items
  // Stores controller for price to manage cursor position with formatter
  final List<Map<String, dynamic>> _items = [
      {'name': '', 'price': TextEditingController(), 'qty': '1'}
  ];
  
  @override
  void dispose() {
    _titleController.dispose();
    for (var item in _items) {
      if (item['price'] is TextEditingController) {
        (item['price'] as TextEditingController).dispose();
      }
    }
    super.dispose();
  }

  void _addItem() {
      setState(() => _items.add({'name': '', 'price': TextEditingController(), 'qty': '1'}));
  }

  void _removeItem(int index) {
      if (_items.length > 1) {
          final item = _items[index];
          (item['price'] as TextEditingController).dispose();
          setState(() => _items.removeAt(index));
      }
  }
  
  Future<void> _pickScan(ImageSource source) async {
      try {
          final XFile? image = await _picker.pickImage(source: source);
          if (image == null) return;
          
          if (!mounted) return;
          
          // Navigate to Scan Screen in Import Mode
          final result = await Navigator.push(context, MaterialPageRoute(
              builder: (context) => ScanReceiptScreen(
                  planId: widget.planId, 
                  imageFile: File(image.path),
                  isImportMode: true,
              )
          ));
          
          if (result != null && result is Map && mounted) {
              final scannedItems = result['items'] as List<ParsedItem>;
              final scannedTitle = result['title'] as String?;
              
              setState(() {
                  if (scannedTitle != null) _titleController.text = scannedTitle;
                  
                  // Replace current items with scanned ones
                  // Clear old controllers
                  for (var i in _items) { (i['price'] as TextEditingController).dispose(); }
                  _items.clear();
                  
                  for (var s in scannedItems) {
                      final controller = TextEditingController(text: CurrencyInputFormatter().formatEditUpdate(
                          const TextEditingValue(text: ""), 
                          TextEditingValue(text: s.price.toInt().toString())
                      ).text);
                      
                      _items.add({
                          'name': s.name,
                          'price': controller,
                          'qty': '1' // OCR doesn't return quantity usually, assume 1
                      });
                  }
              });
              
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Ítems importados correctamente!")));
          }
      } catch (e) {
          debugPrint("Error picking image: $e");
      }
  }
  
  void _goToSplit() {
      if (_titleController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Falta el título del gasto")));
          return;
      }
      
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      if (currentUid == null) return;

      // Validate items
      List<ExpenseItem> expenseItems = [];
      double total = 0;
      
      final currencyFormatter = CurrencyInputFormatter(); // static helper needed or create instance

      for (var i = 0; i < _items.length; i++) {
          final item = _items[i];
          final name = item['name'] as String;
          final priceController = item['price'] as TextEditingController;
          final price = CurrencyInputFormatter.parse(priceController.text);
          final qty = int.tryParse(item['qty']) ?? 1;

          if (name.isEmpty || price <= 0) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Revisa los ítems (Nombre y Precio requeridos)")));
               return;
          }
          
          expenseItems.add(ExpenseItem(
             id: 'temp_$i', // Temp ID
             expenseId: 'temp', 
             name: name, 
             price: price * qty, // Total for this line
             quantity: qty
          ));
          total += (price * qty);
      }
      
      final expenseData = {
          'plan_id': widget.planId,
          'created_by': currentUid,
          'title': _titleController.text,
          'total_amount': total,
          'currency': 'COP',
          'payment_instructions': _paymentInstructionsCtrl.text, // New Field
      };
      
      // Show Selection Strategy Dialog
      showModalBottomSheet(
          context: context, 
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          backgroundColor: Colors.white,
          builder: (ctx) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      const Text("👥 ¿Quiénes participan en este gasto?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      
                      // OPTION 1: AUTO SPLIT
                      ListTile(
                          leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.groups_rounded, color: AppTheme.primaryBrand),
                          ),
                          title: const Text("Todos los del plan"),
                          subtitle: const Text("Se dividirá equitativamente entre los miembros actuales."),
                          onTap: () {
                              Navigator.pop(ctx);
                              _pushSplitScreen(expenseData, expenseItems, autoSplit: true);
                          },
                      ),
                      const SizedBox(height: 12),

                      // OPTION 2: MANUAL
                      ListTile(
                          leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                              child: const Icon(Icons.touch_app_rounded, color: Colors.black87),
                          ),
                          title: const Text("Seleccionar Manualmente"),
                          subtitle: const Text("Tú eliges quiénes pagan y cuánto."),
                          onTap: () {
                              Navigator.pop(ctx);
                              _pushSplitScreen(expenseData, expenseItems, autoSplit: false);
                          },
                      ),

                      // OPTION 3: EXTERNAL GUEST
                      ListTile(
                          leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.person_add_rounded, color: Colors.amber),
                          ),
                          title: const Text("Agregar Invitado Externo"),
                          subtitle: const Text("Alguien que no está en el grupo."),
                          onTap: () {
                             Navigator.pop(ctx);
                             // Just go to manual, but show a hint or auto-open guest dialog?
                             // For simplicity: Go to manual and show snackbar hint
                             _pushSplitScreen(expenseData, expenseItems, autoSplit: false, showGuestHint: true);
                          },
                      ),
                      const SizedBox(height: 24),
                  ],
              ),
          )
      );
  }

  void _pushSplitScreen(Map<String, dynamic> data, List<ExpenseItem> items, {required bool autoSplit, bool showGuestHint = false}) {
      Navigator.push(context, MaterialPageRoute(
          builder: (context) => ExpenseSplitScreen(
              expenseData: data,
              initialItems: items,
              autoSplitAll: autoSplit,
          )
      )).then((saved) {
          if (saved == true && mounted) Navigator.pop(context);
          if (showGuestHint && saved != true && mounted) {
               // If they come back or just arriving, maybe we can't show hint easily after push returns unless we pass it TO the screen.
               // But ExpenseSplitScreen handles guest adding explicitly.
          }
      });
  }

  // Additionals State
  String _additionalType = "Propina";
  final _additionalValueCtrl = TextEditingController();
  String _percentageHint = "";

  @override
  void initState() {
      super.initState();
      _additionalValueCtrl.addListener(_calcPercentage);
  }

  void _calcPercentage() {
      final val = double.tryParse(_additionalValueCtrl.text.replaceAll('.', '')) ?? 0;
      if (val <= 0) {
          if (_percentageHint.isNotEmpty) setState(() => _percentageHint = "");
          return;
      }
      
      // Sum Items
      double subtotal = 0;
      for (var item in _items) {
          final p = double.tryParse((item['price'] as TextEditingController).text.replaceAll('.', '')) ?? 0;
          final q = int.tryParse(item['qty']) ?? 1;
          subtotal += (p * q);
      }
      
      if (subtotal > 0) {
          final pct = (val / subtotal) * 100;
          setState(() {
              _percentageHint = "Equivale al ${pct.toStringAsFixed(1)}% del subtotal";
          });
      }
  }

  void _addAdditional() {
      final val = _additionalValueCtrl.text;
      final price = double.tryParse(val.replaceAll('.', '')) ?? 0;
      
      if (price <= 0) return;
      
      setState(() {
          _items.add({
              'name': "$_additionalType ($_percentageHint)", 
              'price': TextEditingController(text: val), 
              'qty': '1',
              'is_additional': true // Marker if needed later
          });
          _additionalValueCtrl.clear();
          _percentageHint = "";
      });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
          children: [
             // ... existing header ...
             Row(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                     Expanded(
                         child: TextField(
                             controller: _titleController, 
                             decoration: const InputDecoration(labelText: "Concepto General (ej. Cena)", prefixIcon: Icon(Icons.description))
                         )
                     ),
                     const SizedBox(width: 8),
                     Container(
                         height: 56, width: 50,
                         decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                         child: IconButton(icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryBrand), onPressed: () => _pickScan(ImageSource.camera)),
                     ),
                     const SizedBox(width: 8),
                     Container(
                         height: 56, width: 50,
                         decoration: BoxDecoration(color: AppTheme.secondaryBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                         child: IconButton(icon: const Icon(Icons.photo_library_outlined, color: AppTheme.secondaryBrand), onPressed: () => _pickScan(ImageSource.gallery)),
                     )
                 ],
             ),

             const SizedBox(height: 24),
             const Align(alignment: Alignment.centerLeft, child: Text("Ítems del Gasto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
             const SizedBox(height: 8),
             
             ..._items.asMap().entries.map((entry) {
                 final index = entry.key;
                 final item = entry.value;
                 return Card(
                     margin: const EdgeInsets.only(bottom: 8),
                     elevation: 0,
                     color: Colors.grey[50],
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                     child: Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Row(
                             children: [
                                 Expanded(child: TextField(
                                     decoration: const InputDecoration(hintText: "Qué compraste?", border: InputBorder.none), 
                                     controller: TextEditingController(text: item['name'])..selection=TextSelection.collapsed(offset: item['name'].length),
                                     onChanged: (v) => item['name'] = v,
                                 )),
                                 Container(width: 1, height: 24, color: Colors.grey[300]),
                                 const SizedBox(width: 8),
                                 SizedBox(
                                     width: 90, 
                                     child: TextField(
                                         controller: item['price'],
                                         decoration: const InputDecoration(hintText: "\$0", border: InputBorder.none, contentPadding: EdgeInsets.zero), 
                                         keyboardType: TextInputType.number,
                                         textAlign: TextAlign.right,
                                         inputFormatters: [CurrencyInputFormatter()],
                                     )
                                 ),
                                 const SizedBox(width: 8),
                                 SizedBox(
                                     width: 30, 
                                     child: TextField(
                                         decoration: const InputDecoration(hintText: "#", border: InputBorder.none), 
                                         keyboardType: TextInputType.number,
                                         textAlign: TextAlign.center,
                                         controller: TextEditingController(text: item['qty'])..selection=TextSelection.collapsed(offset: item['qty'].length), 
                                         onChanged: (v) => item['qty'] = v,
                                     )
                                 ),
                                 IconButton(
                                     icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), 
                                     onPressed: () => _removeItem(index)
                                 )
                             ],
                         ),
                     ),
                 );
             }).toList(),
             
             TextButton.icon(icon: const Icon(Icons.add_circle_outline), label: const Text("Agregar ítem manual"), onPressed: _addItem),
             
             const Divider(height: 32),
             
             // ADICIONALES SECTION
             const Align(alignment: Alignment.centerLeft, child: Text("Adicionales (Propina, Impuestos)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
             const SizedBox(height: 12),
             Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                     Expanded(flex: 2, child: DropdownButtonFormField<String>(
                         value: _additionalType,
                         decoration: const InputDecoration(labelText: "Tipo", contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0), border: OutlineInputBorder()),
                         items: ["Propina", "Impuesto", "Otro"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                         onChanged: (v) => setState(() => _additionalType = v!),
                     )),
                     const SizedBox(width: 12),
                     Expanded(flex: 2, child: TextField(
                         controller: _additionalValueCtrl,
                         keyboardType: TextInputType.number,
                         inputFormatters: [CurrencyInputFormatter()],
                         decoration: const InputDecoration(labelText: "Valor", prefixText: "\$", border: OutlineInputBorder()),
                     )),
                     const SizedBox(width: 8),
                     IconButton(
                         onPressed: _addAdditional, 
                         icon: const Icon(Icons.add_task, color: AppTheme.primaryBrand),
                         style: IconButton.styleFrom(backgroundColor: AppTheme.primaryBrand.withOpacity(0.1)),
                     )
                 ],
             ),
             if (_percentageHint.isNotEmpty)
                 Padding(
                     padding: const EdgeInsets.only(top: 4),
                     child: Text(_percentageHint, style: const TextStyle(color: AppTheme.primaryBrand, fontWeight: FontWeight.bold, fontSize: 13)),
                 ),
                 
              const SizedBox(height: 24),
              TextField(
                controller: _paymentInstructionsCtrl,
                decoration: const InputDecoration(
                    labelText: "Instrucciones de Pago (Opcional)",
                    hintText: "Ej: Nequi 300 123 4567, Bancolombia...",
                    prefixIcon: Icon(Icons.payment_rounded),
                    border: OutlineInputBorder(),
                    helperText: "Tus amigos verán esto cuando les cobres.",
                ),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                 onPressed: _goToSplit,
                 style: ElevatedButton.styleFrom(
                     minimumSize: const Size(double.infinity, 54), 
                     backgroundColor: AppTheme.primaryBrand, 
                     foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                 ),
                 child: const Text("Siguiente: Repartir"),
             )
          ],
      ),
    );
  }
}
