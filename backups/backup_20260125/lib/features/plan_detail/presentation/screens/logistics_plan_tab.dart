import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plan_detail/domain/models/logistics_item.dart';

class LogisticsPlanTab extends StatefulWidget {
  final String planId;

  const LogisticsPlanTab({super.key, required this.planId});

  @override
  State<LogisticsPlanTab> createState() => _LogisticsPlanTabState();
}

class _LogisticsPlanTabState extends State<LogisticsPlanTab> {
  final _supabase = Supabase.instance.client;
  
  Stream<List<LogisticsItem>> _getLogisticsStream() {
    return _supabase
        .from('logistics_items')
        .stream(primaryKey: ['id'])
        .eq('plan_id', widget.planId)
        .order('created_at')
        .map((maps) => maps.map((e) => LogisticsItem.fromJson(e)).toList());
  }

  Future<void> _addItem(String description) async {
      await _supabase.from('logistics_items').insert({
          'plan_id': widget.planId,
          'description': description,
          'creator_id': _supabase.auth.currentUser?.id,
      });
  }

  Future<void> _toggleComplete(LogisticsItem item) async {
      await _supabase.from('logistics_items').update({
          'is_completed': !item.isCompleted
      }).eq('id', item.id);
  }

  Future<void> _assignToMe(LogisticsItem item) async {
       if (item.assignedUserId == _supabase.auth.currentUser?.id) {
           // Unassign
           await _supabase.from('logistics_items').update({'assigned_user_id': null}).eq('id', item.id);
       } else {
           // Assign
           await _supabase.from('logistics_items').update({'assigned_user_id': _supabase.auth.currentUser?.id}).eq('id', item.id);
       }
  }

  void _showAddDialog() {
      final ctrl = TextEditingController();
      showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Agregar Necesidad"),
          content: TextField(
              controller: ctrl, 
              decoration: const InputDecoration(hintText: "Ej. Hielo, Carpa, Hielera..."),
              autofocus: true,
          ),
          actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(onPressed: () async {
                  if (ctrl.text.isNotEmpty) {
                      await _addItem(ctrl.text);
                      if (mounted) Navigator.pop(ctx);
                  }
              }, child: const Text("Agregar"))
          ],
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.transparent, // Tab background
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddDialog, 
            label: const Text("Agregar ítem"),
            icon: const Icon(Icons.add),
            backgroundColor: AppTheme.primaryBrand,
        ),
        body: StreamBuilder<List<LogisticsItem>>(
            stream: _getLogisticsStream(),
            builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final items = snapshot.data!;
                
                if (items.isEmpty) {
                    return Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                const Icon(Icons.list_alt_rounded, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text("Lista Vacía", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text("Agrega cosas que hagan falta para el plan (Hielo, Comida, Transporte...)", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                ),
                            ],
                        ),
                    );
                }

                return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 16, left: 16, right: 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                        final item = items[index];
                        final isAssignedToMe = item.assignedUserId == _supabase.auth.currentUser?.id;
                        final isAssigned = item.assignedUserId != null || item.assignedGuestName != null;

                        return Card(
                            elevation: 0,
                            color: item.isCompleted ? Colors.green.withOpacity(0.05) : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: item.isCompleted ? Colors.green.withOpacity(0.3) : Colors.grey.shade200)
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                                leading: Checkbox(
                                    value: item.isCompleted,
                                    activeColor: Colors.green,
                                    onChanged: (_) => _toggleComplete(item),
                                ),
                                title: Text(
                                    item.description, 
                                    style: TextStyle(
                                        decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                        color: item.isCompleted ? Colors.grey : Theme.of(context).colorScheme.onSurface
                                    )
                                ),
                                subtitle: isAssigned 
                                    ? Row(
                                        children: [
                                            Icon(Icons.person, size: 14, color: isAssignedToMe ? AppTheme.primaryBrand : Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                                isAssignedToMe ? "Yo me encargo" : "Alguien se encarga", // Todo: Join profile name if possible or keep simple
                                                style: TextStyle(
                                                    color: isAssignedToMe ? AppTheme.primaryBrand : Colors.grey,
                                                    fontWeight: isAssignedToMe ? FontWeight.bold : FontWeight.normal,
                                                    fontSize: 12
                                                )
                                            ),
                                        ],
                                      )
                                    : const Text("Sin asignar", style: TextStyle(color: Colors.orange, fontSize: 12)),
                                trailing: isAssignedToMe || !isAssigned 
                                    ? IconButton(
                                        icon: Icon(
                                            isAssignedToMe ? Icons.back_hand : Icons.pan_tool_outlined, // "Volunteer" hand
                                            color: isAssignedToMe ? AppTheme.primaryBrand : Colors.grey
                                        ),
                                        tooltip: isAssignedToMe ? "Dejar de encargarme" : "Me ofrezco",
                                        onPressed: () => _assignToMe(item),
                                    )
                                    : null // Already assigned to someone else
                            ),
                        );
                    },
                );
            },
        )
    );
  }
}
