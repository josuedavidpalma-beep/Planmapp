import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class AvatarGalleryModal extends StatelessWidget {
  final Function(String) onAvatarSelected;

  const AvatarGalleryModal({super.key, required this.onAvatarSelected});

  @override
  Widget build(BuildContext context) {
    // Usaremos los estilos más "Premium" y divertidos de DiceBear 9.x
    // Micah (Ilustraciones modernas), Fun-Emoji (Emojis vibrantes), 
    // Notionists (Estilo Notion minimalista), Adventurer-Neutral (Personajes Cool)
    // Redujimos a 24 totales (6 por categoría) para evitar que el API gratuito de DiceBear rechace conexiones simultáneas.
    final avatarUrls = [
      ...List.generate(6, (i) => "https://api.dicebear.com/9.x/micah/png?seed=premium${i+1}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffdfbf"),
      ...List.generate(6, (i) => "https://api.dicebear.com/9.x/fun-emoji/png?seed=divertido${i+1}"),
      ...List.generate(6, (i) => "https://api.dicebear.com/9.x/notionists/png?seed=notion${i+1}&backgroundColor=f8d25c,ffdfbf,c0aede"),
      ...List.generate(6, (i) => "https://api.dicebear.com/9.x/adventurer-neutral/png?seed=adv${i+1}&backgroundColor=b6e3f4,c0aede"),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text("Elige tu Avatar 🎨", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          const Text("Selecciona el que mejor te represente o más te divierta", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Se ajustó a 3 para que se vean más grandes y definidos
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: avatarUrls.length,
              itemBuilder: (context, index) {
                final url = avatarUrls[index];
                return InkWell(
                  onTap: () {
                    onAvatarSelected(url);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 2),
                    ),
                    child: ClipOval(
                      // Usar CachedNetworkImage evita que se recarguen y falle la bajada
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                           child: SizedBox(
                              width: 20, height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                           )
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
