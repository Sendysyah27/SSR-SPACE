// Unit test verifikasi HMAC webhook — `deno test`.
import {
  DEFAULT_MAX_SKEW_SECONDS,
  hmacSha256Hex,
  timingSafeEqualString,
  verifyWebhookHmac,
} from "./webhook_auth.ts";

const SECRET = "rahasia-uji-123";
const NOW = 1_800_000_000;

async function sign(body: string, ts = NOW): Promise<string> {
  return await hmacSha256Hex(SECRET, `${ts}.${body}`);
}

Deno.test("HMAC valid diterima", async () => {
  const body = '{"amount":1137}';
  const result = await verifyWebhookHmac({
    secret: SECRET,
    timestamp: String(NOW),
    signature: await sign(body),
    rawBody: body,
    nowSeconds: NOW,
  });
  assertEquals(result, { ok: true });
});

Deno.test("prefix sha256= diterima", async () => {
  const body = '{"amount":1}';
  const result = await verifyWebhookHmac({
    secret: SECRET,
    timestamp: String(NOW),
    signature: "sha256=" + (await sign(body)),
    rawBody: body,
    nowSeconds: NOW,
  });
  assertEquals(result, { ok: true });
});

Deno.test("body diubah ditolak", async () => {
  const body = '{"amount":1137}';
  const result = await verifyWebhookHmac({
    secret: SECRET,
    timestamp: String(NOW),
    signature: await sign(body),
    rawBody: '{"amount":9999}',
    nowSeconds: NOW,
  });
  assertEquals(result, { ok: false, reason: "bad_signature" });
});

Deno.test("secret salah ditolak", async () => {
  const body = '{"amount":1}';
  const result = await verifyWebhookHmac({
    secret: "salah",
    timestamp: String(NOW),
    signature: await sign(body),
    rawBody: body,
    nowSeconds: NOW,
  });
  assertEquals(result, { ok: false, reason: "bad_signature" });
});

Deno.test("timestamp kedaluwarsa ditolak", async () => {
  const body = '{"amount":1}';
  const old = NOW - DEFAULT_MAX_SKEW_SECONDS - 1;
  const result = await verifyWebhookHmac({
    secret: SECRET,
    timestamp: String(old),
    signature: await sign(body, old),
    rawBody: body,
    nowSeconds: NOW,
  });
  assertEquals(result, { ok: false, reason: "stale_timestamp" });
});

Deno.test("timestamp masa depan jauh ditolak", async () => {
  const body = '{"amount":1}';
  const future = NOW + DEFAULT_MAX_SKEW_SECONDS + 1;
  const result = await verifyWebhookHmac({
    secret: SECRET,
    timestamp: String(future),
    signature: await sign(body, future),
    rawBody: body,
    nowSeconds: NOW,
  });
  assertEquals(result, { ok: false, reason: "stale_timestamp" });
});

Deno.test("header kosong / bukan angka / signature kosong", async () => {
  const body = "{}";
  assertEquals(
    await verifyWebhookHmac({
      secret: SECRET,
      timestamp: "",
      signature: "abc",
      rawBody: body,
      nowSeconds: NOW,
    }),
    { ok: false, reason: "missing_timestamp" },
  );
  assertEquals(
    await verifyWebhookHmac({
      secret: SECRET,
      timestamp: "abc",
      signature: "abc",
      rawBody: body,
      nowSeconds: NOW,
    }),
    { ok: false, reason: "bad_timestamp" },
  );
  assertEquals(
    await verifyWebhookHmac({
      secret: SECRET,
      timestamp: String(NOW),
      signature: "",
      rawBody: body,
      nowSeconds: NOW,
    }),
    { ok: false, reason: "missing_signature" },
  );
});

Deno.test("timingSafeEqualString akurat", () => {
  if (!timingSafeEqualString("abc", "abc")) throw new Error("harus sama");
  if (timingSafeEqualString("abc", "abd")) throw new Error("harus beda");
  if (timingSafeEqualString("abc", "abcd")) throw new Error("harus beda");
  if (!timingSafeEqualString("", "")) throw new Error("kosong = kosong");
});

function assertEquals<T>(actual: T, expected: T): void {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`expected ${e}, dapat ${a}`);
}