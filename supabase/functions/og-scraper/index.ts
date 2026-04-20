import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { url } = await req.json();
    if (!url) {
      return new Response(JSON.stringify({ error: "No URL provided" }), { headers: corsHeaders, status: 400 });
    }

    let result = {
       title: "Shared Link",
       thumbnailUrl: null,
       provider: "web",
       html: null
    };

    if (url.includes('tiktok.com')) {
       // Fetch TikTok oEmbed
       const tiktokOembedUrl = `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`;
       const res = await fetch(tiktokOembedUrl);
       if (res.ok) {
           const json = await res.json();
           result.title = json.title;
           result.thumbnailUrl = json.thumbnail_url;
           result.provider = "tiktok";
           result.html = json.html;
       }
    } else if (url.includes('instagram.com/reel') || url.includes('instagram.com/p')) {
        // Fetch Instagram oEmbed (requires Facebook Graph API token usually, but we try the public one if available)
        // Public Instagram oEmbed is deprecated without token, so we fallback to basic parsing
        result.provider = "instagram";
        result.title = "Instagram Post";
    } else {
        // Attempt generic simple HTML parsing for OpenGraph (We only do simple fetch to avoid big memory usage)
        const res = await fetch(url.toString(), {
           headers: { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
        });
        if (res.ok) {
           const text = await res.text();
           const matchTitle = text.match(/<meta property="og:title" content="([^"]+)"/);
           const matchImage = text.match(/<meta property="og:image" content="([^"]+)"/);
           if (matchTitle) result.title = matchTitle[1];
           if (matchImage) result.thumbnailUrl = matchImage[1];
        }
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
