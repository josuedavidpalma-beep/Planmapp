import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/plan_detail/domain/models/poll_model.dart';
import 'package:planmapp/features/itinerary/services/itinerary_service.dart';
import 'package:planmapp/features/itinerary/domain/models/activity.dart';
import 'package:planmapp/core/services/plan_service.dart'; // To get plan date if needed
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class PollService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _geminiApiKey = "AIzaSyB9PhkXejEfeNJvjCk8U6mnY4MelD-ejIM"; // User provided key

  // Stream of polls for a specific plan
  Stream<List<Poll>> getPollsStream(String planId) {
    final currentUserId = _supabase.auth.currentUser?.id;
    return _supabase
        .from('polls')
        .stream(primaryKey: ['id'])
        .eq('plan_id', planId)
        .order('created_at', ascending: false)
        .asyncMap((event) async {
          final List<Poll> polls = [];
          for (var pollData in event) {
             // Fetch options with votes (to check current user and count)
             final optionsRes = await _supabase
                .from('poll_options')
                .select('*, poll_votes(user_id)') // Fetching user_id to check my vote
                .eq('poll_id', pollData['id']);
             
             // In Dart, we will calculate the count since we have the full List of votes now
             for (var opt in optionsRes) {
                final votes = opt['poll_votes'] as List;
                opt['poll_votes'] = {
                  'count': votes.length,
                  'user_id': votes.any((v) => v['user_id'] == currentUserId) ? currentUserId : null
                };
             }

             pollData['poll_options'] = optionsRes;
             polls.add(Poll.fromJson(pollData, currentUserId));
          }
          return polls;
        });
  }

  // Fetch Polls (Future version)
  Future<List<Poll>> getPolls(String planId) async {
    try {
      final response = await _supabase
          .from('polls')
          .select('*, poll_options(*)') // Join options
          .eq('plan_id', planId)
          .order('created_at');
      
      final currentUserId = _supabase.auth.currentUser?.id;
      return (response as List).map((e) => Poll.fromJson(e, currentUserId)).toList().cast<Poll>();
    } catch (e) {
      throw Exception('Error cargando encuestas: $e');
    }
  }

  // Create a new Poll
  Future<void> createPoll(String planId, String question, List<String> options, {String status = 'active', DateTime? expiresAt}) async {
    // 1. Create Poll
    final pollRes = await _supabase
        .from('polls')
        .insert({
            'plan_id': planId, 
            'question': question,
            'status': status,
            'expires_at': expiresAt?.toIso8601String(),
        })
        .select()
        .single();
    
    final pollId = pollRes['id'];

    // 2. Create Options
    final optionsData = options.map((opt) => {
      'poll_id': pollId,
      'text': opt,
    }).toList();

    if (optionsData.isNotEmpty) {
      await _supabase.from('poll_options').insert(optionsData);
    }
  }

  // Vote!
  Future<void> vote(String pollId, String optionId) async {
    final userId = _supabase.auth.currentUser!.id;
    
    // Simple logic: Insert vote. Database constraint ensures 1 vote per user per option.
    // If we want "Single Choice", we might need to delete previous votes first.
    // For MVP: Let's assume Multi-Choice or just simple insert.
    await _supabase.from('poll_votes').insert({
      'poll_id': pollId,
      'option_id': optionId,
      'user_id': userId,
    });
  }
  
  Future<void> closePoll(String pollId) async {
    await _supabase.from('polls').update({'is_closed': true}).eq('id', pollId);
  }

  Future<void> promotePollToActivity(String pollId) async {
      // 1. Fetch Poll Details to find winner
      final pollRes = await _supabase.from('polls').select('*, poll_options(*, poll_votes(count))').eq('id', pollId).single();
      
      final String question = pollRes['question'];
      final String planId = pollRes['plan_id'];
      final List options = pollRes['poll_options'];

      if (options.isEmpty) return;

      // Find winner
      Map<String, dynamic>? winner;
      int maxVotes = -1;

      for (var opt in options) {
          final List votesList = opt['poll_votes'] ?? [];
          // Supabase count is tricky with nested select, assuming list length or count object
          // If we use .select('*, poll_votes(user_id)'), count is length
          // If we used .select('poll_votes(count)'), it's different.
          // Let's rely on a simpler counting here since we didn't do a count query above.
          // Wait, the query above `poll_votes(count)` returns [{count: 1}] usually.
          
          int count = 0;
          if (votesList.isNotEmpty && votesList[0] is Map && votesList[0].containsKey('count')) {
               count = votesList[0]['count'];
          } else {
               count = votesList.length; // Fallback if regular select
          }

          if (count > maxVotes) {
              maxVotes = count;
              winner = opt;
          }
      }

      if (winner == null) return;

      // 2. Create Activity
      // Default time: Tomorrow at 9AM or Plan Event Date if available
      DateTime startTime = DateTime.now().add(const Duration(days: 1)).copyWith(hour: 9, minute: 0, second: 0);
      try {
          final planRes = await _supabase.from('plans').select('event_date').eq('id', planId).maybeSingle();
          if (planRes != null && planRes['event_date'] != null) {
              startTime = DateTime.parse(planRes['event_date']).toLocal();
          }
      } catch (_) {}

      // 2. Create Activity (AI ENHANCED)
      Activity activity;
      
      try {
          // AI Attempt
          final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
          final prompt = """
            Analyze this poll result and generate a JSON for an itinerary activity.
            Context: A group trip plan.
            Poll Question: "$question"
            Winning Option: "${winner['text']}"
            
            Return JSON with these fields:
            - title: A short, catchy title (e.g. "Dinner at Mario's")
            - description: A fun description including the context that it was voted on.
            - category: One of ['food', 'transport', 'lodging', 'activity']
            - duration_minutes: Estimated duration (int)
            
            Output ONLY raw JSON.
          """;
          
          final content = [Content.text(prompt)];
          final response = await model.generateContent(content);
          final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
          
          if (text != null) {
             final data = jsonDecode(text);
             ActivityCategory cat;
             switch(data['category'].toString().toLowerCase()) {
                 case 'food': cat = ActivityCategory.food; break;
                 case 'transport': cat = ActivityCategory.transport; break;
                 case 'lodging': cat = ActivityCategory.lodging; break;
                 default: cat = ActivityCategory.activity;
             }
             
             activity = Activity(
                 id: '',
                 planId: planId,
                 title: data['title'],
                 description: data['description'],
                 locationName: winner['text'], 
                 location: null,
                 startTime: startTime, // Use calculated start time as base
                 endTime: startTime.add(Duration(minutes: data['duration_minutes'] ?? 60)),
                 category: cat
             );
          } else {
             throw Exception("No AI response");
          }
      } catch (e) {
          print("AI Failed, falling back to basic: $e");
          // Fallback
          activity = Activity(
              id: '',
              planId: planId,
              title: winner['text'],
              description: "Resultado de votación: $question",
              locationName: null, 
              location: null,
              startTime: startTime,
              category: ActivityCategory.activity,
          );
      }

      await ItineraryService().createActivity(activity);

      // 3. Close Poll
      await closePoll(pollId);
  }

  Future<void> deletePoll(String pollId) async {
       try {
           // Cascade delete handles options/votes usually, but let's be safe if no cascade
           await _supabase.from('poll_votes').delete().eq('poll_id', pollId);
           await _supabase.from('poll_options').delete().eq('poll_id', pollId);
           await _supabase.from('polls').delete().eq('id', pollId);
       } catch (e) {
           throw Exception("Error deleting poll: $e");
       }
  }
}
