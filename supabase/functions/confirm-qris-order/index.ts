// Supabase Edge Function: konfirmasi user "Saya sudah bayar".
// Spec: BRIEF-QRIS-PAYMENT-SSRSPACE.md §6 (fallback) & §7.
// Auth: JWT user; order harus milik org tempat pemanggil menjadi anggota.
// Transisi: pending -> awaiting_confirmation. Idempoten untuk order yang
// sudah awaiting_confirmation. Order kedaluwarsa ditandai expired.
// Deploy: supabase functions deploy confirm-qris-order
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const ORDER_FIELDS =
  "id, org_id, plan_code, amount_total, status, expires_at, paid_at";

serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Token tidak ada" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData.user) return json({ error: "Token tidak valid" }, 401);
  const user = userData.user;

  let body: { order_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Body JSON tidak valid" }, 400);
  }
  const orderId = body.order_id;
  if (!orderId) return json({ error: "order_id wajib diisi" }, 400);

  const db = createClient(supabaseUrl, serviceKey);

  const { data: order } = await db
    .from("payment_orders")
    .select(ORDER_FIELDS)
    .eq("id", orderId)
    .maybeSingle();
  if (!order) return json({ error: "Order tidak ditemukan" }, 404);

  // Pemanggil wajib anggota org pemilik order.
  const { data: member } = await db
    .from("org_members")
    .select("org_id")
    .eq("org_id", order.org_id as string)
    .eq("user_id", user.id)
    .maybeSingle();
  if (!member) return json({ error: "Bukan anggota workspace ini" }, 403);

  if (order.status === "awaiting_confirmation") {
    return json(order, 200); // sudah dikonfirmasi sebelumnya (idempoten)
  }
  if (order.status !== "pending") {
    return json(
      { error: "Status order tidak bisa dikonfirmasi", status: order.status },
      409,
    );
  }

  // Order lewat jendela bayar -> expired, tidak bisa dikonfirmasi.
  if (new Date(order.expires_at as string).getTime() <= Date.now()) {
    await db
      .from("payment_orders")
      .update({ status: "expired", updated_at: new Date().toISOString() })
      .eq("id", orderId)
      .eq("status", "pending");
    return json({ error: "Order sudah kedaluwarsa", status: "expired" }, 410);
  }

  const { data: updated, error: updErr } = await db
    .from("payment_orders")
    .update({
      status: "awaiting_confirmation",
      updated_at: new Date().toISOString(),
    })
    .eq("id", orderId)
    .eq("status", "pending")
    .select(ORDER_FIELDS)
    .maybeSingle();
  if (updErr) {
    return json({ error: "Gagal konfirmasi: " + updErr.message }, 500);
  }
  if (!updated) {
    return json({ error: "Status order sudah berubah", status: order.status }, 409);
  }
  return json(updated, 200);
});
