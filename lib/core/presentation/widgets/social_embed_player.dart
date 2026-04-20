import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Used ONLY on Web for rendering TikTok oEmbed IFrames
// We use a conditional import trick, or simply use universal_html
// actually, flutter/foundation handles kIsWeb
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class SocialEmbedPlayer extends StatefulWidget {
  final String url;

  const SocialEmbedPlayer({super.key, required this.url});

  @override
  State<SocialEmbedPlayer> createState() => _SocialEmbedPlayerState();
}

class _SocialEmbedPlayerState extends State<SocialEmbedPlayer> {
  bool _isLoading = true;
  bool _isPlaying = false;
  Map<String, dynamic>? _ogData;
  String _viewId = '';

  @override
  void initState() {
    super.initState();
    _fetchOgData();
  }

  Future<void> _fetchOgData() async {
    try {
      final res = await Supabase.instance.client.functions.invoke('og-scraper', body: {
         'url': widget.url
      });
      if (mounted && res.data != null) {
          setState(() {
             _ogData = res.data;
             _isLoading = false;
          });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playVideo() {
     if (!_ogData!.containsKey('html') || _ogData!['html'] == null) {
         _launchExternal();
         return;
     }

     if (kIsWeb) {
         setState(() => _isPlaying = true);
         _viewId = 'tiktok_embed_${DateTime.now().millisecondsSinceEpoch}';
         // Register the view factory
         ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
             final container = html.DivElement()
                 ..style.width = '100%'
                 ..style.height = '100%'
                 ..style.overflow = 'hidden'
                 ..style.display = 'flex'
                 ..style.justifyContent = 'center'
                 ..style.alignItems = 'center';
                 
             // TikTok oEmbed returns a blockquote. We must add their embed.js script.
             container.innerHtml = _ogData!['html'];
             
             final script = html.ScriptElement()
                 ..src = "https://www.tiktok.com/embed.js"
                 ..async = true;
             container.append(script);
             
             return container;
         });
     } else {
         _launchExternal();
     }
  }

  Future<void> _launchExternal() async {
      final uri = Uri.tryParse(widget.url);
      if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
        return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(height: 50, child: Center(child: CircularProgressIndicator()))
        );
    }

    if (_ogData == null) {
        // Fallback to simple link
        return GestureDetector(
            onTap: _launchExternal,
            child: Text(widget.url, style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline))
        );
    }

    return Container(
       margin: const EdgeInsets.symmetric(vertical: 8),
       decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10)
       ),
       child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
             if (_ogData?['thumbnailUrl'] != null && !_isPlaying)
                Stack(
                   alignment: Alignment.center,
                   children: [
                      ClipRRect(
                         borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                         child: CachedNetworkImage(
                             imageUrl: _ogData!['thumbnailUrl'],
                             width: double.infinity,
                             height: 300,
                             fit: BoxFit.cover,
                         )
                      ),
                      Container(
                         width: double.infinity,
                         height: 300,
                         color: Colors.black45,
                      ),
                      IconButton(
                         iconSize: 64,
                         icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                         onPressed: _playVideo,
                      )
                   ]
                ),
             
             if (_isPlaying && kIsWeb)
                SizedBox(
                   width: double.infinity,
                   height: 600, // TikToks are usually tall
                   child: HtmlElementView(viewType: _viewId),
                ),

             Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                   children: [
                      Icon(
                         _ogData?['provider'] == 'tiktok' ? Icons.music_note : Icons.link,
                         color: AppTheme.primaryBrand,
                         size: 20
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                         child: Text(
                             _ogData?['title'] ?? 'Enlace Compartido',
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                         )
                      )
                   ]
                )
             )
          ]
       )
    );
  }
}
