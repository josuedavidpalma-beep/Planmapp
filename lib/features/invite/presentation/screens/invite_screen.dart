import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/services/plan_service.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:planmapp/features/plan_detail/presentation/widgets/participant_list_bottom_sheet.dart';
import 'package:planmapp/features/invite/presentation/widgets/app_download_cta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteScreen extends ConsumerStatefulWidget {
  final String planId;

  const InviteScreen({super.key, required this.planId});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  bool _isLoading = true;
  Plan? _plan;
  List<PlanMember> _members = [];

  @override
  void initState() {
    super.initState();
    _loadPlanData();
  }

  Future<void> _loadPlanData() async {
    try {
      final plan = await PlanService().getPlanById(widget.planId).timeout(const Duration(seconds: 10));
      final members = await PlanMembersService().getMembers(widget.planId);
      
      // Smart Redirect: If already a member or creator, go to Dashboard
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
          final isMember = members.any((m) => m.id == uid && m.status == 'accepted');
          final isCreator = (plan != null && plan!.creatorId == uid);
          
          if (isMember || isCreator) {
              if (mounted) {
                  context.pushReplacement('/plan/${widget.planId}');
                  return;
              }
          }
      }

      if (mounted) {
        setState(() {
          _plan = plan;
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _plan = null; 
        });
      }
    }
  }

  bool _accepted = false;

  void _handleDecision(bool accept) async {
    if (accept) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.user.isAnonymous) {
          // Send anonymous or null users directly into the plan as guests.
          context.pushReplacement('/plan/${widget.planId}?guest=true');
      } else {
          _joinPlan();
      }
    } else {
      try {
          final uid = Supabase.instance.client.auth.currentUser?.id;
          if (uid != null) {
              await Supabase.instance.client.from('plan_members').upsert({
                  'plan_id': widget.planId,
                  'user_id': uid,
                  'role': 'member',
                  'status': 'declined', // Record rejection
              });
          }
      } catch (_) {}
      if (mounted) context.go('/');
    }
  }

  void _showExpressRegistration() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        bool acceptedTerms = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Completar Registro 🚀", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text("Para sumarte a este plan necesitas una cuenta de Planmapp. Solo toma 1 minuto."),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: acceptedTerms,
                        onChanged: (val) {
                          setModalState(() {
                            acceptedTerms = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "Acepto el tratamiento de mis datos personales según la Ley 1581 de 2012.",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: acceptedTerms ? () {
                        Navigator.pop(context);
                        context.push('/register');
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBrand,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("Ir a Registro", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _joinPlan() async {
      try {
          final uid = Supabase.instance.client.auth.currentUser!.id;
          await Supabase.instance.client.from('plan_members').upsert({
              'plan_id': widget.planId,
              'user_id': uid,
              'role': 'member',
              'status': 'accepted', // Crucial to override pending status
          });
          
          if (_plan != null && _plan!.creatorId != uid) {
             try {
                // Determine implicit friendship direction: uid requested creatorId
                await Supabase.instance.client.from('friendships').upsert({
                    'requester_id': uid,
                    'receiver_id': _plan!.creatorId,
                    'status': 'accepted',
                }, onConflict: 'requester_id, receiver_id');
             } catch (e) {
                 debugPrint("Implicit friendship error: $e");
             }
          }

          if (mounted) {
             context.pushReplacement('/plan/${widget.planId}');
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al unirse: $e")));
      }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Plan no encontrado")),
        body: const Center(child: Text("El enlace de invitación es inválido o el plan ha sido eliminado.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      body: Stack(
        children: [
            // Hero Image Background (Gradient for now)
            Container(
                height: MediaQuery.of(context).size.height * 0.45,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppTheme.primaryBrand, AppTheme.secondaryBrand],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                    )
                ),
                alignment: Alignment.center,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                         const Icon(Icons.celebration, color: Colors.white, size: 64),
                         const SizedBox(height: 16),
                         const Text("¡Te han invitado!", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ],
                ),
            ),
            
            // Content Card
            Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                    height: MediaQuery.of(context).size.height * 0.65,
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                             Center(
                                 child: Container(
                                     width: 40, height: 4, 
                                     margin: const EdgeInsets.only(bottom: 24),
                                     decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))
                                 )
                             ),

                             Text(_plan!.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
                             const SizedBox(height: 16),
                             
                             _buildInfoRow(Icons.calendar_today_rounded, 
                                DateFormat('EEEE d, MMMM yyyy (hh:mm a)', 'es_ES').format(_plan!.eventDate!)
                             ),
                             const SizedBox(height: 12),
                             _buildInfoRow(Icons.location_on_rounded, _plan!.locationName),
                             const SizedBox(height: 24),

                             const Text("Lista de Invitados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                             const SizedBox(height: 8),
                             
                             // Embedded Guest List Preview (Clickable)
                             InkWell(
                                 onTap: () {
                                     showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (c) => ParticipantListBottomSheet(members: _members, creatorId: _plan!.creatorId)
                                     );
                                 },
                                 borderRadius: BorderRadius.circular(12),
                                 child: Container(
                                     padding: const EdgeInsets.all(12),
                                     decoration: BoxDecoration(
                                         color: AppTheme.lightBackground,
                                         borderRadius: BorderRadius.circular(12),
                                         border: Border.all(color: Colors.grey.shade200)
                                     ),
                                     child: Row(
                                         children: [
                                             // Avatar Stack
                                             SizedBox(
                                                 width: 80,
                                                 child: Stack(
                                                     children: [
                                                         for (int i=0; i < 3 && i < _members.length; i++)
                                                            Align(
                                                                widthFactor: 0.6,
                                                                alignment: Alignment(i * 0.6 - 1, 0),
                                                                child: CircleAvatar(
                                                                    radius: 14,
                                                                    backgroundColor: Colors.white,
                                                                    child: CircleAvatar(radius: 12, backgroundColor: Colors.blueAccent, child: Text(_members[i].name[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white))),
                                                                )
                                                            )
                                                     ],
                                                 ), 
                                             ),
                                             Expanded(
                                                 child: Text(
                                                     "${_members.length} invitados", 
                                                     style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
                                                 )
                                             ),
                                             const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
                                         ],
                                     ),
                                 ),
                             ),

                             const Spacer(),
                             
                             if (_accepted) 
                                const AppDownloadCTA()
                             else ...[
                                 Row(
                                     children: [
                                         Expanded(
                                             child: OutlinedButton(
                                                 onPressed: () => _handleDecision(false),
                                                 style: OutlinedButton.styleFrom(
                                                     padding: const EdgeInsets.symmetric(vertical: 16),
                                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                     side: BorderSide(color: Colors.grey.shade300)
                                                 ),
                                                 child: const Text("Rechazar", style: TextStyle(color: Colors.grey)),
                                             ),
                                         ),
                                         const SizedBox(width: 16),
                                         Expanded(
                                             child: ElevatedButton(
                                                 onPressed: () => _handleDecision(true),
                                                 style: ElevatedButton.styleFrom(
                                                     backgroundColor: AppTheme.primaryBrand,
                                                     foregroundColor: Colors.white,
                                                     padding: const EdgeInsets.symmetric(vertical: 16),
                                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                     elevation: 4,
                                                 ),
                                                 child: const Text("¡Me Apunto! 🚀", style: TextStyle(fontWeight: FontWeight.bold)),
                                             ),
                                         ),
                                     ],
                                 )
                             ]
                        ],
                    ),
                ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppTheme.primaryBrand, size: 20)
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87))),
      ]);
  }
}
