import 'package:flutter/material.dart';

class LogisticsPlanTab extends StatelessWidget {
  final String planId;

  const LogisticsPlanTab({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(context, "Por Traer / Comprar"),
        const SizedBox(height: 12),
        _buildTaskItem("Hielo y Vasos", "Josué", true),
        _buildTaskItem("Snacks", "María", false),
        _buildTaskItem("Juegos de Mesa", null, false), // Unassigned
        
        const SizedBox(height: 24),
        OutlinedButton.icon(
           onPressed: () {},
           icon: const Icon(Icons.add),
           label: const Text("Agregar Tarea")
        )
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTaskItem(String title, String? assignee, bool isDone) {
    return Card(
      elevation: 0,
      color: isDone ? Colors.green[50] : Colors.grey[50],
      shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
         side: BorderSide(color: isDone ? Colors.green[200]! : Colors.grey[200]!)
      ),
      child: ListTile(
        leading: Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? Colors.green : Colors.grey
        ),
        title: Text(title, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null)),
        subtitle: assignee != null ? Text("Encargado: $assignee") : const Text("Sin asignar", style: TextStyle(color: Colors.orange)),
        trailing: const Icon(Icons.more_vert, size: 20),
      ),
    );
  }
}
