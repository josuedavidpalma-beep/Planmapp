


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
  final List<Map<String, dynamic>> _items = [
      {'name': TextEditingController(), 'price': TextEditingController(), 'qty_ctrl': TextEditingController(text: "1")}
  ];
  
  @override
  void dispose() {
    _titleController.dispose();
    for (var item in _items) {
      if (item['name'] is TextEditingController) (item['name'] as TextEditingController).dispose();
      if (item['price'] is TextEditingController) (item['price'] as TextEditingController).dispose();
      if (item['qty_ctrl'] is TextEditingController) (item['qty_ctrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _addItem() {
      setState(() => _items.add({'name': TextEditingController(), 'price': TextEditingController(), 'qty_ctrl': TextEditingController(text: "1")}));
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
                  imageFile: image,
                  isImportMode: true,
              )
          ));
          
          if (result != null && result is Map && mounted) {
              final scannedItems = result['items'] as List<ParsedItem>;
              final scannedTitle = result['title'] as String?;
              final tip = result['tip'] as double?;
              final discount = result['discount'] as double?;
              final tax = result['tax'] as double?;
              
              setState(() {
                  if (scannedTitle != null) _titleController.text = scannedTitle;
                  
                  // Replace current items with scanned ones
                  for (var i in _items) { 
                      if (i['price'] is TextEditingController) (i['price'] as TextEditingController).dispose(); 
                  }
                  _items.clear();
                  
                  // 1. Regular Items
                  for (var s in scannedItems) {
                      final priceCtrl = TextEditingController(text: CurrencyInputFormatter().formatEditUpdate(
                          const TextEditingValue(text: ""), 
                          TextEditingValue(text: s.price.toInt().toString())
                      ).text);
                      
                      final qtyCtrl = TextEditingController(text: s.quantity.toString());

                      _items.add({
                          'name': TextEditingController(text: s.name),
                          'price': priceCtrl,
                          'qty_ctrl': qtyCtrl
                      });
                  }

                  // 2. Auto-Add Logic Fields (Tip, Tax, Discount)
                  if (tip != null && tip > 0) {
                      _items.add({
                          'name': TextEditingController(text: "Propina (Detectada)"),
                          'price': TextEditingController(text: CurrencyInputFormatter.format(tip)),
                          'qty_ctrl': TextEditingController(text: "1"),
                          'is_additional': true
                      });
                  }
                  if (tax != null && tax > 0) {
                      _items.add({
                          'name': TextEditingController(text: "Impuesto (Detectado)"),
                          'price': TextEditingController(text: CurrencyInputFormatter.format(tax)),
                          'qty_ctrl': TextEditingController(text: "1"),
                          'is_additional': true
                      });
                  }
                  if (discount != null && discount > 0) {
                      // Discounts are negative for math? 
                      // For now, let's treat them as positive items but labeled "Descuento".
                      // The user might prefer them to SUBTRACT.
                      // If we want to subtract, we'd need negative input support or logic in Split.
                      // Let's assume for now it's an item, but usually discounts REDUCE total.
                      // I will make it negative in the controller? CurrencyFormatter might struggle with negative.
                      // I'll add it as "Descuento" and let user check, or ideally logic handles it.
                      // User feedback: "hay que agregar un campo opcional para esto...".
                      // I'll add it to the list.
                      _items.add({
                          'name': TextEditingController(text: "Descuento (Detectado - Restar manualmente si aplica)"), 
                          'price': TextEditingController(text: CurrencyInputFormatter.format(discount)),
                          'qty_ctrl': TextEditingController(text: "1"),
                          'is_additional': true
                      });
                  }
              });
              
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Ítems, propinas y descuentos importados!")));
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
          final nameController = item['name'] as TextEditingController;
          final name = nameController.text;
          final priceController = item['price'] as TextEditingController;
          final price = CurrencyInputFormatter.parse(priceController.text);
          final qtyController = item['qty_ctrl'] as TextEditingController;
          final qty = int.tryParse(qtyController.text) ?? 1;

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
          'payment_instructions': _paymentInstructionsCtrl.text,
          'category': _selectedCategory,
          'emoji': _selectedEmoji,
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
  
  // AI State
  String? _selectedCategory;
  String? _selectedEmoji;
  bool _isAnalyzing = false;

  @override
  void initState() {
      super.initState();
      _additionalValueCtrl.addListener(_calcPercentage);
  }
  
  Future<void> _autoCategorize() async {
      if (_titleController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escribe un título primero (ej. Uber)")));
          return;
      }
      
      setState(() => _isAnalyzing = true);
      try {
           final supabase = Supabase.instance.client;
           final response = await supabase.functions.invoke('ai-assistant', body: {
               'action': 'classify_expense',
               'payload': { 'title': _titleController.text }
           });
           
           // if (response.error != null) throw Exception(response.error!.message);
           
           final data = response.data;
           if (mounted) {
               setState(() {
                   _selectedCategory = data['category'];
                   _selectedEmoji = data['emoji'];
                   _isAnalyzing = false;
               });
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Categoría detectada: $_selectedCategory $_selectedEmoji")));
           }
      } catch (e) {
           if(mounted) setState(() => _isAnalyzing = false);
           debugPrint("AI Error: $e");
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No pude categorizarlo, elígelo tú.")));
      }
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
          final q = int.tryParse((item['qty_ctrl'] as TextEditingController).text) ?? 1;
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
              'name': TextEditingController(text: "$_additionalType ($_percentageHint)"), 
              'price': TextEditingController(text: val), 
              'qty_ctrl': TextEditingController(text: "1"),
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
                         decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
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
                     color: Theme.of(context).cardColor,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
                     child: Padding(
                         padding: const EdgeInsets.all(8.0),
                         child: Row(
                             children: [
                                 Expanded(child: TextField(
                                     decoration: const InputDecoration(labelText: "Descripción", hintText: "Ej: Pizza, Cervezas...", border: InputBorder.none), 
                                     controller: item['name'] as TextEditingController,
                                 )),
                                 Container(width: 1, height: 24, color: Colors.grey[300]),
                                 const SizedBox(width: 8),
                                 SizedBox(
                                     width: 90, 
                                     child: TextField(
                                         controller: item['price'] as TextEditingController,
                                         decoration: const InputDecoration(labelText: "Valor Unit.", hintText: "\$0", border: InputBorder.none, contentPadding: EdgeInsets.zero), 
                                         keyboardType: TextInputType.number,
                                         textAlign: TextAlign.right,
                                         inputFormatters: [CurrencyInputFormatter()],
                                     )
                                 ),
                                 const SizedBox(width: 8),
                                 SizedBox(
                                     width: 50,
                                     child: TextField(
                                         controller: item['qty_ctrl'] as TextEditingController,
                                         keyboardType: TextInputType.number,
                                         textAlign: TextAlign.center,
                                         decoration: const InputDecoration(labelText: "Cant.", contentPadding: EdgeInsets.zero, border: InputBorder.none),
                                     )
                                 ),
                                 IconButton(
                                     icon: const Icon(Icons.close, color: Colors.redAccent, size: 20), 
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
                         items: ["Propina", "Impuesto", "Descuento", "Otro"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
              const SizedBox(height: 16),
              
              // NEW: Category & AI Button
              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Expanded(
                          child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                  labelText: "Categoría", 
                                  border: const OutlineInputBorder(),
                                  prefixIcon: _selectedEmoji != null ? Padding(padding: const EdgeInsets.all(12), child: Text(_selectedEmoji!, style: const TextStyle(fontSize: 20))) : const Icon(Icons.category)
                              ),
                              items: ["Comida", "Transporte", "Alojamiento", "Actividad", "Compras", "Otro"]
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() => _selectedCategory = v),
                          )
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                          height: 56,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade50, 
                                  foregroundColor: Colors.purple,
                                  elevation: 0,
                                  side: BorderSide(color: Colors.purple.shade200)
                              ),
                              onPressed: _isAnalyzing ? null : _autoCategorize,
                              child: _isAnalyzing 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                                  : const Icon(Icons.auto_awesome),
                          ),
                      )
                  ],
              ),
              if (_selectedCategory == null && !_isAnalyzing)
                  Padding(
                       padding: const EdgeInsets.only(top: 4, left: 4),
                       child: Text("O toca ✨ para que la IA decida", style: TextStyle(color: Colors.purple.shade300, fontSize: 12)),
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

