import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:planmapp/core/config/api_config.dart';
import 'package:planmapp/features/plans/services/plan_members_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiMatchmakerService {
  late final GenerativeModel _model;

  AiMatchmakerService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  Future<Map<String, dynamic>> generatePerfectPlan(List<PlanMember> friends) async {
    try {
      final prompt = _buildPrompt(friends);
      
      final response = await _model.generateContent([Content.text(prompt)]);
      
      final text = response.text;
      if (text == null) throw Exception("La IA no devolvió respuesta");
      
      // Extract JSON from markdown
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (jsonMatch == null) throw Exception("No se obtuvo un formato válido de la IA");
      
      return jsonDecode(jsonMatch.group(0)!);
    } catch (e) {
      throw Exception("Error generando plan: $e");
    }
  }

  String _buildPrompt(List<PlanMember> friends) {
    StringBuffer info = StringBuffer();
    for (var f in friends) {
      info.writeln("- ${f.name}: Disfruta de ${f.interests.isEmpty ? 'planes relajados' : f.interests.join(', ')}");
    }

    return '''
Eres un asistente experto en organizar reuniones sociales y "parches" entre amigos. Tienes la tarea de analizar los gustos ("Vibes") de un grupo de amigos y recomendar LA ACTIVIDAD PERFECTA que encaje con la mayoría.

Toma en cuenta la siguiente lista de amigos y sus intereses:
$info

Instrucciones:
1. Crea un plan que combine la mayor cantidad de intereses del grupo de manera creativa.
2. Si los intereses son opuestos (ej. uno quiere fiesta y otro lectura), busca un punto medio (ej. Una tarde de cócteles tranquilos en una terraza y cena).
3. Devuelve SIEMPRE la respuesta en formato JSON estrictamente, sin texto antes ni después. Usa esta estructura:

{
  "title": "Un título atractivo para el plan",
  "description": "Una breve descripción de por qué este plan es ideal para el grupo",
  "location": "Sugerencia del tipo de lugar o lugar real (ej. Parque, Restaurante X)",
  "budget": "Presupuesto sugerido",
  "vibe_tag": "La categoría principal que engloba el plan (ej. Chill/Café, Aventura, Fiesta, Comida/Gastro)"
}
''';
  }
}
