// Example secure AI proxy (Supabase Edge Function). NOT deployed or tested by the author.
// The provider key lives ONLY in Supabase secrets: `supabase secrets set AI_API_KEY=... AI_MODEL=...`
// Default provider below is the Anthropic Messages API; swap `callProvider` to change provider.
// verify_jwt stays ON (default) so only your app (anon key / signed-in users) can call it.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
};

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = await req.json();
    const scores = body?.scores;
    if (!scores || typeof scores !== "object") {
      return new Response(JSON.stringify({ error: "scores required" }), { status: 400, headers: corsHeaders });
    }
    const text = await callProvider(scores);
    return new Response(JSON.stringify({ text }), { headers: { ...corsHeaders, "content-type": "application/json" } });
  } catch (_e) {
    return new Response(JSON.stringify({ error: "failed" }), { status: 502, headers: corsHeaders });
  }
});
