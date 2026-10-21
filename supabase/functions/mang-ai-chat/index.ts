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
// Cadangan vision (terverifikasi 2026-10-21 bisa menerima gambar via
// gateway + menjawab benar): dipakai berantai bila model utama kena
// rate limit kuota free (429 bergelombang per model). Urutan =
// kebersihan output (minimax terakhir: suka membocorkan teks reasoning).
const VISION_FALLBACKS = [
  "big-pickle",
  "deepseek-v4.1-flash-free",
  "longcat-2.5-preview-free",
  "minimax-m3.1-flash-free",
  "glm-5.3-flash-free",
];
// ===== Batch 284 tahap E: pipeline receipt server-side =====
// Prompt receipt dirakit di sini (kategori org dibaca dari DB),
// keluaran model dinormalisasi jadi JSON ketat untuk parser
// tunggal klien. Request gaya lama (prompt/model dari klien)
// tetap diterima: model klien yang allowlist tetap dihormati,
// prompt klien diganti prompt server khusus kind receipt.
const DEFAULT_RECEIPT_CATEGORIES = [
  "Makanan",
  "Transportasi",
  "Belanja",
  "Tagihan",
  "Kesehatan",
  "Pendidikan",
  "Hiburan",
  "Pulsa & Internet",
  "Tabungan",
  "Lainnya",
];

// Cermin scanReceiptSystemPrompt Dart (format baris — terbukti
// robust untuk LLM) dengan daftar kategori dari server.
function receiptSystemPrompt(categories: string[]): string {
  const cats = categories
    .map((c) => c.trim())
    .filter((c) => c.length > 0)
    .join(", ");
  return "Kamu pengurai struk belanja Indonesia. Baca gambar struk dengan teliti " +
    "dari atas sampai bawah. Balas HANYA teks dengan format persis seperti contoh " +
    "ini, tanpa markdown, tanpa penjelasan, tanpa teks lain:\n" +
    "MERCHANT: Nama Gerai\n" +
    "DATE: 2026-09-08\n" +
    "TOTAL: 16000\n" +
    "CATEGORY: Makanan\n" +
    "ITEMS:\n" +
    "Racik Bumbu Sayur Asem 33gr | 1 | 1700\n" +
    "Sasa Santan Kelapa Cair 65ml | 1 | 4500\n" +
    "Aturan:\n" +
    "- MERCHANT: nama gerai, atau kosong bila tak ada.\n" +
    "- DATE: tanggal transaksi format YYYY-MM-DD.\n" +
    "- TOTAL: GRAND TOTAL yang dibayar (SETELAH diskon), integer murni dalam " +
    "rupiah (contoh 16000).\n" +
    "- CATEGORY: harus persis salah satu dari: " + cats + ".\n" +
    "- ITEMS: SEMUA baris produk dari atas sampai bawah struk, lengkap jangan " +
    "diringkas. Tiap baris format persis: nama produk | jumlah pcs | harga TOTAL " +
    "baris itu (qty x harga satuan) dalam rupiah integer.\n" +
    "- Abaikan baris subtotal/pajak/diskon/pembulatan/tunai/kembalian/metode " +
    "bayar (bukan produk).\n" +
    "- Jangan karang angka bila ragu; baris yang ragu boleh dilewati.\n" +
    "- Jangan pakai tool.";
}

// Kategori org dari DB: daftar bawaan app + kategori (lapis atas)
// yang pernah dipakai transaksi org ini. Fail-open: error -> bawaan.
async function receiptCategories(
  db: ReturnType<typeof createClient>,
  orgId: string,
): Promise<string[]> {
  const out = [...DEFAULT_RECEIPT_CATEGORIES];
  try {
    const { data } = await db
      .from("transactions")
      .select("category")
      .eq("org_id", orgId)
      .order("date", { ascending: false })
      .limit(300);
    for (const row of (data ?? []) as Record<string, unknown>[]) {
      const top = (row?.category ?? "").toString().split(">")[0].trim();
      if (top && !out.some((x) => x.toLowerCase() === top.toLowerCase())) {
        out.push(top);
        if (out.length >= 20) break;
      }
    }
  } catch { /* fail-open: daftar bawaan saja */ }
  return out;
}

