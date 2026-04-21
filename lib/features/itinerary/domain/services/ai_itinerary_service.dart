import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:planmapp/core/config/api_config.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';

class AiItineraryService {
  late final GenerativeModel _model;

  AiItineraryService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: ApiConfig.geminiApiKey,
    );
  }

  Future<List<Map<String, dynamic>>> generateItinerary(Plan plan) async {
    try {
      final prompt = _buildPrompt(plan);
      
      final response = await _model.generateContent([Content.text(prompt)]);
      
      final text = response.text;
      if (text == null) throw Exception("La IA no devolvió respuesta");
      
      // Extract JSON array from markdown
      final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(text);
      if (jsonMatch == null) {
          // Si por alguna razón responde un JSON object con una key "itinerary" o algo así
          final objMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
          if (objMatch != null) {
              final parsedMap = jsonDecode(objMatch.group(0)!);
              if (parsedMap is Map && parsedMap.containsKey('steps')) {
                  return List<Map<String, dynamic>>.from(parsedMap['steps']);
              }
          }
          throw Exception("No se obtuvo un formato válido de la IA");
      }
      
      final parsedList = jsonDecode(jsonMatch.group(0)!);
      if (parsedList is List) {
          return List<Map<String, dynamic>>.from(parsedList);
      } else {
          throw Exception("El JSON devuelto no es una lista");
      }
    } catch (e) {
      throw Exception("Error fabricando itinerario: $e");
    }
  }

  String _buildPrompt(Plan plan) {
    final dateStr = plan.eventDate != null 
        ? DateFormat('EEE d MMM yyyy, h:mm a', 'es_CO').format(plan.eventDate!)
        : "Fecha no especificada";

    return '''
Eres un organizador de eventos de élite ("Event Planner") de Planmapp. Tu objetivo es crear la línea de tiempo o "Itinerario" logístico paso a paso para un grupo de amigos.

Aquí están los detalles fundamentales del plan:
- Título: ${plan.title}
- Descripción / Notas: ${plan.description ?? "Ninguna observacion adicional."}
- Lugar Principal: ${plan.locationName}
- Fecha y Hora Inicial: $dateStr

Instrucciones:
1. Diseña un itinerario con pasos secuenciales, empezando aproximadamente 1 o 2 horas ANTES de la hora principal (sugerencias para el punto de encuentro o pedir transporte).
2. Estipula la llegada al lugar principal ("${plan.locationName}").
3. Agrega 1 o 2 pasos posteriores a la hora principal (por ejemplo, comer algo rápido de madrugada o el regreso).
4. El itinerario no debe tener más de 5 o 6 pasos para no saturar al grupo.
5. Devuelve la respuesta ESTRICTAMENTE como un Arreglo JSON (List) donde cada objeto tenga esta estructura:

[
  {
    "time": "7:00 PM",
    "title": "Punto de encuentro",
    "description": "Reunámonos en la casa de Juan para pedir el transporte juntos."
  },
  {
    "time": "8:30 PM",
    "title": "Comienza el transporte",
    "description": "Pedir InDrive o Uber hacia ${plan.locationName}."
  }
]

IMPORTANTE: No escribas texto introductorio ni conclusiones. SOLAMENTE JSON válido empezando con `[` y terminando con `]`.
''';
  }
}
