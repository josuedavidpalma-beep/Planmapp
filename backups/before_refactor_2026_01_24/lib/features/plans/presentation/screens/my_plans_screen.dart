import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:planmapp/core/presentation/widgets/skeleton_helper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyPlansScreen extends ConsumerStatefulWidget {
  const MyPlansScreen({super.key});

  @override
  ConsumerState<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends ConsumerState<MyPlansScreen> {
  List<Plan> _plans = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
       _isLoading = true;
       _errorMessage = null; 
    });
    
    try {
      final plans = await PlanService().getPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _isLoading = false;
           _errorMessage = "Problema al cargar: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Mis Planes", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
           IconButton(
             icon: const Icon(Icons.refresh, color: Colors.white), 
             onPressed: _loadPlans,
             tooltip: "Recargar",
           )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
             begin: Alignment.topCenter, end: Alignment.bottomRight,
             colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand]
          )
        ),
        child: SafeArea(
          child: Column(
            children: [
               Expanded(
                 child: Container(
                   width: double.infinity,
                   decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
                   ),
                   child: ClipRRect(
                     borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                     child: _isLoading 
                        ? _buildLoadingState() 
                        : _errorMessage != null 
                            ? _buildErrorState()
                            : _plans.isEmpty ? _buildEmptyState() : _buildPlanList(context, _plans),
                   ),
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(_errorMessage ?? "Error desconocido", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[800], fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                      onPressed: _loadPlans,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Intentar de nuevo"),
                  )
               ],
            ),
          )
      );
  }

  Widget _buildLoadingState() {
     return ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 4,
        separatorBuilder: (_,__) => const SizedBox(height: 16),
        itemBuilder: (_,__) => SkeletonHelper.planCardSkeleton(),
     );
  }

  Widget _buildEmptyState() {
     return Center(
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                child: Icon(Icons.map_outlined, size: 60, color: Colors.grey[400]),
              ),
              const SizedBox(height: 24),
              Text("No tienes planes activos", style: TextStyle(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("¡Crea uno o únete para empezar!", style: TextStyle(color: Colors.grey)),
           ],
        )
     );
  }

  Widget _buildPlanList(BuildContext context, List<Plan> plans) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), // Extra bottom padding for FAB
      itemCount: plans.length,
      separatorBuilder: (_,__) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final plan = plans[index];
        return _PlanCard(
            plan: plan, 
            onRefresh: _loadPlans
        )
            .animate(delay: (50 * index).ms) 
            .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad)
            .fade(duration: 400.ms);
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final VoidCallback onRefresh;

  const _PlanCard({required this.plan, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isCreator = uid == plan.creatorId;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: AppTheme.primaryBrand.withOpacity(0.05),
            blurRadius: 0,
            offset: const Offset(0, 0),
            spreadRadius: 1, // Subtle border effect
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push('/plan/${plan.id}'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     // Status Badge
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                          color: AppTheme.primaryBrand.withOpacity(0.08), 
                          borderRadius: BorderRadius.circular(20),
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                            const Icon(Icons.circle, size: 8, color: AppTheme.primaryBrand),
                            const SizedBox(width: 6),
                            Text(
                              plan.status.name.toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primaryBrand,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.5
                              ),
                            ),
                         ],
                       ),
                     ),
                     // 3-Dots Menu (FIXED)
                     PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (value) async {
                             if (value == 'delete' || value == 'leave') {
                                 _handleAction(context, isCreator);
                             }
                        },
                        itemBuilder: (context) => [
                           PopupMenuItem(
                             value: isCreator ? 'delete' : 'leave',
                             child: Row(
                               children: [
                                 Icon(isCreator ? Icons.delete_outline : Icons.exit_to_app, color: Colors.red, size: 20),
                                 const SizedBox(width: 12),
                                 Text(isCreator ? "Eliminar Plan" : "Salir del Plan", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                               ],
                             ),
                           )
                        ],
                     )
                  ],
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Info Row
                Row(
                  children: [
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                       child: const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryBrand),
                     ),
                     const SizedBox(width: 12),
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text(DateFormat('MMM d, y').format(plan.eventDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(DateFormat('h:mm a').format(plan.eventDate), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                       ],
                     )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                       child: const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.primaryBrand),
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                       child: Text(
                         plan.locationName.isEmpty ? "Ubicación por definir" : plan.locationName,
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                       ),
                     ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     _buildAvatarStack(context, plan.participantCount),
                     Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black, 
                          borderRadius: BorderRadius.circular(30)
                        ),
                        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                     )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, bool isCreator) async {
       final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: Text(isCreator ? "¿Eliminar este plan?" : "¿Salir del plan?"),
          content: Text(isCreator 
            ? "Esta acción no se puede deshacer. Se borrarán todos los datos, chats y gastos." 
            : "Ya no tendrás acceso al chat ni a los gastos compartidos."),
          actions: [
              TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancelar")),
              TextButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Confirmar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
      ));

      if (confirm == true) {
          try {
              if (isCreator) {
                  await PlanService().deletePlan(plan.id);
                  if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan eliminado")));
              } else {
                  await PlanMembersService().leavePlan(plan.id);
                  if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saliste del plan")));
              }
              onRefresh(); 
          } catch (e) {
              if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
      }
  }

  Widget _buildAvatarStack(BuildContext context, int count) {
    return Row(
      children: [
        for (int i = 0; i < (count > 3 ? 3 : count); i++)
          Align(
            widthFactor: 0.7,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).cardColor, width: 2),
              ),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 14, color: Colors.white),
              ),
            ),
          ),
        if (count > 3)
          Container(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              "+${count - 3}",
              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}

