// Mirrors SharePayload.swift in the iOS app — the payload travels entirely in
// the URL (compact JSON → unpadded base64url). Any shape change must be made
// in both places and versioned via `v`.

export interface SharedHand {
  /** Per-player scores for the hand, seat order. */
  s: number[];
  /** Moon shooter's player index, if this hand was a shot moon. */
  m?: number;
}

export interface SharePayload {
  /** Payload format version. */
  v: number;
  /** The game's stable shareID (lowercase UUID string) — dedupe key. */
  id: string;
  /** Game date as Unix seconds. */
  d: number;
  /** Sharer's UTC offset in minutes at game time (for wall-clock display). */
  z?: number;
  /** Player names, seat order. */
  n: string[];
  /** Final cumulative scores, same order. */
  s: number[];
  /** Winner (lowest score) index. */
  w: number;
  /** Hands in play order. */
  h: SharedHand[];
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function decodePayload(encoded: string): SharePayload | null {
  try {
    let base64 = encoded.replace(/-/g, "+").replace(/_/g, "/");
    while (base64.length % 4 !== 0) base64 += "=";
    const json = new TextDecoder().decode(
      Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)),
    );
    const p = JSON.parse(json) as SharePayload;
    if (
      p.v !== 1 ||
      typeof p.id !== "string" ||
      !UUID_RE.test(p.id) ||
      !Array.isArray(p.n) ||
      p.n.length === 0 ||
      p.n.length > 4 ||
      !Array.isArray(p.s) ||
      p.s.length !== p.n.length ||
      typeof p.w !== "number" ||
      p.w < 0 ||
      p.w >= p.n.length ||
      !Array.isArray(p.h) ||
      !p.n.every((x) => typeof x === "string" && x.length <= 40) ||
      !p.s.every((x) => Number.isInteger(x)) ||
      !p.h.every(
        (hand) =>
          Array.isArray(hand.s) && hand.s.every((x) => Number.isInteger(x)),
      )
    ) {
      return null;
    }
    return p;
  } catch {
    return null;
  }
}

/** Shifted so that formatting in UTC yields the sharer's wall-clock time. */
export function wallClockDate(p: SharePayload): Date {
  return new Date((p.d + (p.z ?? 0) * 60) * 1000);
}

export function formatDate(p: SharePayload): string {
  return wallClockDate(p).toLocaleString("en-US", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  });
}

export function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// What's next:
// - api/game.ts renders the recap page + OG tags from this payload.
// - api/og.tsx renders the GameHistoryCard-styled image from this payload.
