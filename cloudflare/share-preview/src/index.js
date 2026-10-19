// Preview cards for shared Squad HQ links (Messenger, Facebook, Telegram…).
//
// A share link is https://squad-hq.web.app/s/<token>; Firebase Hosting
// redirects it here (firebase.json). Link-preview bots read this page's
// Open Graph tags; a person's browser runs the script and goes on to
// /open/<token> in the app, which opens the match or bill once signed in.
//
// Opened inside Messenger's, Facebook's or Instagram's own browser, it
// stops to suggest a real one instead: Google sign-in is blocked there,
// and the installed app can't catch the link from inside it.
//
// The card comes from 054's share_preview, read with the anon key: no
// live counts and no amounts, since anyone the link reaches sees it.

const APP = 'https://squad-hq.web.app';
const IMAGE = `${APP}/share/card.png`;

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    const token = path.match(/^\/s\/([A-Za-z0-9_-]{4,64})\/?$/)?.[1];
    if (!token) return Response.redirect(APP, 302);
    const preview = await loadPreview(token, env);
    const agent = request.headers.get('user-agent') ?? '';
    return new Response(page(token, card(preview), inAppBrowser(agent)), {
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'public, max-age=300',
      },
    });
  },
};

/** 054's share_preview row, or null if the token is unknown (or Supabase
 * is down — the card then just says Squad HQ). */
