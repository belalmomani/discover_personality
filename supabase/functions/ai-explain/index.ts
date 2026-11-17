// Example secure AI proxy (Supabase Edge Function). NOT deployed or tested by the author.
// The provider key lives ONLY in Supabase secrets: `supabase secrets set AI_API_KEY=... AI_MODEL=...`
// Default provider below is the Anthropic Messages API; swap `callProvider` to change provider.
// verify_jwt stays ON (default) AND the function requires a signed-in user (role "authenticated"), a size cap and a per-user rate limit.

const SYSTEM_PROMPT =
  "أنت مساعد عربي يشرح نتائج اختبار تفضيلات شخصية أولي. التزم حرفيًا بالأرقام المعطاة ولا تغيّرها. " +
  "لا تخترع سمات غير مدعومة بالأرقام. لا تقدّم تشخيصًا نفسيًا. اذكر أن النتائج مرشحة وليست قطعية. " +
  "اكتب فقرتين إلى ثلاث بإيجاز.";

async function callProvider(scores: unknown): Promise<string> {
  const key = Deno.env.get("AI_API_KEY");
  const model = Deno.env.get("AI_MODEL");
  if (!key || !model) throw new Error("AI_API_KEY / AI_MODEL secrets are not set");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
    body: JSON.stringify({
      model,
      max_tokens: 700,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: "ملخص الدرجات (JSON):\n" + JSON.stringify(scores) }],
    }),
  });
  if (!res.ok) throw new Error("provider status " + res.status);
  const data = await res.json();
  const text = (data.content ?? []).filter((b: { type: string }) => b.type === "text").map((b: { text: string }) => b.text).join("\n");
  if (!text) throw new Error("empty provider response");
  return text;
}

const MAX_BODY_BYTES = 8 * 1024; // score summaries are tiny; reject anything bigger
const MAX_PER_HOUR = 10; // per signed-in user (best effort: memory is per function instance)
const hits = new Map<string, number[]>();

const jsonHeaders = { "content-type": "application/json" };
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: jsonHeaders });

/** verify_jwt already checked the signature; here we only read the claims. */
function claims(req: Request): { role?: string; sub?: string } | null {
  try {
    const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
    const payload = token.split(".")[1];
    if (!payload) return null;
    const b64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, "=")));
  } catch (_e) {
    return null;
  }
}

function allowed(user: string): boolean {
  const now = Date.now();
  const recent = (hits.get(user) ?? []).filter((t) => now - t < 3_600_000);
  if (recent.length >= MAX_PER_HOUR) {
    hits.set(user, recent);
    return false;
  }
  recent.push(now);
  hits.set(user, recent);
  return true;
}

Deno.serve(async (req) => {
  // The mobile app does not need CORS, so no cross-origin access is granted.
  if (req.method !== "POST") return reply(405, { error: "method not allowed" });

  // Only signed-in users (role "authenticated"), never the public anon key: otherwise anyone
  // who extracts the anon key from the app could spend your AI provider credit.
  const c = claims(req);
  if (!c || c.role !== "authenticated" || !c.sub) return reply(401, { error: "sign in required" });
  if (!allowed(c.sub)) return reply(429, { error: "too many requests" });

  try {
    const raw = await req.text();
    if (raw.length > MAX_BODY_BYTES) return reply(413, { error: "payload too large" });
    const scores = JSON.parse(raw)?.scores;
    if (!scores || typeof scores !== "object" || Array.isArray(scores)) {
      return reply(400, { error: "scores required" });
    }
    const text = await callProvider(scores);
    return reply(200, { text });
  } catch (_e) {
    return reply(502, { error: "failed" });
  }
});
