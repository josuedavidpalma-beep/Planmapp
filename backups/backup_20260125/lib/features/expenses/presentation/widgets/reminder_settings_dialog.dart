import 'package:flutter/material.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class ReminderSettingsDialog extends StatefulWidget {
  final String planId;
  final int initialFrequency;
  final String initialChannel;

  const ReminderSettingsDialog({super.key, required this.planId, required this.initialFrequency, required this.initialChannel});

  @override
  State<ReminderSettingsDialog> createState() => _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState extends State<ReminderSettingsDialog> {
  late int _selectedFrequency;
  late String _selectedChannel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedFrequency = widget.initialFrequency;
    _selectedChannel = widget.initialChannel;
  }

  Future<void> _save() async {
      setState(() => _isLoading = true);
      try {
          await PlanService().updatePlanSettings(widget.planId, _selectedFrequency, channel: _selectedChannel);
          if (mounted) Navigator.pop(context, true);
      } catch (e) {
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              setState(() => _isLoading = false);
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text("Configurar Cobro Automático"),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const Text("Define la frecuencia con la que enviaremos recordatorios a los participantes con deudas pendientes."),
                const SizedBox(height: 16),
                _buildOption("Desactivado", 0),
                _buildOption("Diario", 1),
                _buildOption("Semanal", 7),
                _buildOption("Quincenal", 15),
                _buildOption("Mensual", 30),
                
                const Divider(height: 32),
                const Text("Canal de Envío:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                    children: [
                        _buildChannelChip("WhatsApp", "whatsapp", Icons.message),
                        const SizedBox(width: 8),
                        _buildChannelChip("Email", "email", Icons.email),
                    ],
                )
            ],
        ),
        actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white),
                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Guardar"),
            )
        ],
    );
  }

  Widget _buildChannelChip(String label, String value, IconData icon) {
      final isSelected = _selectedChannel == value;
      return FilterChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey), const SizedBox(width: 4), Text(label)]),
          selected: isSelected,
          onSelected: (v) => setState(() => _selectedChannel = value),
          selectedColor: AppTheme.primaryBrand,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      );
  }

  Widget _buildOption(String label, int value) {
      return RadioListTile<int>(
          title: Text(label),
          value: value, 
          groupValue: _selectedFrequency, 
          onChanged: (v) => setState(() => _selectedFrequency = v!),
          dense: true,
          contentPadding: EdgeInsets.zero,
      );
  }
}
