import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/social/domain/models/friendship_model.dart';
import 'package:planmapp/features/social/services/friendship_service.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:planmapp/features/matchmaker/domain/services/ai_matchmaker_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiMatchmakerScreen extends StatefulWidget {
  const AiMatchmakerScreen({super.key});

  @override
  State<AiMatchmakerScreen> createState() => _AiMatchmakerScreenState();
}

class _AiMatchmakerScreenState extends State<AiMatchmakerScreen> {
  final FriendshipService _friendshipService = FriendshipService();
  final AiMatchmakerService _aiService = AiMatchmakerService();
  
  List<Friendship> _friends = [];
  final Set<String> _selectedFriendIds = {};
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final all = await _friendshipService.getFriendships();
    if (mounted) {
      setState(() {
        _friends = all.where((f) => f.status == FriendshipStatus.accepted).toList();
        _isLoading = false;
      });
    }
    _checkMyProfile();
  }

  Future<void> _checkMyProfile() async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final myProfileRes = await Supabase.instance.client.from('profiles').select('interests, budget_level').eq('id', myId).maybeSingle();
    
    if (myProfileRes != null) {
        final interests = myProfileRes['interests'] as List<dynamic>?;
        if (interests == null || interests.isEmpty) {
            _showProgressiveProfilingModal();
        }
    }
  }

  void _showProgressiveProfilingModal() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("¿Qué vibra te gusta?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              const Text("Para que la IA funcione mejor, cuéntanos qué te gusta hacer.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              // We could navigate to the profile edit screen or handle it here
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/profile'); // or wherever they can set preferences
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ve a 'Editar Perfil' para añadir tus vibes.")));
                  },
                  child: const Text("Configurar Mis Vibes"),
                )
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("En otro momento", style: TextStyle(color: Colors.white54)),
                )
              ),
              const SizedBox(height: 24),
            ]
          )
        );
      }
    );
  }

  Future<void> _generatePlan() async {
    if (_selectedFriendIds.isEmpty || _selectedFriendIds.length > 5) return;
    
    setState(() => _isGenerating = true);
    
    try {
      final selectedFriends = _friends.where((f) => _selectedFriendIds.contains(f.id)).toList();
      
      // Convert Friendship to PlanMember format for the AI Service
      final List<PlanMember> membersForAi = selectedFriends.map((f) => PlanMember(
        id: f.friendId ?? '',
        name: f.friendName ?? 'Amigo',
        isGuest: false,
        interests: f.friendInterests,
      )).toList();

      // Add myself implicitly or assume AI knows this is a group
      // Fetch my profile
      final myId = Supabase.instance.client.auth.currentUser!.id;
      final myProfileRes = await Supabase.instance.client.from('profiles').select('nickname, display_name, interests').eq('id', myId).maybeSingle();
      if (myProfileRes != null) {
          final myInterests = myProfileRes['interests'] != null ? 
            List<String>.from((myProfileRes['interests'] as List).map((e) => e.toString())) : <String>[];
          membersForAi.add(PlanMember(
             id: myId,
             name: myProfileRes['nickname'] ?? myProfileRes['display_name'] ?? 'Yo',
             isGuest: false,
             interests: myInterests
          ));
      }

      final result = await _aiService.generatePerfectPlan(membersForAi);
      
      // Navigate to Create Plan with AI data
      if (mounted) {
         final title = result['title'] ?? 'Plan Mágico';
         final address = (result['location'] ?? 'Ubicación sorpresa').toString() + " • Presupuesto: " + (result['budget'] ?? '\$\$').toString();
         // We use extra parameters to directly inject title and address into CreatePlanScreen
         context.push('/create-plan', extra: {
             'initialTitle': title,
             'initialAddress': address,
         });
      }
      
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
    } finally {
       if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Planmapp AI Matchmaker ✨"),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
          children: [
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                    color: AppTheme.primaryBrand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.3))
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Row(
                       children: [
                         Icon(Icons.auto_awesome, color: AppTheme.primaryBrand),
                         SizedBox(width: 8),
                         Text("Descubre el Plan Perfecto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       ],
                     ),
                     const SizedBox(height: 8),
                     Text(
                       "Selecciona entre 1 y 5 amigos. Nuestra Inteligencia Artificial leerá sus gustos ('Vibes') y les diseñará una actividad a medida.",
                       style: TextStyle(color: Colors.grey[400], fontSize: 14),
                     )
                   ],
                 ),
               ),
             ),
             const Divider(),
             Expanded(
               child: _friends.isEmpty 
                  ? const Center(child: Text("Necesitas añadir amigos primero."))
                  : ListView.builder(
                     itemCount: _friends.length,
                     itemBuilder: (context, index) {
                        final f = _friends[index];
                        final isSelected = _selectedFriendIds.contains(f.id);
                        
                        return ListTile(
                           leading: CircleAvatar(
                              backgroundImage: f.friendAvatarUrl != null ? NetworkImage(f.friendAvatarUrl!) : null,
                              child: f.friendAvatarUrl == null ? const Icon(Icons.person) : null,
                           ),
                           title: Text(f.friendName ?? "Amigo"),
                           subtitle: Text(f.friendInterests.isNotEmpty ? f.friendInterests.join(', ') : 'Sin Vibes registrados', style: const TextStyle(fontSize: 12)),
                           trailing: Checkbox(
                              value: isSelected,
                              activeColor: AppTheme.primaryBrand,
                              onChanged: (val) {
                                  setState(() {
                                     if (val == true) {
                                         if (_selectedFriendIds.length < 5) _selectedFriendIds.add(f.id);
                                         else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Máximo 5 amigos")));
                                     } else {
                                         _selectedFriendIds.remove(f.id);
                                     }
                                  });
                              },
                           ),
                           onTap: () {
                               setState(() {
                                   if (isSelected) _selectedFriendIds.remove(f.id);
                                   else if (_selectedFriendIds.length < 5) _selectedFriendIds.add(f.id);
                               });
                           },
                        );
                     }
                  )
             )
          ],
        ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: (_selectedFriendIds.isEmpty || _isGenerating) ? null : _generatePlan,
            style: ElevatedButton.styleFrom(
               backgroundColor: AppTheme.primaryBrand,
               foregroundColor: Colors.white,
               padding: const EdgeInsets.symmetric(vertical: 16),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(_isGenerating ? "Consultando a Gemini..." : "Generar Plan Mágico (${_selectedFriendIds.length})"),
          ),
        ),
      ),
    );
  }
}
