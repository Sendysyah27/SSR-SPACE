// Supabase Edge Function: webhook pembayaran QRIS dari watcher notifikasi.
// Spec: BRIEF-QRIS-PAYMENT-SSRSPACE.md §5.3 & §6.
// Dipanggil watcher Termux di HP Sendy setelah mem-parsing notifikasi
// pembayaran GoPay (paket com.gojek.gopay, title "Pembayaran QRIS statis
// diterima"). Auth: header x-webhook-secret == env QRIS_WEBHOOK_SECRET.
// Body: { amount: number, ... } — field lain dari notifikasi (packageName,
// title, content, when) diterima untuk audit pemanggil tapi diabaikan.
//
// Pencocokan: amount_total persis pada order berstatus
// pending/awaiting_confirmation yang belum kedaluwarsa.
// - 0 kandidat  -> { matched:false, reason:"no_active_order" } (idempoten:
//   notifikasi duplikat setelah paid jatuh ke sini dan tidak mengubah apa pun)
// - >1 kandidat -> { matched:false, reason:"ambiguous" } (brief §6 butir 5:
//   ditahan, jatuh ke verifikasi manual)
// - 1 kandidat  -> order paid (verified_via='notif_auto') + aktivasi plan:
//   plan_expires_at = greatest(now(), plan_expires_at) + duration_days;
//   plan permanen (duration_days NULL) -> 9999-12-31.
// Deploy: supabase functions deploy qris-notif-webhook --no-verify-jwt
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const PERMANENT_EXPIRY = "9999-12-31T23:59:59.000Z";

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const secret = Deno.env.get("QRIS_WEBHOOK_SECRET") ?? "";
  const given = req.headers.get("x-webhook-secret") ?? "";
  if (!secret || given !== secret) {
    return json({ error: "Secret tidak valid" }, 401);
  }

  let body: { amount?: number };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Body JSON tidak valid" }, 400);
  }
  const amount = Number(body.amount);
  if (!Number.isInteger(amount) || amount <= 0) {
    return json({ error: "amount harus bilangan bulat positif" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const db = createClient(supabaseUrl, serviceKey);

  const now = new Date();
  const nowIso = now.toISOString();

  const { data: candidates, error: candErr } = await db
    .from("payment_orders")
    .select("id, org_id, plan_code, status")
    .eq("amount_total", amount)
    .in("status", ["pending", "awaiting_confirmation"])
    .gt("expires_at", nowIso)
    .order("created_at", { ascending: true })
    .limit(2);
  if (candErr) {
    return json({ error: "Gagal mencari order: " + candErr.message }, 500);
  }
  if (!candidates || candidates.length === 0) {
    return json({ matched: false, reason: "no_active_order" }, 200);
  }
  if (candidates.length > 1) {
    return json({ matched: false, reason: "ambiguous" }, 200);
  }
  const order = candidates[0];

  // Durasi plan order ini.
  const { data: plan } = await db
    .from("plan_pricing")
    .select("duration_days")
    .eq("plan_code", order.plan_code as string)
    .maybeSingle();
  if (!plan) {
    return json({ error: "Plan order tidak ditemukan" }, 500);
  }

  // Hitung expiry baru mengikuti brief §5.3.
  const { data: org } = await db
    .from("organizations")
    .select("plan_expires_at")
    .eq("id", order.org_id as string)
    .maybeSingle();
  if (!org) return json({ error: "Organization tidak ditemukan" }, 500);

  let newExpiry: string;
  if (plan.duration_days === null || plan.duration_days === undefined) {
    newExpiry = PERMANENT_EXPIRY;
  } else {
    const current = org.plan_expires_at
      ? new Date(org.plan_expires_at as string)
      : null;
    const base = current && current.getTime() > now.getTime() ? current : now;
    newExpiry = new Date(
      base.getTime() + (plan.duration_days as number) * 86_400_000,
    ).toISOString();
  }

  // Tandai paid — dijaga status masih aktif agar retry/race tidak dobel.
  const { data: paidRows, error: paidErr } = await db
    .from("payment_orders")
    .update({
      status: "paid",
      paid_at: nowIso,
      verified_via: "notif_auto",
      updated_at: nowIso,
    })
    .eq("id", order.id as string)
    .in("status", ["pending", "awaiting_confirmation"])
    .select("id");
  if (paidErr) {
    return json({ error: "Gagal menandai paid: " + paidErr.message }, 500);
  }
  if (!paidRows || paidRows.length === 0) {
    return json({ matched: false, reason: "already_processed" }, 200);
  }

  // Aktivasi plan. Bila gagal, kembalikan status order seperti semula agar
  // watcher bisa mencoba lagi (kompensasi manual; tidak ada transaksi
  // lintas-tabel di PostgREST).
  const { error: orgErr } = await db
    .from("organizations")
    .update({ plan_expires_at: newExpiry })
    .eq("id", order.org_id as string);
  if (orgErr) {
    await db
      .from("payment_orders")
      .update({
        status: order.status as string,
        paid_at: null,
        verified_via: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", order.id as string);
    return json({ error: "Gagal aktivasi plan: " + orgErr.message }, 500);
  }

  return json(
    {
      matched: true,
      order_id: order.id,
      org_id: order.org_id,
      plan_code: order.plan_code,
      amount_total: amount,
      plan_expires_at: newExpiry,
    },
    200,
  );
});
