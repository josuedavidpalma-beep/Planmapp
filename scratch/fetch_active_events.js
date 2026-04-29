const fs = require('fs');
const https = require('https');

async function main() {
  const envContent = fs.readFileSync('.env', 'utf-8');
  let anonKey = '';
  envContent.split('\n').forEach(line => {
    if (line.startsWith('SUPABASE_ANON_KEY=')) {
      anonKey = line.split('=')[1].trim();
    }
  });

  if (!anonKey) {
    console.error("No anon key");
    return;
  }

  const options = {
    hostname: 'pthiaalrizufhlplbjht.supabase.co',
    path: '/rest/v1/local_events?status=eq.active&select=id,event_name,image_url,primary_source',
    method: 'GET',
    headers: {
      'apikey': anonKey,
      'Authorization': `Bearer ${anonKey}`
    }
  };

  const req = https.request(options, res => {
    let data = '';
    res.on('data', chunk => { data += chunk; });
    res.on('end', () => {
      const events = JSON.parse(data);
      console.log(`Total active events: ${events.length}`);
      events.forEach(e => {
          console.log(`- ${e.event_name} | Image: ${e.image_url ? 'YES' : 'NO'} | Link: ${e.primary_source}`);
          if (!e.image_url) {
              console.log("  [MISSING IMAGE]");
          }
      });
    });
  });

  req.on('error', error => { console.error(error); });
  req.end();
}

main();
