// Verifikasi webhook qris-notif (murni, bisa diuji tanpa server).
// Skema: signature = hex(HMAC-SHA256(secret, `${timestamp}.${rawBody}`)).
// Timestamp unix detik; tolak bila selisih > maxSkewSeconds (anti-replay).
// Prefix "sha256=" pada signature opsional (dibuang sebelum dibandingkan).

export const DEFAULT_MAX_SKEW_SECONDS = 300;

export type HmacFailure =
  | "missing_timestamp"
  | "missing_signature"
  | "bad_timestamp"
  | "stale_timestamp"
  | "bad_signature";

export type HmacResult = { ok: true } | { ok: false; reason: HmacFailure };

const encoder = new TextEncoder();

export async function hmacSha256Hex(
  secret: string,
  message: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(message),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function timingSafeEqualString(a: string, b: string): boolean {
  const length = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < length; i++) {
    diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  }
  return diff === 0;
}

function normalizeSignature(signature: string): string {
  const trimmed = signature.trim().toLowerCase();
  return trimmed.startsWith("sha256=") ? trimmed.slice(7) : trimmed;
}

export async function verifyWebhookHmac(opts: {
  secret: string;
  timestamp: string;
  signature: string;
  rawBody: string;
  nowSeconds: number;
  maxSkewSeconds?: number;
}): Promise<HmacResult> {
  const maxSkew = opts.maxSkewSeconds ?? DEFAULT_MAX_SKEW_SECONDS;

  const timestamp = opts.timestamp.trim();
  if (timestamp === "") return { ok: false, reason: "missing_timestamp" };

  const signature = normalizeSignature(opts.signature);
  if (signature === "") return { ok: false, reason: "missing_signature" };

  if (!/^\d{1,12}$/.test(timestamp)) {
    return { ok: false, reason: "bad_timestamp" };
  }
  const ts = Number(timestamp);
  if (Math.abs(opts.nowSeconds - ts) > maxSkew) {
    return { ok: false, reason: "stale_timestamp" };
  }

  const expected = await hmacSha256Hex(
    opts.secret,
    `${timestamp}.${opts.rawBody}`,
  );
  if (!timingSafeEqualString(expected, signature)) {
    return { ok: false, reason: "bad_signature" };
  }
  return { ok: true };
}