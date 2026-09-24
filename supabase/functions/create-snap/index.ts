// Supabase Edge Function: create Midtrans Snap token.
// Deploy dari PC (CLI tidak jalan di Termux):
//   supabase functions deploy create-snap --no-verify-jwt
// Secrets: MIDTRANS_SERVER_KEY, MIDTRANS_IS_PRODUCTION
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const { orderId, amount } = await req.json();
  const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
  const isProd = (Deno.env.get("MIDTRANS_IS_PRODUCTION") ?? "false") === "true";
  const base = isProd ? "https://app.midtrans.com" : "https://app.sandbox.midtrans.com";
  const res = await fetch(`${base}/snap/v1/transactions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Basic " + btoa(serverKey + ":"),
    },
    body: JSON.stringify({
      transaction_details: { order_id: orderId, gross_amount: Math.round(amount) },
    }),
  });
  const data = await res.json();
  return new Response(JSON.stringify(data), { headers: { "Content-Type": "application/json" } });
});
