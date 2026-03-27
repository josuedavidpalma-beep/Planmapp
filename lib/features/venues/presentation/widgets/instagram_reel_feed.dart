import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// FEED PRINCIPAL
class InstagramEmbedFeed extends StatelessWidget {
  final List<String> instagramUrls;

  const InstagramEmbedFeed({super.key, required this.instagramUrls});

  @override
  Widget build(BuildContext context) {
    if (instagramUrls.isEmpty) {
      return const Center(child: Text("No hay publicaciones disponibles."));
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: instagramUrls.length,
      itemBuilder: (context, index) {
        return ReelWidget(url: instagramUrls[index]);
      },
    );
  }
}

/// WIDGET INDIVIDUAL DEL REEL
class ReelWidget extends StatefulWidget {
  final String url;

  const ReelWidget({super.key, required this.url});

  @override
  State<ReelWidget> createState() => _ReelWidgetState();
}

class _ReelWidgetState extends State<ReelWidget> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
        _isLoading = false;
        return;
    }
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    final embedHtml = '''
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
             body, html { margin: 0; padding: 0; height: 100%; background-color: #000; display:flex; justify-content:center; align-items:center; }
             iframe { border: none; width: 100%; height: 100%; }
          </style>
        </head>
        <body>
          <blockquote class="instagram-media" data-instgrm-permalink="\${widget.url}" data-instgrm-version="14" style="background:#FFF; border:0; margin:0; padding:0; width:100%;"></blockquote>
          <script async src="//www.instagram.com/embed.js"></script>
        </body>
      </html>
    ''';
    
    _controller!.loadHtmlString(embedHtml);
  }

  void _shareExternally() {
    Share.share('¡Mira este increíble lugar en PlanMaps! ${widget.url}');
  }

  void _shareInternally() {
    // TODO: [Supabase Lógica] 
    // 1. Mostrar un Modal/BottomSheet con la lista de 'Mis Planes'.
    // 2. Al seleccionar uno, invocar: supabase.from('plan_chat').insert({ plan_id: X, message: url, sender_id: auth.uid() });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Compartir en chat interno (Próximamente)")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Webview (Contenido)
        Positioned.fill(
          child: kIsWeb 
            ? _buildWebFallback()
            : WebViewWidget(controller: _controller!),
        ),
        
        // 2. Cargador
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // 3. Barra de Acciones Nativa de Flutter (Estilo TikTok/Reels)
        Positioned(
          right: 16,
          bottom: 100, // Espacio para descripciones abajo
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.favorite_border,
                label: "Like",
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: "Interno",
                onTap: _shareInternally,
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                icon: Icons.share_outlined,
                label: "WhatsApp",
                onTap: _shareExternally,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWebFallback() {
      return Container(
          color: Colors.black,
          child: Center(
             child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.ondemand_video_rounded, size: 80, color: Colors.white24),
                   const SizedBox(height: 24),
                   const Text("Los videos de Instagram no se" "\n" "reproducen dentro del navegador Web.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                   const SizedBox(height: 24),
                   ElevatedButton.icon(
                       onPressed: () => launchUrl(Uri.parse(widget.url)),
                       icon: const Icon(Icons.open_in_browser),
                       label: const Text("Ver en Instagram"),
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white)
                   )
                ]
             )
          )
      );
  }
}
