// Supabase Edge Function: buat order pembayaran QRIS dinamis.
// Spec: BRIEF-QRIS-PAYMENT-SSRSPACE.md §3/§5/§7.
// Auth: JWT user; pemanggil WAJIB anggota org (org_members).
// Harga SELALU diambil server-side dari plan_pricing — nominal dari client
// tidak dibaca sama sekali. Kode unik 100-999 dialokasikan agar tidak
// tabrakan dengan order aktif lain (dijaga juga oleh partial unique index
// payment_orders_unique_code_live di migration_26).
// Secrets: QRIS_STATIC_PAYLOAD (payload QRIS statis merchant Sendy).
// Deploy: supabase functions deploy create-qris-order
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { make_dynamic } from "../_shared/qris.ts";

// Jendela pembayaran per order (brief §10 butir 3 — usulan 30 menit;
// ubah di sini bila Sendy memutuskan lain).
const ORDER_EXPIRY_MINUTES = 30;

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
  const staticPayload = Deno.env.get("QRIS_STATIC_PAYLOAD") ?? "";
  if (!staticPayload) {
    return json({ error: "QRIS_STATIC_PAYLOAD belum dikonfigurasi" }, 500);
  }

  // Validasi JWT pemanggil.
  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData.user) return json({ error: "Token tidak valid" }, 401);
  const user = userData.user;

  let body: { org_id?: string; plan_code?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Body JSON tidak valid" }, 400);
  }
  const orgId = body.org_id;
  const planCode = body.plan_code;
  if (!orgId || !planCode) {
    return json({ error: "org_id dan plan_code wajib diisi" }, 400);
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

  // Harga dari plan_pricing (server-side).
  const { data: plan } = await db
    .from("plan_pricing")
    .select("plan_code, price_idr, is_active")
    .eq("plan_code", planCode)
    .maybeSingle();
  if (!plan || !plan.is_active) {
    return json({ error: "Plan tidak ditemukan / tidak aktif" }, 404);
  }

  // Kode unik yang sedang dipakai order aktif.
  const { data: live } = await db
    .from("payment_orders")
    .select("unique_code")
    .in("status", ["pending", "awaiting_confirmation"]);
  const used = new Set<number>(
    (live ?? []).map((r: { unique_code: number }) => r.unique_code),
  );

  const expiresAt = new Date(
    Date.now() + ORDER_EXPIRY_MINUTES * 60_000,
  ).toISOString();

  // Alokasi kode unik + insert. Tabrakan index unik (Postgres 23505,
  // mis. dua request bersamaan) -> coba kode lain.
  for (let attempt = 0; attempt < 12; attempt++) {
    const candidates: number[] = [];
    for (let code = 100; code <= 999; code++) {
      if (!used.has(code)) candidates.push(code);
    }
    if (candidates.length === 0) {
      return json({ error: "Kode unik habis, coba lagi nanti" }, 503);
    }
    const uniqueCode =
      candidates[Math.floor(Math.random() * candidates.length)];
    const amountTotal = (plan.price_idr as number) + uniqueCode;

    let payload: string;
    try {
      payload = make_dynamic(staticPayload, amountTotal);
    } catch (e) {
      return json(
        { error: "Payload QRIS merchant tidak valid: " + (e as Error).message },
        500,
      );
    }

    const { data: order, error: insErr } = await db
      .from("payment_orders")
      .insert({
        org_id: orgId,
        user_id: user.id,
        plan_code: planCode,
        amount_base: plan.price_idr,
        unique_code: uniqueCode,
        amount_total: amountTotal,
        qris_payload: payload,
        status: "pending",
        expires_at: expiresAt,
      })
      .select(
        "id, org_id, plan_code, amount_base, unique_code, amount_total, qris_payload, status, expires_at",
      )
      .single();

    if (!insErr && order) return json(order, 200);
    if (insErr && (insErr as { code?: string }).code === "23505") {
      used.add(uniqueCode);
      continue;
    }
    return json(
      { error: "Gagal membuat order: " + (insErr?.message ?? "unknown") },
      500,
    );
  }
  return json({ error: "Gagal alokasi kode unik, coba lagi" }, 503);
});
