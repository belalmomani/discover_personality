// Supabase Edge Function: sends an FCM push when a chat message is inserted.
// NOT deployed or tested by the author. Setup is described in docs/PUSH_SETUP.md.
//
// Trigger: a Database Webhook on INSERT into public.messages -> this function, with the header
//   x-webhook-secret: <PUSH_WEBHOOK_SECRET>   (deploy with "Verify JWT" OFF; the secret protects it).
// Secrets (Supabase -> Edge Functions -> Secrets):
//   PUSH_WEBHOOK_SECRET   random string, also set as the webhook header
//   FCM_SERVICE_ACCOUNT   the whole Firebase service-account JSON (Project settings -> Service accounts)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically to Edge Functions.
// The service-role key stays on the server only. Notification text NEVER contains the message itself.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

type Msg = { id: string; conversation_id: string; sender_id: string; kind: string };

// ---------- FCM access token (service-account JWT -> OAuth2), cached until near expiry
let cached: { token: string; exp: number } | null = null;

function b64url(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(sa: { client_email: string; private_key: string; token_uri?: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;
  const enc = new TextEncoder();
  const header = b64url(enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claim = b64url(enc.encode(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })));
  const pem = sa.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(`${header}.${claim}`));
  const res = await fetch(sa.token_uri ?? "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${header}.${claim}.${b64url(sig)}` }),
  });
  if (!res.ok) throw new Error("oauth " + res.status);
  const j = await res.json();
  cached = { token: j.access_token as string, exp: now + (j.expires_in as number ?? 3600) };
  return cached.token;
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("PUSH_WEBHOOK_SECRET")) return json({ error: "forbidden" }, 403);
  try {
    const body = await req.json();
    if (body?.type !== "INSERT") return json({ skipped: "not an insert" });
    const m = body.record as Msg;
    if (!m?.conversation_id || !["text", "gift", "image"].includes(m.kind)) return json({ skipped: "kind" });

    const { data: conv } = await supabase.from("conversations").select("user_a,user_b").eq("id", m.conversation_id).single();
    if (!conv) return json({ skipped: "no conversation" });
    const receiver = conv.user_a === m.sender_id ? conv.user_b : conv.user_a;

    const { data: prof } = await supabase.from("profiles").select("push_enabled,banned,allow_chat").eq("id", receiver).single();
    if (!prof || !prof.push_enabled || prof.banned || !prof.allow_chat) return json({ skipped: "receiver settings" });

    const { data: blocked } = await supabase.from("blocks").select("blocker_id").or(
      `and(blocker_id.eq.${receiver},blocked_id.eq.${m.sender_id}),and(blocker_id.eq.${m.sender_id},blocked_id.eq.${receiver})`,
    );
    if (blocked && blocked.length) return json({ skipped: "blocked" });

    const { data: sender } = await supabase.from("profiles").select("username").eq("id", m.sender_id).single();
    const { data: tokens } = await supabase.from("push_tokens").select("token").eq("user_id", receiver);
    if (!tokens || !tokens.length) return json({ skipped: "no tokens" });

    const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
    const access = await accessToken(sa);
    const name = sender?.username ?? "مستخدم";
    const text = m.kind === "gift" ? `${name} أرسل لك هدية` : m.kind === "image" ? `${name} أرسل لك صورة` : `رسالة جديدة من ${name}`;

    let sent = 0;
    for (const t of tokens) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: "POST",
        headers: { authorization: `Bearer ${access}`, "content-type": "application/json" },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title: "اكتشف شخصيتك", body: text },
            data: { conversation_id: m.conversation_id, type: "chat" },
            android: { priority: "HIGH" },
          },
        }),
      });
      if (res.ok) {
        sent++;
      } else if (res.status === 404 || res.status === 400) {
        // token no longer valid: remove it
        const err = await res.text();
        if (err.includes("UNREGISTERED") || err.includes("INVALID_ARGUMENT")) await supabase.from("push_tokens").delete().eq("token", t.token);
      }
    }
    return json({ sent });
  } catch (_e) {
    return json({ error: "failed" }, 500);
  }
});