// Ekstrak objek JSON pertama yang valid dari teks (utuh / fence /
// kurung seimbang sadar-string). Null bila tak ada.
function extractReceiptJson(t: string): Record<string, unknown> | null {
  const s = (t ?? "").trim();
  if (!s) return null;
  const ok = (txt: string): Record<string, unknown> | null => {
    try {
      const j = JSON.parse(txt);
      if (j && typeof j === "object" && !Array.isArray(j)) {
        return j as Record<string, unknown>;
      }
    } catch { /* lanjut */ }
    return null;
  };
  let j = ok(s);
  if (j) return j;
  const fence = s.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
  if (fence) {
    j = ok(fence[1].trim());
    if (j) return j;
  }
  const start = s.indexOf("{");
  if (start >= 0) {
    let depth = 0, inStr = false, esc = false, end = -1;
    for (let i = start; i < s.length; i++) {
      const c = s[i];
      if (inStr) {
        if (esc) esc = false;
        else if (c === "\\") esc = true;
        else if (c === '"') inStr = false;
      } else {
        if (c === '"') inStr = true;
        else if (c === "{") depth++;
        else if (c === "}") {
          depth--;
          if (depth === 0) { end = i; break; }
        }
      }
    }
    if (end > start) {
      j = ok(s.slice(start, end + 1));
      if (j) return j;
    }
  }
  return null;
}

// Parser format baris (cermin parseReceiptScanText Dart yang
// dipensiunkan di klien): MERCHANT/DATE/TOTAL/CATEGORY + ITEMS.
function parseReceiptLines(t: string): Record<string, unknown> | null {
  let s = (t ?? "").trim();
  if (!s) return null;
  s = s.replace(/^```(\w+)?\s*/, "").replace(/\s*```$/, "");
  const lines = s.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 0);
  if (!lines.length) return null;
  let merchant: string | null = null;
  let dateStr: string | null = null;
  let total: number | null = null;
  let categoryRaw: string | null = null;
  let i = 0;
  for (; i < lines.length; i++) {
    const l = lines[i];
    if (l.toUpperCase() === "ITEMS:") { i++; break; }
    const colon = l.indexOf(":");
    if (colon <= 0) continue;
    const key = l.substring(0, colon).trim().toUpperCase();
    const val = l.substring(colon + 1).trim();
    if (key === "MERCHANT") merchant = val || null;
    else if (key === "DATE") dateStr = val;
    else if (key === "TOTAL") {
      const digits = val.replace(/[^0-9]/g, "");
      total = digits ? parseInt(digits, 10) : null;
    } else if (key === "CATEGORY") categoryRaw = val;
  }
  if (total === null || !Number.isFinite(total) || total <= 0) return null;
  if (!dateStr || !/^\d{4}-\d{2}-\d{2}$/.test(dateStr.trim())) return null;
  const ds = dateStr.trim();
  const dt = new Date(ds + "T00:00:00Z");
  if (isNaN(dt.getTime()) || dt.toISOString().slice(0, 10) !== ds) return null;
  if (!categoryRaw || !categoryRaw.trim()) return null;
  const items: { name: string; qty: number; price: number }[] = [];
  for (; i < lines.length; i++) {
    const l = lines[i];
    if (l.startsWith("...")) continue;
    const parts = l.split("|");
    if (parts.length < 3) continue;
    const priceDigits = parts[parts.length - 1].trim().replace(/[^0-9]/g, "");
    const price = priceDigits ? parseInt(priceDigits, 10) : null;
    if (price === null || price < 0) continue;
    const qtyDigits = parts[parts.length - 2].trim().replace(/[^0-9]/g, "");
    let qty = qtyDigits ? parseInt(qtyDigits, 10) : 1;
    if (!qty || qty <= 0 || qty > 10000) qty = 1;
    let name = parts.slice(0, parts.length - 2).join("|").trim();
    if (!name) continue;
    if (name.length > 120) name = name.substring(0, 120);
    if (items.length >= 100) continue;
    items.push({ name, qty, price });
  }
  if (merchant && merchant.length > 120) {
    merchant = merchant.substring(0, 120);
  }
  return { merchant, date: ds, total, category: categoryRaw.trim(), items };
}

