// Sends Squad HQ push notifications through Firebase Cloud Messaging.
//
// Run every few minutes by pg_cron (supabase/sql/013_push_schedule.sql). Each
// run claims whatever's due — claim_push_notifications() in
// supabase/sql/012_push_notifications.sql works it out from matches, RSVPs,
// MOTM votes and bills, and logs each one so it's only ever sent once —
// then delivers it to every device the player has registered.
//
// Secrets (Supabase Dashboard -> Edge Functions -> Secrets):
//   SQUAD_HQ_FIREBASE_KEY     the Firebase service account key JSON
//   PUSH_CRON_SECRET          any long random string; pg_cron sends it
//   APP_WEB_URL               optional, e.g. https://squad-hq.web.app — where
//                             tapping a web notification opens
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.
//
// Deploy with JWT verification OFF: pg_cron calls it with the project's
// publishable key (not a JWT), and the x-cron-secret check below is what
// guards it.

import { createClient } from "npm:@supabase/supabase-js@2";

type Due = {
  profile_id: string;
  title: string;
  body: string;
  route: string;
  web_only: boolean;
};

type PushToken = { token: string; profile_id: string; platform: string };

type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
};

const encoder = new TextEncoder();

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

// OAuth access token for FCM, from a JWT signed with the service account.
async function fcmAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = base64url(
    encoder.encode(
      JSON.stringify({
        iss: account.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }),
    ),
  );
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(unsigned)),
  );
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${unsigned}.${base64url(signature)}`,
    }),
  });
  const json = await response.json();
  if (!response.ok) throw new Error(`OAuth failed: ${JSON.stringify(json)}`);
  return json.access_token as string;
}

Deno.serve(async (request) => {
  // Refuse outright if the secret isn't set — otherwise a missing header
  // would "match" a missing secret.
  const cronSecret = Deno.env.get("PUSH_CRON_SECRET");
  if (!cronSecret || request.headers.get("x-cron-secret") !== cronSecret) {
    return new Response("Forbidden", { status: 403 });
  }

  // Sign in to FCM before claiming anything: claiming marks notifications
  // as sent, so a bad key must fail here, not after.
  let account: ServiceAccount;
  try {
    account = JSON.parse(Deno.env.get("SQUAD_HQ_FIREBASE_KEY") ?? "") as ServiceAccount;
  } catch {
    return Response.json(
      { error: "SQUAD_HQ_FIREBASE_KEY is missing or isn't the service account JSON" },
      { status: 500 },
    );
  }
  let accessToken: string;
  try {
    accessToken = await fcmAccessToken(account);
  } catch (error) {
    return Response.json({ error: String(error) }, { status: 500 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: due, error } = await supabase.rpc("claim_push_notifications");
  if (error) return Response.json({ error: error.message }, { status: 500 });
  const notifications = (due ?? []) as Due[];
  if (notifications.length === 0) return Response.json({ sent: 0 });

  const profileIds = [...new Set(notifications.map((n) => n.profile_id))];
  const { data: tokenRows, error: tokenError } = await supabase
    .from("push_tokens")
    .select("token, profile_id, platform")
    .in("profile_id", profileIds);
  if (tokenError) return Response.json({ error: tokenError.message }, { status: 500 });
  const tokens = (tokenRows ?? []) as PushToken[];

  const webUrl = Deno.env.get("APP_WEB_URL")?.replace(/\/$/, "");
  const endpoint = `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  let sent = 0;
  const deadTokens: string[] = [];
  const sends: Promise<void>[] = [];

  for (const n of notifications) {
    for (const device of tokens) {
      if (device.profile_id !== n.profile_id) continue;
      if (n.web_only && device.platform !== "web") continue;
      const message = {
        token: device.token,
        notification: { title: n.title, body: n.body },
        data: { route: n.route },
        android: { notification: { channel_id: "squad_updates" } },
        webpush: {
          notification: { icon: "/icons/Icon-192.png" },
          // The web app uses hash routes (e.g. /#/wallet).
          ...(webUrl ? { fcm_options: { link: `${webUrl}/#${n.route}` } } : {}),
        },
      };
      sends.push(
        fetch(endpoint, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ message }),
        }).then(async (response) => {
          if (response.ok) {
            sent++;
            return;
          }
          const text = await response.text();
          // Uninstalled app / revoked permission: forget the token.
          if (response.status === 404 || text.includes("UNREGISTERED")) {
            deadTokens.push(device.token);
          } else {
            console.error(`FCM ${response.status}: ${text}`);
          }
        }),
      );
    }
  }
  await Promise.all(sends);

  if (deadTokens.length > 0) {
    await supabase.from("push_tokens").delete().in("token", deadTokens);
  }
  return Response.json({ claimed: notifications.length, sent, removed: deadTokens.length });
});
