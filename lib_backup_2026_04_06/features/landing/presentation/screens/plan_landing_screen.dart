import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/utils/currency_formatter.dart';
import 'package:planmapp/features/landing/services/guest_service.dart';
import 'package:intl/intl.dart';

class PlanLandingScreen extends StatefulWidget {
  final String planId;

  const PlanLandingScreen({super.key, required this.planId});

  @override
  State<PlanLandingScreen> createState() => _PlanLandingScreenState();
}

class _PlanLandingScreenState extends State<PlanLandingScreen> {
  final _guestService = GuestService();
  final _nameController = TextEditingController();
  
  bool _isLoading = true;
  Map<String, dynamic>? _planData;
  Map<String, dynamic>? _myDebt; // The debt found for the entered name
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlan();
  }

  Future<void> _fetchPlan() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _guestService.getPlanSummary(widget.planId);
      if (mounted) {
        setState(() {
          _planData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "No pudimos encontrar el plan. Verifica el link.";
        });
      }
    }
  }

  void _findMyDebt() {
    if (_nameController.text.trim().isEmpty) return;
    
    final nameInput = _nameController.text.trim().toLowerCase();
    final debts = (_planData?['debts_summary'] as List<dynamic>? ?? []);
    
    // Simple matching logic
    final found = debts.firstWhere((d) {
      final dName = d['name'].toString().toLowerCase();
      // Match exact or contains? Let's try flexible "contains" for UX
      return dName.contains(nameInput);
    }, orElse: () => null);

    setState(() {
      if (found != null) {
        _myDebt = found;
        _error = null; // Clear previous errors
      } else {
        _myDebt = null;
        _error = "No encontramos deudas pendientes para '$nameInput'. ¡Quizás ya pagaste o no estás en la lista!";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_planData == null) {
      return Scaffold(
        body: Center(child: Text(_error ?? "Error desconocido")),
      );
    }

    final title = _planData!['title'];
    final dateStr = _planData!['event_date'];
    final DateTime? date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final fmtDate = date != null ? DateFormat.yMMMd('es_CO').format(date) : "";

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // BRANDING
                const Icon(Icons.verified_user_outlined, size: 64, color: AppTheme.primaryBrand),
                const SizedBox(height: 16),
                const Text(
                  "PlanMapp Pagos",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 32),

                // PLAN CARD
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0,10))
                    ]
                  ),
                  child: Column(
                    children: [
                      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      if(fmtDate.isNotEmpty)
                         Padding(
                           padding: const EdgeInsets.only(top: 8),
                           child: Text(fmtDate, style: TextStyle(color: Colors.grey[600])),
                         ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // INPUT
                      const Text("¿Quién eres?", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: "Ingresa tu nombre (ej. Jorge)",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: AppTheme.primaryBrand),
                            onPressed: _findMyDebt,
                          )
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _findMyDebt(),
                      ),
                      
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _findMyDebt,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBrand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: const Text("Ver Cuánto Debo"),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // RESULT AREA
                if (_error != null && _myDebt == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),

                if (_myDebt != null)
                  _buildDebtCard(_myDebt!)
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtCard(Map<String, dynamic> debtData) {
    final total = (debtData['total_owed'] as num).toDouble();
    final details = (debtData['details'] as List<dynamic>);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.1), blurRadius: 20, offset: const Offset(0,10))
        ]
      ),
      child: Column(
        children: [
          const Text("Hola", style: TextStyle(color: Colors.grey)),
          Text(debtData['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text("Tu total a pagar es:", style: TextStyle(color: Colors.grey)),
          Text(
            CurrencyInputFormatter.format(total),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryBrand),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: Text("Detalle:", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          ...details.map((d) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(d['expense'], overflow: TextOverflow.ellipsis)),
                Text(CurrencyInputFormatter.format((d['amount'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )),
          const SizedBox(height: 24),
          const SizedBox(
             width: double.infinity,
             child: OutlinedButton(onPressed: null, child: Text("Pagar (Próximamente)")) // Placeholder for payment link integration
          )
        ],
      ),
    );
  }
}
