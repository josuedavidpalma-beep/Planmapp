import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/plan_detail/domain/models/poll_model.dart';
import 'package:planmapp/features/itinerary/services/itinerary_service.dart';
import 'package:planmapp/features/itinerary/domain/models/activity.dart';
import 'package:planmapp/core/services/plan_service.dart'; // To get plan date if needed
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:planmapp/core/config/api_config.dart';

class PollService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _geminiApiKey = ApiConfig.geminiApiKey;

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
          try {
            for (var pollData in event) {
              try {
                  // Fetch options and JOIN VOTES -> PROFILES
                  final optionsRes = await _supabase
                      .from('poll_options')
                      .select('*, poll_votes(user_id)') // Restore Votes (Count only, no profiles to avoid RLS crash) 
                      .eq('poll_id', pollData['id'])
                      .order('id'); // Stable order
                  
                  // DEBUG: Check if we got options
                  // print("Poll ${pollData['id']} Options Fetched: ${optionsRes.length}"); 
                  
                  polls.add(Poll.fromJson({ ...pollData, 'poll_options': optionsRes}, currentUserId));
              } catch (e) {
                  print("Error fetching options for poll ${pollData['id']}: $e");
                  // Fallback: Add poll with empty options so it at least appears
                  polls.add(Poll.fromJson({ ...pollData, 'poll_options': []}, currentUserId));
              }
            }
          } catch (e) {
            print("Critical Stream Error: $e");
          }
          return polls;
        });
  }

  // Fetch Polls (Future version)
  Future<List<Poll>> getPolls(String planId) async {
    try {
      // Future version not used in stream builder but updated for consistency
      return []; 
    } catch (e) {
      throw Exception('Error cargando encuestas: $e');
    }
  }

  // Create a new Poll
  Future<Poll> createPoll(String planId, String question, List<Map<String, dynamic>> options, {String status = 'active', String type = 'text', DateTime? expiresAt}) async {
    final userId = _supabase.auth.currentUser!.id;

    // 1. Create Poll
    final pollRes = await _supabase
        .from('polls')
        .insert({
            'plan_id': planId, 
            'question': question,
            'status': status,
            'type': type,
            'expires_at': expiresAt?.toIso8601String(),
            // 'creator_id': userId, // If schema has it. Assuming RLS handles it or schema default.
        })
        .select()
        .single();
    
    final pollId = pollRes['id'];

    // 2. Create Options
    // options is now List<Map> to support quantity: [{'text': 'Soda', 'quantity': 2}]
    final optionsData = options.map((opt) => {
      'poll_id': pollId,
      'text': opt['text'],
      'quantity': opt['quantity'] ?? 1,
    }).toList();

    List<PollOption> createdOptions = [];
    if (optionsData.isNotEmpty) {
      try {
          final optsRes = await _supabase.from('poll_options').insert(optionsData).select();
          createdOptions = (optsRes as List).map((o) => PollOption.fromJson(o, userId)).toList();
      } catch (e) {
          throw Exception("Error insertando opciones (${optionsData.length}): $e");
      }
    }

    return Poll.fromJson({...pollRes, 'poll_options': []}, userId).copyWith(options: createdOptions);
  }

  // Toggle Vote (Claim/Unclaim or Vote/Unvote)
  Future<void> toggleVote(String pollId, String optionId, String type) async {
    final userId = _supabase.auth.currentUser!.id;
    
    // Check if I voted
    final existing = await _supabase.from('poll_votes').select().eq('option_id', optionId).eq('user_id', userId).maybeSingle();

    if (existing != null) {
        // Unvote (Unclaim)
         await _supabase.from('poll_votes').delete().eq('option_id', optionId).eq('user_id', userId);
    } else {
        // Vote (Claim)
        // If Item, check if anyone else claimed it first (Exclusive/Atomic check best done in DB but here is okay for MVP)
        if (type == 'items') {
             final anyVote = await _supabase.from('poll_votes').select().eq('option_id', optionId).maybeSingle();
             if (anyVote != null) throw Exception("Este ítem ya fue asignado a otro participante.");
        }
        await _supabase.from('poll_votes').insert({'poll_id': pollId, 'option_id': optionId, 'user_id': userId});
    }
  }
  
  Future<void> closePoll(String pollId) async {
    await _supabase.from('polls').update({'is_closed': true}).eq('id', pollId);
  }

  Future<void> promotePollToActivity(String pollId) async {
      // 1. Fetch Poll Details to find winner
      // We need deeper data for 'items' (who voted), so we fetch generic first
      final pollRes = await _supabase.from('polls').select('*').eq('id', pollId).single();
      
      final String question = pollRes['question'];
      final String planId = pollRes['plan_id'];
      final String type = pollRes['type'] ?? 'text';

      // Special Handling for ITEMS (Checklist)
      if (type == 'items') {
           final optionsRes = await _supabase.from('poll_options')
              .select('*, poll_votes(user_id, profiles(full_name))')
              .eq('poll_id', pollId);
           
           final StringBuffer logBuffer = StringBuffer();
           logBuffer.writeln("\n✅ $question:");

           for (var opt in optionsRes) {
               final text = opt['text'];
               final votes = opt['poll_votes'] as List;
               if (votes.isNotEmpty) {
                   // For items, usually one person per item (but logic allows many). List them.
                   final List<String> assignees = votes.map((v) {
                       final profile = v['profiles']; // Assuming joined
                       if (profile != null) return profile['full_name']?.split(' ')[0] ?? "Alguien";
                       return "Alguien";
                   }).toList().cast<String>(); // Cast explicitly

                   logBuffer.writeln("- $text (${assignees.join(', ')})");
               } else {
                   logBuffer.writeln("- $text (Pendiente)");
               }
           }
           
           await _logToDescription(planId, logBuffer.toString());
           await closePoll(pollId);
           return;
      }

      // STANDARD HANDLING (Winner takes all) for Text/Date/Location
      final optionsWithCounts = await _supabase.from('poll_options')
          .select('*, poll_votes(count)') // precise count for winner logic
          .eq('poll_id', pollId);

      if (optionsWithCounts.isEmpty) return;

      // Find winner
      Map<String, dynamic>? winner;
      int maxVotes = -1;

      for (var opt in optionsWithCounts) {
          final List votesList = opt['poll_votes'] ?? [];
          int count = 0;
          if (votesList.isNotEmpty && votesList[0] is Map && votesList[0].containsKey('count')) {
               count = votesList[0]['count'];
          } else {
               count = votesList.length; 
          }

          if (count > maxVotes) {
              maxVotes = count;
              winner = opt;
          }
      }

      if (winner == null) return;
      final String winnerText = winner['text'] ?? '';

      // 2. METADATA UPDATE LOGIC (Flexible Check)
      bool handledAsMetadata = false;
      
      // Auto-detect type if generic 'text' but content looks specific?
      String effectiveType = type;
      if (type == 'text') {
           final qLower = question.toLowerCase();
           if (qLower.contains('fecha') || qLower.contains('cuándo')) effectiveType = 'date';
           else if (qLower.contains('lugar') || qLower.contains('dónde') || qLower.contains('donde')) effectiveType = 'location';
      }

      if (effectiveType == 'location') {
          try {
             await _supabase.from('plans').update({'location_name': winnerText}).eq('id', planId);
             handledAsMetadata = true;
          } catch (_) {}
      } 
      else if (effectiveType == 'date') {
           DateTime? newDate;
           // Try ISO first
           try { newDate = DateTime.parse(winnerText); } catch (_) {}
           // Try Localized 'EEE d MMM' (e.g. 'mié. 29 ene.')
           if (newDate == null) {
               try {
                   final now = DateTime.now();
                   // Parse format used in PlanDetailScreen
                   final parsed = DateFormat('EEE d MMM', 'es_CO').parse(winnerText);
                   // Infer year: if month < current month, assume next year (or just current year for simplicity)
                   // But since we can't easily validaty "past", let's default to current year 
                   // and if date < now - 30 days, maybe next year?
                   // Simplest: Use current year.
                   newDate = DateTime(now.year, parsed.month, parsed.day);
                   if (newDate.isBefore(now.subtract(const Duration(days: 90)))) {
                       newDate = DateTime(now.year + 1, parsed.month, parsed.day);
                   }
               } catch (e) {
                   print("Date Parse Error: $e");
               }
           }

           if (newDate != null) {
               try {
                 await _supabase.from('plans').update({'event_date': newDate.toIso8601String()}).eq('id', planId);
                 handledAsMetadata = true;
               } catch (_) {}
           }
      }
      else if (effectiveType == 'time') {
           // Parse Time string (e.g. "10:00 AM", "14:00")
           // Assuming winnerText is parseable or simple
           TimeOfDay? time;
            try {
                // Try 'h:mm a' first (standardized)
                try {
                     final dt = DateFormat('h:mm a').parse(winnerText); // Creates 1970 date
                     time = TimeOfDay.fromDateTime(dt);
                } catch (_) {
                    // Fallback to manual parse
                    final parts = winnerText.replaceAll(' ', '').split(':');
                    if (parts.length >= 2) {
                        int h = int.tryParse(parts[0]) ?? 9;
                        int m = int.tryParse(parts[1].substring(0, 2)) ?? 0; // handle 00pm
                        // Simple pm check
                        if (winnerText.toLowerCase().contains('pm') && h < 12) h += 12;
                        time = TimeOfDay(hour: h, minute: m);
                    } else {
                         final dt = DateTime.parse("2020-01-01 $winnerText"); 
                         time = TimeOfDay.fromDateTime(dt);
                    }
                }
            } catch (_) {}

           if (time != null) {
               try {
                   final planRes = await _supabase.from('plans').select('event_date').eq('id', planId).maybeSingle();
                   DateTime currentStats = planRes != null && planRes['event_date'] != null 
                       ? DateTime.parse(planRes['event_date']) 
                       : DateTime.now().add(const Duration(days: 7));
                   
                   final newDate = DateTime(
                       currentStats.year, currentStats.month, currentStats.day,
                       time.hour, time.minute
                   );
                   
                   await _supabase.from('plans').update({'event_date': newDate.toIso8601String()}).eq('id', planId);
                   handledAsMetadata = true;
               } catch (_) {}
           }
      }
      else if (type == 'budget') {
          // Map likely winner text to payment mode
          String mode = 'individual';
          final wLower = winnerText.toLowerCase();
          if (wLower.contains('vaca') || wLower.contains('pool')) mode = 'pool';
          else if (wLower.contains('invitado') || wLower.contains('gratis')) mode = 'guest';
          else if (wLower.contains('clara') || wLower.contains('split') || wLower.contains('dividir')) mode = 'split';
          
          try {
             await _supabase.from('plans').update({'payment_mode': mode}).eq('id', planId);
             handledAsMetadata = true;
          } catch (_) {}
      }

      // If handled as metadata, just log it in description/notes and close poll
      // 3. LOGIC FOR OTHER DECISIONS (Log to Observations)
      // Instead of creating a new Activity, we log this decision into the Plan Description/Notes.
      // E.g. "We decided to eat Pizza" -> Appended to description.
      
      await _logToDescription(planId, "\n✅ $question: $winnerText");
      await closePoll(pollId);
  }

  Future<void> _logToDescription(String planId, String logEntry) async {
      try {
          final planRes = await _supabase.from('plans').select('description').eq('id', planId).single();
          String currentDesc = planRes['description'] ?? '';
          
          // Avoid duplicate logs if possible (simple check)
          if (!currentDesc.contains(logEntry.trim())) {
               // If description is null/empty, just set it.
               if (currentDesc.isEmpty) {
                   currentDesc = "Observaciones del Grupo:";
               }
               
               await _supabase.from('plans').update({
                   'description': "$currentDesc$logEntry"
               }).eq('id', planId);
          }
      } catch (e) {
          print("Error logging decision: $e");
      }
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
