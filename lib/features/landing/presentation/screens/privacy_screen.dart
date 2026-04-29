import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Privacidad y Términos", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
              if (GoRouter.of(context).canPop()) {
                  context.pop();
              } else {
                  context.go('/');
              }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Políticas de Privacidad y Términos de Servicio",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  "Última actualización: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                _buildSectionTitle("1. Información que recopilamos"),
                _buildParagraph("En Planmapp, valoramos tu privacidad. Cuando inicias sesión con tu cuenta de Google, únicamente recopilamos la información básica autorizada por ti, como tu nombre completo, dirección de correo electrónico y fotografía de perfil. Esta información se utiliza exclusivamente para crear tu perfil dentro de la aplicación y permitirte interactuar con tus amigos en la creación de planes y división de gastos."),

                _buildSectionTitle("2. Uso de la Información"),
                _buildParagraph("La información recopilada se utiliza para:\n"
                    "• Autenticar tu acceso seguro a la aplicación.\n"
                    "• Mostrar tu nombre y foto a tus amigos cuando los invitas a un plan o a dividir una cuenta.\n"
                    "• Enviar notificaciones push relevantes sobre tus deudas o planes pendientes (si otorgas el permiso).\n"
                    "Planmapp NUNCA venderá, alquilará ni compartirá tus datos personales con terceros para fines publicitarios."),

                _buildSectionTitle("3. Protección de Datos (Ley 1581 de 2012)"),
                _buildParagraph("Cumplimos con las normativas vigentes en Colombia sobre el Tratamiento de Datos Personales. Tus datos están almacenados en bases de datos cifradas y seguras. Tienes derecho a conocer, actualizar, rectificar y solicitar la eliminación de tus datos en cualquier momento."),

                _buildSectionTitle("4. Eliminación de Cuenta"),
                _buildParagraph("Puedes solicitar la eliminación total de tu cuenta y todos tus datos asociados en cualquier momento desde la sección 'Perfil' dentro de la aplicación, o contactándonos a través de nuestro soporte. Una vez eliminada, la información no podrá recuperarse."),

                _buildSectionTitle("5. Permisos del Dispositivo"),
                _buildParagraph("La aplicación puede solicitar acceso a tu cámara y galería fotográfica de manera temporal y exclusiva para el propósito de escanear facturas de restaurantes o cambiar tu foto de perfil. Ninguna imagen se extrae de tu dispositivo sin tu acción directa."),

                const SizedBox(height: 48),
                const Center(
                  child: Text("Planmapp © Todos los derechos reservados.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBrand),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
    );
  }
}
