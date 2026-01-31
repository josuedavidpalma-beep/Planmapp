import 'package:flutter/material.dart';
import 'package:planmapp/core/config/supabase_config.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/expenses/data/models/expense_model.dart';
import 'package:planmapp/features/expenses/data/repositories/expense_repository.dart';
import 'package:planmapp/features/expenses/presentation/widgets/expense_card.dart';
import 'package:planmapp/features/expenses/presentation/screens/debt_recovery_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/expense_detail_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpensesPlanTab extends StatefulWidget {
  final String planId;
  final String userRole;

  const ExpensesPlanTab({super.key, required this.planId, this.userRole = 'member'});

  @override
  State<ExpensesPlanTab> createState() => _ExpensesPlanTabState();
}

class _ExpensesPlanTabState extends State<ExpensesPlanTab> {
  late final ExpenseRepository _expenseRepository;
  bool _isLoading = true;
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _expenseRepository = ExpenseRepository(Supabase.instance.client);
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final expenses = await _expenseRepository.getExpensesForPlan(widget.planId);
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando gastos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Total Summary logic
    final double totalPlan = _expenses.fold(0.0, (sum, item) => sum + (item.totalAmount ?? 0.0));

    return CustomScrollView(
        slivers: [
             // 1. Expenses Header (Adjusted padding)
             SliverToBoxAdapter(
                 child: Padding(
                     padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                     child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                             Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                     const Text("Gastos Reales", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                     if (totalPlan > 0)
                                        Text("\$${totalPlan.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                 ],
                             ),
                             if (widget.userRole == 'admin' || widget.userRole == 'treasurer')
                               TextButton.icon(
                                   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DebtRecoveryScreen(planId: widget.planId))),
                                   icon: const Icon(Icons.account_balance_wallet, size: 20),
                                   label: const Text("Por Cobrar"),
                                   style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primaryBrand,
                                        backgroundColor: AppTheme.primaryBrand.withOpacity(0.1),
                                   )
                               )
                         ],
                     ),
                 ),
             ),

             // 3. Expenses List or Empty State
             if (_isLoading) 
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
             else if (_expenses.isEmpty)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBrand.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.receipt_long_rounded, size: 64, color: AppTheme.primaryBrand.withOpacity(0.8)),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "¡Aún no hay gastos!",
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Sube tu primera factura o agrega un gasto manual para empezar a repartir cuentas.",
                              style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            // Action Buttons
                             ElevatedButton.icon(
                                onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => AddExpenseScreen(planId: widget.planId))
                                    ).then((_) => _loadExpenses());
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text("Agregar mi primer gasto"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBrand,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                             ),
                          ],
                        ),
                      ),
                    ),
                )
             else 
                SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (context, index) {
                            final expense = _expenses[index];
                            
                            // RELAXED PERMISSION FOR CLEANUP: Allow delete for everyone temporarily
                            // In production: final isCreator = expense.createdBy == Supabase.instance.client.auth.currentUser?.id;
                            const isCreator = true; 

                            return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                                child: ExpenseCard(
                                    expense: expense,
                                    onTap: () {
                                         // Open Detail Screen
                                         Navigator.of(context).push(
                                            MaterialPageRoute(builder: (context) => ExpenseDetailScreen(expense: expense)),
                                         ).then((_) => _loadExpenses()); // Refresh on return
                                    },
                                    onDelete: isCreator ? () async {
                                        final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                                title: const Text("¿Eliminar Gasto?"),
                                                content: const Text("Se borrarán todos los registros asociados."),
                                                actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
                                                ],
                                            )
                                        );

                                        if (confirm == true) {
                                            try {
                                                await _expenseRepository.deleteExpense(expense.id);
                                                if(mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gasto eliminado")));
                                                    _loadExpenses(); // Refresh list
                                                }
                                            } catch(e) {
                                                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                            }
                                        }
                                    } : null,
                                ),
                            );
                        },
                        childCount: _expenses.length,
                    ),
                ),
             
             // Bottom Padding
             const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
    );
  }
}