async function loadPreview(token, env) {
  const url = `${env.SUPABASE_URL}/rest/v1/rpc/share_preview?p_token=${encodeURIComponent(token)}`;
  try {
    const response = await fetch(url, {
      headers: { apikey: env.SUPABASE_ANON_KEY, authorization: `Bearer ${env.SUPABASE_ANON_KEY}` },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!response.ok) return null;
    const rows = await response.json();
    return rows[0] ?? null;
  } catch {
    return null;
  }
}

/** The card's title and description. Messenger always shows the title and
 * often cuts the description to a line, so the title carries the match. */
function card(preview) {
  if (!preview) {
    return {
      title: 'Squad HQ',
      description: 'This match was cancelled, or the link has expired.',
    };
  }
  const versus = `${preview.team_name} vs ${preview.opponent}`;
  const when = formatKickoff(preview.kickoff_at, preview.timezone);
  if (preview.kind === 'bill') {
    return {
      title: `💸 Match fee · ${versus}`,
      description: preview.payer_name
        ? `Paid by ${preview.payer_name}. Tap to see your share and pay in Squad HQ.`
        : 'Tap to see your share and pay in Squad HQ.',
    };
  }
  const where = preview.venue ? ` · ${preview.venue}` : '';
  if (new Date(preview.kickoff_at) > new Date()) {
    return { title: `⚽ ${versus}`, description: `${when}${where}` };
  }
  const games = preview.games ? preview.games.split(' · ') : [];
  if (games.length === 1) {
    return {
      title: `⚽ ${preview.team_name} ${games[0]} ${preview.opponent}`,
      description: `Played ${when}${where} · ratings and Man of the Match in Squad HQ`,
    };
  }
  return {
    title: `⚽ ${versus}`,
    description: games.length > 1
      ? `Games ${preview.games} · played ${when}`
      : `Played ${when}${where} · scores and Man of the Match in Squad HQ`,
  };
}

/** Messenger's, Facebook's or Instagram's built-in browser — 'ios' or
 * 'android' — else null. (Facebook's preview bot is "facebookexternalhit",
 * which doesn't match.) */
function inAppBrowser(agent) {
  if (!/FBAN|FBAV|FB_IAB|FBIOS|Messenger|Instagram/i.test(agent)) return null;
  return /iPhone|iPad|iPod/i.test(agent) ? 'ios' : 'android';
}

/** "Sat 25 Oct · 7:00 pm", in the team's time zone. */
function formatKickoff(iso, timeZone) {
  const date = new Date(iso);
  const zone = timeZone || 'Asia/Bangkok';
  const day = new Intl.DateTimeFormat('en-GB', {
    weekday: 'short', day: 'numeric', month: 'short', timeZone: zone,
  }).format(date).replace(',', '');
  const time = new Intl.DateTimeFormat('en-US', {
    hour: 'numeric', minute: '2-digit', timeZone: zone,
  }).format(date).toLowerCase();
  return `${day} · ${time}`;
}

function page(token, { title, description }, inApp) {
  const share = `${APP}/s/${token}`;
  const open = `${APP}/open/${token}`;
  const t = escape(title);
  const d = escape(description);
  const body = inApp ? openElsewhere(open, title, inApp) : `<p>Opening Squad HQ… <a href="${escape(open)}">Open</a></p>`;
  const go = inApp ? '' : `<script>location.replace(${JSON.stringify(open)});</script>`;
  // No meta refresh: Facebook's bot follows those, and would read the
  // app's own (generic) tags instead. Bots don't run the script.
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${t}</title>
<meta name="description" content="${d}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Squad HQ">
<meta property="og:url" content="${share}">
<meta property="og:title" content="${t}">
<meta property="og:description" content="${d}">
<meta property="og:image" content="${IMAGE}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="Squad HQ">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${t}">
<meta name="twitter:description" content="${d}">
<meta name="twitter:image" content="${IMAGE}">
${go}
<style>
*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:grid;place-items:center;background:#F5EAD8;color:#201E1D;font:16px/1.45 -apple-system,Helvetica,Arial,sans-serif}
a{color:#8C491A;font-weight:700}
.tip{width:100%;max-width:420px;padding:28px 16px;text-align:center}
.tip h1{font-size:20px;margin:0 0 6px}
.tip p{margin:0 0 18px;color:#645C50;font-size:15px}
.button{display:block;width:100%;padding:14px;border-radius:999px;text-decoration:none;font-weight:800;margin-bottom:10px}
.primary{background:#2E2B25;color:#F9F4ED}
.secondary{border:1.5px solid rgba(32,30,29,.18);color:#201E1D;background:transparent;font:inherit;font-weight:800;cursor:pointer}
.steps{font-size:14px;color:#474238;margin:16px 0 0}
</style>
</head>
<body>${body}</body>
</html>`;
}

/** The in-app browser page: open the link in Safari/Chrome — where the
 * installed app or a signed-in browser can take it — or carry on here. */
function openElsewhere(open, title, platform) {
  const ios = platform === 'ios';
  const browser = ios ? 'Safari' : 'Chrome';
  // iOS 17+ opens Safari for x-safari-https; Android hands an intent:
  // link to the installed app if it can take it, else the browser.
  const out = ios
    ? `x-safari-${open}`
    : `intent://${open.replace(/^https:\/\//, '')}#Intent;scheme=https;S.browser_fallback_url=${encodeURIComponent(open)};end`;
  const steps = ios
    ? 'Or tap <b>⋯</b> at the top, then <b>Open in Safari</b> (or <b>Open in external browser</b>).'
    : 'Or tap <b>⋮</b> at the top, then <b>Open in Chrome</b> (or <b>Open in browser</b>).';
  return `<div class="tip">
<h1>${escape(title)}</h1>
<p>Open this in ${browser} to use Squad HQ — signing in with Google doesn't work inside Messenger or Facebook.</p>
<a class="button primary" href="${escape(out)}">Open in ${browser}</a>
<button class="button secondary" id="copy">Copy link</button>
<a class="button secondary" href="${escape(open)}">Continue here</a>
<p class="steps">${steps}</p>
</div>
<script>
document.getElementById('copy').onclick = async (event) => {
  try {
    await navigator.clipboard.writeText(${JSON.stringify(open)});
    event.target.textContent = 'Copied — paste it in ${browser}';
  } catch {
    event.target.textContent = ${JSON.stringify(open)};
  }
};
</script>`;
}

function escape(text) {
  return String(text)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}
