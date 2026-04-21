import 'package:flutter/material.dart';
import 'package:planmapp/features/plans/data/models/plan_model.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/services/invitation_service.dart';
import 'package:planmapp/features/plans/services/google_calendar_service.dart';

class PlanProfileSheet extends StatelessWidget {
  final Plan plan;
  final Map<String, dynamic> membersMap;
  final String myRole;
  final Function onDelete; // To trigger delete dialog from parent

  const PlanProfileSheet({
    super.key,
    required this.plan,
    required this.membersMap,
    required this.myRole,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
       decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: AppTheme.primaryBrand.withOpacity(0.2), width: 1))
       ),
       child: SafeArea(
         child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
               const SizedBox(height: 32),
               
               // Cabecera Principal
               CircleAvatar(
                  radius: 46,
                  backgroundColor: AppTheme.primaryBrand.withOpacity(0.1),
                  child: const Icon(Icons.celebration, size: 40, color: AppTheme.primaryBrand),
               ),
               const SizedBox(height: 16),
               
               Text(plan.title, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)
               ),
               
               const SizedBox(height: 6),
               
               Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: plan.status == PlanStatus.cancelled ? Colors.redAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Text(
                      plan.status == PlanStatus.cancelled ? "Cancelado" : "Activo",
                      style: TextStyle(
                          color: plan.status == PlanStatus.cancelled ? Colors.redAccent : Colors.greenAccent, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12
                      )
                  )
               ),
               
               const SizedBox(height: 24),
               
               // Metadata Chips
               Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      _buildMetaChip(Icons.calendar_month, DateFormat('MMM dd, hh:mm a').format(plan.date)),
                      const SizedBox(width: 12),
                      _buildMetaChip(Icons.group, "${membersMap.length} Amigos"),
                  ],
               ),
               
               const SizedBox(height: 12),
               _buildMetaChip(Icons.location_on, plan.address ?? 'Ubicación por definir'),
               
               const SizedBox(height: 32),
               const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Participantes", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold))
               ),
               const SizedBox(height: 12),
               
               // Opciones rápidas (Añadir + Carrusel)
               SizedBox(
                  height: 90,
                  child: ListView(
                     scrollDirection: Axis.horizontal,
                     children: [
                        // Add Button
                        GestureDetector(
                           onTap: () {
                              Navigator.pop(context);
                              InvitationService.inviteToPlan(plan);
                           },
                           child: Container(
                              width: 70,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                 children: [
                                     CircleAvatar(
                                         radius: 30,
                                         backgroundColor: AppTheme.primaryBrand.withOpacity(0.1),
                                         child: const Icon(Icons.person_add, color: AppTheme.primaryBrand)
                                     ),
                                     const SizedBox(height: 6),
                                     const Text("Invitar", style: TextStyle(color: AppTheme.primaryBrand, fontSize: 12, fontWeight: FontWeight.bold))
                                 ]
                              )
                           )
                        ),
                        
                        ...membersMap.entries.map((req) {
                            final m = req.value;
                            return Container(
                               width: 70,
                               margin: const EdgeInsets.only(right: 12),
                               child: Column(
                                  children: [
                                      CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Colors.grey[800],
                                          backgroundImage: m['avatar_url'] != null ? NetworkImage(m['avatar_url']) : null,
                                          child: m['avatar_url'] == null 
                                              ? Text(m['full_name'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))
                                              : null,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                          m['full_name'].toString().split(' ')[0], 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: m['role'] == 'admin' ? Colors.orangeAccent : Colors.grey[300], fontSize: 12)
                                      )
                                  ]
                               )
                            );
                        })
                     ]
                  )
               ),
               
               const SizedBox(height: 32),
               const Divider(color: Colors.white10),
               
               // Actions Menu
               ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: Colors.orangeAccent),
                  title: const Text("Exportar a Google Calendar", style: TextStyle(color: Colors.white)),
                  onTap: () async {
                      Navigator.pop(context);
                      await GoogleCalendarService.exportPlanToCalendar(plan);
                  },
               ),
               ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  title: Text(myRole == 'admin' ? "Eliminar Plan" : "Abandonar Plan", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                      Navigator.pop(context);
                      onDelete();
                  },
               )
            ]
         )
       )
    );
  }
  
  Widget _buildMetaChip(IconData icon, String text) {
      return Container(
         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
         decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
         child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                Icon(icon, size: 14, color: AppTheme.primaryBrand),
                const SizedBox(width: 8),
                Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500))
            ]
         )
      );
  }
}
