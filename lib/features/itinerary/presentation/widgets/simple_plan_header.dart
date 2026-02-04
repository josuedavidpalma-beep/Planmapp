import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';

class SimplePlanHeader extends StatelessWidget {
  final Plan plan;
  final bool canEdit;
  final VoidCallback onEditDate;
  final VoidCallback onEditTime; // NEW
  final VoidCallback onEditLocation;
  final Function(String) onPaymentModeChanged;
  final VoidCallback onEditDescription;

  const SimplePlanHeader({
    super.key,
    required this.plan,
    required this.canEdit,
    required this.onEditDate,
    required this.onEditTime, // NEW
    required this.onEditLocation,
    required this.onPaymentModeChanged,
    required this.onEditDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                    border: Border.all(color: Colors.grey.withOpacity(0.1))
                ),
                child: Column(
                    children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(child: _buildField(
                                    context, 
                                    label: "FECHA", 
                                    value: plan.eventDate != null 
                                        ? DateFormat('EEE d MMM', 'es_CO').format(plan.eventDate!)
                                        : "Pendiente",
                                    icon: Icons.calendar_today_rounded,
                                    onTap: canEdit ? onEditDate : null
                                )),
                                Container(height: 40, width: 1, color: Colors.grey[200]),
                                Expanded(child: _buildField(
                                    context,
                                    label: "HORA",
                                    value: plan.eventDate != null
                                        ? DateFormat('h:mm a').format(plan.eventDate!)
                                        : "--:--",
                                    icon: Icons.access_time_rounded,
                                    onTap: canEdit ? onEditTime : null
                                )),
                                Container(height: 40, width: 1, color: Colors.grey[200]),
                                Expanded(child: _buildPaymentField(context)),
                            ],
                        ),
                        const Divider(height: 32, thickness: 0.5),
                         Row(
                           children: [
                             Expanded(child: _buildField(
                                    context,
                                    label: "LUGAR",
                                    value: plan.locationName.isNotEmpty ? plan.locationName : "Por definir",
                                    icon: Icons.location_on_outlined,
                                    onTap: canEdit ? onEditLocation : null
                                )),
                           ],
                         ),
                        
                        // OBSERVATIONS SECTION (Auto-filled by Polls)
                        if (plan.description != null && plan.description!.isNotEmpty) ...[
                            const Divider(height: 32, thickness: 0.5),
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.amber.withOpacity(0.3))
                                ),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                                Row(
                                                    children: [
                                                        const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                                                        const SizedBox(width: 8),
                                                        Text("OBSERVACIONES & DECISIONES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber[900], letterSpacing: 1.0)),
                                                    ],
                                                ),
                                                if (canEdit)
                                                    InkWell(
                                                        onTap: onEditDescription,
                                                        child: Icon(Icons.edit, size: 14, color: Colors.amber[900]),
                                                    )
                                            ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(plan.description!, style: TextStyle(fontSize: 13, color: Colors.brown[900], height: 1.4)),
                                    ],
                                ),
                            )
                        ],
                    ],
                ),
            )
        ],
      ),
    ).animate().fade().slideY(begin: -0.1, duration: 400.ms);
  }

  Widget _buildField(BuildContext context, {required String label, required String value, required IconData icon, VoidCallback? onTap}) {
      return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: AppTheme.primaryBrand),
                          const SizedBox(width: 6),
                          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                          value, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                      )
                  ],
              ),
          ),
      );
  }

  Widget _buildPaymentField(BuildContext context) {
      final modes = {
        'individual': {'icon': Icons.person_outline, 'label': 'Individual', 'color': Colors.blue},
        'pool': {'icon': Icons.savings_outlined, 'label': 'Vaca', 'color': Colors.orange},
        'guest': {'icon': Icons.card_giftcard, 'label': 'Invitado', 'color': Colors.purple},
        'split': {'icon': Icons.receipt_long, 'label': 'Dividir', 'color': Colors.green},
      };
      
      final current = modes[plan.paymentMode] ?? modes['individual']!;
      final color = current['color'] as Color;
      final icon = current['icon'] as IconData;
      final label = current['label'] as String;

      return InkWell(
          onTap: canEdit ? () => _showPaymentModeDialog(context) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: color),
                          const SizedBox(width: 6),
                          const Text("PAGO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                          label, 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                      )
                  ],
              ),
          ),
      );
  }

  void _showPaymentModeDialog(BuildContext context) {
      showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text("Modo de Pago", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildModeOption(ctx, 'individual', "Individual", Icons.person_outline, Colors.blue, "Cada quien paga lo suyo"),
              _buildModeOption(ctx, 'pool', "Vaca / Fondo", Icons.savings_outlined, Colors.orange, "Recogemos dinero antes"),
              _buildModeOption(ctx, 'split', "Dividir Cuenta", Icons.receipt_long, Colors.green, "Se divide el total al final"),
              _buildModeOption(ctx, 'guest', "Invitación", Icons.card_giftcard, Colors.purple, "Todo corre por mi cuenta"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption(BuildContext ctx, String mode, String title, IconData icon, Color color, String subtitle) {
      final isSelected = plan.paymentMode == mode;
      return ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: isSelected ? Icon(Icons.check_circle, color: color) : null,
        onTap: () {
          onPaymentModeChanged(mode);
          Navigator.pop(ctx);
        },
      );
  }
}