// Normalisasi keluaran receipt jadi JSON ketat
// {merchant, date, total, category, items[]}. Sumber bisa JSON
// (diekstrak) atau format baris. Kategori dipetakan ke daftar
// server (tak sensitif huruf); di luar daftar -> 'Lainnya'/pertama
// bila daftar ada. Tak terparse / tak valid -> teks apa adanya.
function normalizeReceiptContract(t: string, categories: string[]): string {
  const src = extractReceiptJson(t) ?? parseReceiptLines(t);
  if (!src) return t;
  const total = src.total;
  if (
    typeof total !== "number" || !Number.isFinite(total) || total <= 0 ||
    Math.floor(total) !== total
  ) return t;
  const date = typeof src.date === "string" ? src.date.trim() : "";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return t;
  const dt = new Date(date + "T00:00:00Z");
  if (isNaN(dt.getTime()) || dt.toISOString().slice(0, 10) !== date) return t;
  let category = typeof src.category === "string" ? src.category.trim() : "";
  if (!category) return t;
  const match = categories.find(
    (c) => c.toLowerCase() === category.toLowerCase(),
  );
  if (match) category = match;
  else if (categories.length) {
    category = categories.includes("Lainnya") ? "Lainnya" : categories[0];
  }
  const items: { name: string; qty: number; price: number }[] = [];
  if (Array.isArray(src.items)) {
    for (const e of src.items) {
      if (!e || typeof e !== "object") continue;
      const im = e as Record<string, unknown>;
      const nm = typeof im.name === "string" ? im.name.trim() : "";
      const pr = im.price;
      if (!nm) continue;
      if (
        typeof pr !== "number" || !Number.isFinite(pr) || pr < 0 ||
        Math.floor(pr) !== pr
      ) continue;
      let q = 1;
      if (
        typeof im.qty === "number" && im.qty > 0 && im.qty <= 10000 &&
        Math.floor(im.qty) === im.qty
      ) q = im.qty;
      items.push({
        name: nm.length > 120 ? nm.substring(0, 120) : nm,
        qty: q,
        price: pr,
      });
      if (items.length >= 100) break;
    }
  }
  const merchant =
    typeof src.merchant === "string" && src.merchant.trim()
      ? src.merchant.trim().substring(0, 120)
      : null;
  return JSON.stringify({ merchant, date, total, category, items });
}

const MAX_BODY_CHARS = 6_500_000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Normalisasi jawaban chat ke kontrak {"reply","action"}: sebagian
// model free membungkus JSON dengan prosa / fence sehingga parser
// ketat di aplikasi gagal dan JSON mentah bocor ke bubble user.
// Ekstrak objek kontraknya (pindai kurung seimbang dari kemunculan
// terakhir '{"reply"'), buang markdown ** di reply, serialisasi
// ulang bersih. Teks tanpa kontrak dikembalikan apa adanya.
function extractContractJson(t: string): Record<string, unknown> | null {
  const s = (t ?? "").trim();
  if (!s) return null;
  const ok = (txt: string): Record<string, unknown> | null => {
    try {
      const j = JSON.parse(txt);
      if (j && typeof j === "object" && typeof j.reply === "string" && j.reply.trim()) {
        return j as Record<string, unknown>;
      }
    } catch { /* lanjut */ }
    return null;
  };
  let j = ok(s);
  if (j) return j;
  const fence = s.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/);
  if (fence) {
    j = ok(fence[1].trim());
    if (j) return j;
  }
  let idx = s.lastIndexOf('{"reply"');
  while (idx >= 0) {
    let depth = 0, inStr = false, esc = false, end = -1;
    for (let i = idx; i < s.length; i++) {
      const c = s[i];
      if (inStr) {
        if (esc) esc = false;
        else if (c === "\\") esc = true;
        else if (c === '"') inStr = false;
      } else {
        if (c === '"') inStr = true;
        else if (c === "{") depth++;
        else if (c === "}") {
          depth--;
          if (depth === 0) { end = i; break; }
        }
      }
    }
    if (end > idx) {
      j = ok(s.slice(idx, end + 1));
      if (j) return j;
    }
    idx = idx > 0 ? s.lastIndexOf('{"reply"', idx - 1) : -1;
  }
  return null;
}

