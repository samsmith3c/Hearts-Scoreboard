// Mirrors SharePayload.swift in the iOS app — the payload travels entirely in
// the URL (compact JSON → raw DEFLATE → unpadded base64url). Compression keeps
// links short enough that iMessage doesn't truncate them. Any shape change
// must be made in both places and versioned via `v`.

import { inflateSync } from "fflate";

/** Normalized hand for rendering (wire format packs each hand as an array). */
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
  /** Hands in play order, normalized from the wire format. */
  h: SharedHand[];
}

/**
 * Wire shape: hands are arrays of one score per player (n.length of them) +
 * optional trailing moon-shooter index. Still v1 — the 4-player encoding is
 * unchanged from pre-v1.4 links.
 */
type WirePayload = Omit<SharePayload, "h"> & { h: number[][] };

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function decodePayload(encoded: string): SharePayload | null {
  try {
    let base64 = encoded.replace(/-/g, "+").replace(/_/g, "/");
    while (base64.length % 4 !== 0) base64 += "=";
    const compressed = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
    const json = new TextDecoder().decode(inflateSync(compressed));
    const p = JSON.parse(json) as WirePayload;
    if (
      p.v !== 1 ||
      typeof p.id !== "string" ||
      !UUID_RE.test(p.id) ||
      !Array.isArray(p.n) ||
      p.n.length < 3 ||
      p.n.length > 6 ||
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
          Array.isArray(hand) &&
          (hand.length === p.n.length || hand.length === p.n.length + 1) &&
          hand.every((x) => Number.isInteger(x)),
      )
    ) {
      return null;
    }
    return {
      ...p,
      h: p.h.map((hand) => ({
        s: hand.slice(0, p.n.length),
        m: hand.length === p.n.length + 1 ? hand[p.n.length] : undefined,
      })),
    };
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
// - api/game.ts and api/og.tsx already render columns from p.n, so 3–6
//   players flow through unchanged; eyeball a 6-player /og render after the
//   next production deploy in case the fixed font sizes get cramped.
