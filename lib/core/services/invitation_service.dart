import 'package:share_plus/share_plus.dart';
import 'package:planmapp/features/plans/domain/models/plan_model.dart';
import 'package:intl/intl.dart';

class InvitationService {
  static Future<void> inviteToPlan(Plan plan) async {
    final String dateStr = plan.eventDate != null 
        ? DateFormat('EEEE d \'de\' MMMM', 'es_CO').format(dateStrParsed(plan.eventDate!))
        : "Fecha por definir";
    
    final String locationInfo = plan.locationName.isNotEmpty 
        ? "\n📍 Lugar: ${plan.locationName}" 
        : "";

    final String message = """
✨ ¡Te invitaron a un plan en Planmapp! ✨

🎨 Plan: ${plan.title}
🗓️ Fecha: $dateStr$locationInfo

Para ver los detalles, votar en encuestas y confirmar tu asistencia, abre este enlace:
https://planmapp.app/?invite=${plan.id}

¡Nos vemos allá! 🚀
""";

    await Share.share(message, subject: "Invitación a ${plan.title}");
  }

  // Helper to parse date if it's a string, or return as is if implementation changes
  static DateTime dateStrParsed(dynamic date) {
      if (date is DateTime) return date;
      return DateTime.parse(date.toString());
  }
}