function normalizeChatContract(t: string): string {
  const j = extractContractJson(t);
  if (!j) return t;
  const reply = String(j.reply).replace(/\*\*/g, "").trim();
  return JSON.stringify({ reply, action: j.action ?? null });
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

  // Batch 284 tahap E: prompt receipt dirakit server — kategori org
  // dibaca dari DB, system prompt klien untuk kind receipt DIGANTI
  // prompt server. Request gaya lama (prompt + model pin dari
  // klien) tetap diterima; model klien yang allowlist dihormati.
  let receiptCats: string[] = [];
  let outMessages: unknown = body.messages;
  if (kind === "receipt") {
    receiptCats = await receiptCategories(db, orgId);
    const msgs = (body.messages as Record<string, unknown>[]).slice();
    const sysMsg = {
      role: "system",
      content: receiptSystemPrompt(receiptCats),
    };
    const sysIdx = msgs.findIndex((m) => m && m.role === "system");
    if (sysIdx >= 0) msgs[sysIdx] = sysMsg;
    else msgs.unshift(sysMsg);
    outMessages = msgs;
  }

  // Model: receipt -> vision; model dari klien hanya bila ada di allowlist.
  let model: string | undefined;
  if (body.model && ALLOWED_MODELS.has(body.model)) model = body.model;
  if (kind === "receipt" && !model) model = VISION_MODEL;

  // Teruskan ke AI Gateway (Worker). Request BERGAMBAR (scan struk
  // maupun foto di chat — klien mem-pin model vision untuk keduanya):
  // coba berantai model utama lalu VISION_FALLBACKS. Kuota free per
  // model kena 429 bergelombang; satu model gagal tidak boleh
  // menggagalkan request.
  const hasImagePart = raw.includes('"image_url"');
  const candidates: (string | undefined)[] = [model];
  if (kind === "receipt" || hasImagePart) {
    for (const fb of VISION_FALLBACKS) {
      if (fb !== model && ALLOWED_MODELS.has(fb)) candidates.push(fb);
    }
  }
  let gw: { ok?: boolean; text?: string; model?: string; error?: string } | null = null;
  let lastErr = "AI sedang sibuk, coba lagi sebentar";
  for (const cand of candidates) {
    try {
      const res = await fetch(`${gwUrl}/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-gw-key": gwKey },
        body: JSON.stringify({
          model: cand,
          messages: outMessages,
          max_tokens: body.max_tokens,
        }),
      });
      const parsed = await res.json();
      if (res.ok && parsed.ok) {
        gw = parsed;
        model = cand;
        break;
      }
      lastErr = parsed.error ?? lastErr;
    } catch (e) {
      lastErr = "AI Gateway tidak terjangkau: " + String(e).slice(0, 120);
    }
  }
  if (!gw) {
    return json({ error: lastErr, code: "AI_UPSTREAM" }, 502);
  }

  // Catat pemakaian (best-effort, sama seperti klien lama).
  try {
    await authClient.rpc("record_ai_usage", { p_org_id: orgId, p_kind: kind });
  } catch { /* diam */ }

  let outText = gw.text;
  if ((kind === "chat" || kind === "quick") && gw.text) {
    outText = normalizeChatContract(gw.text);
  } else if (kind === "receipt" && gw.text) {
    // Tahap E: keluaran receipt dinormalisasi jadi JSON ketat
    // {merchant, date, total, category, items[]} untuk parser
    // tunggal klien; tak terparse -> teks apa adanya (fail-open).
    outText = normalizeReceiptContract(gw.text, receiptCats);
  }
  return json({ text: outText, model: gw.model ?? model ?? null });
});
