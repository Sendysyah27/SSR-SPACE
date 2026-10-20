// Supabase Edge Function: mang-ai-chat
// Gerbang Mang AI untuk SEMUA user SSR-SPACE (pengganti OpenCode lokal).
// Auth: JWT user + anggota org. Kuota: RPC check_quota('ai')
// (Gratis 30/bulan, Pro bebas — migration_20). Pemakaian dicatat via
// record_ai_usage SETELAH sukses. Request diteruskan ke AI Gateway
// (Cloudflare Worker) yang membentuk request ala OpenCode CLI ke
// free-tier OpenCode. Secrets: AI_GATEWAY_URL (termasuk secret path),
// AI_GATEWAY_KEY.
// Deploy: supabase functions deploy mang-ai-chat
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_MODELS = new Set([
  "big-pickle",
  "beam-free",
  "mimo-v2.6-flash-free",
  "nemotron-3-ultra-free",
  "nemotron-3.5-lightning-free",
  "nemotron-3.5-super-vl-free",
  "longcat-2.5-preview-free",
  "deepseek-v4.1-flash-free",
  "glm-5.3-flash-free",
  "minimax-m3.1-flash-free",
]);
const VISION_MODEL = "nemotron-3.5-super-vl-free";
const MAX_BODY_CHARS = 6_500_000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Token tidak ada" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const gwUrl = (Deno.env.get("AI_GATEWAY_URL") ?? "").replace(/\/+$/, "");
  const gwKey = Deno.env.get("AI_GATEWAY_KEY") ?? "";
  if (!gwUrl || !gwKey) {
    return json({ error: "AI_GATEWAY belum dikonfigurasi" }, 500);
  }

  // Validasi JWT pemanggil.
  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData.user) return json({ error: "Token tidak valid" }, 401);
  const user = userData.user;

  let raw: string;
  try {
    raw = await req.text();
  } catch {
    return json({ error: "Body tidak terbaca" }, 400);
  }
  if (raw.length > MAX_BODY_CHARS) {
    return json({ error: "Payload terlalu besar" }, 413);
  }
  let body: {
    org_id?: string;
    kind?: string;
    model?: string;
    max_tokens?: number;
    messages?: unknown;
  };
  try {
    body = JSON.parse(raw);
  } catch {
    return json({ error: "Body JSON tidak valid" }, 400);
  }

  const orgId = body.org_id;
  const kind = ["chat", "receipt", "quick"].includes(body.kind ?? "")
    ? (body.kind as string)
    : "chat";
  if (!orgId) return json({ error: "org_id wajib diisi" }, 400);
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return json({ error: "messages wajib diisi" }, 400);
  }

  const db = createClient(supabaseUrl, serviceKey);

  // Pemanggil wajib anggota org.
  const { data: member } = await db
    .from("org_members")
    .select("org_id")
    .eq("org_id", orgId)
    .eq("user_id", user.id)
    .maybeSingle();
  if (!member) return json({ error: "Bukan anggota workspace ini" }, 403);

  // Kuota AI per plan (server-side, tidak bisa dilewati klien nakal).
  const { data: quota, error: quotaErr } = await authClient.rpc("check_quota", {
    p_org_id: orgId,
    p_kind: "ai",
  });
  if (!quotaErr && quota && quota.allowed !== true) {
    return json(
      { error: "Kuota AI bulan ini sudah habis", code: "QUOTA_EXCEEDED" },
      403,
    );
  }

  // Model: receipt -> vision; model dari klien hanya bila ada di allowlist.
  let model: string | undefined;
  if (body.model && ALLOWED_MODELS.has(body.model)) model = body.model;
  if (kind === "receipt" && !model) model = VISION_MODEL;

  // Teruskan ke AI Gateway (Worker).
  let gw: { ok?: boolean; text?: string; model?: string; error?: string };
  try {
    const res = await fetch(`${gwUrl}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-gw-key": gwKey },
      body: JSON.stringify({
        model,
        messages: body.messages,
        max_tokens: body.max_tokens,
      }),
    });
    gw = await res.json();
    if (!res.ok || !gw.ok) {
      return json(
        { error: gw.error ?? "AI sedang sibuk, coba lagi sebentar", code: "AI_UPSTREAM" },
        502,
      );
    }
  } catch (e) {
    return json(
      { error: "AI Gateway tidak terjangkau", code: "AI_UPSTREAM", detail: String(e).slice(0, 150) },
      502,
    );
  }

  // Catat pemakaian (best-effort, sama seperti klien lama).
  try {
    await authClient.rpc("record_ai_usage", { p_org_id: orgId, p_kind: kind });
  } catch { /* diam */ }

  return json({ text: gw.text, model: gw.model ?? model ?? null });
});
