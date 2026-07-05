// og:image for /og/<payload> — a 1200×630 render of the game, styled after the
// app's GameHistoryCard SwiftUI view (StatsView.swift): felt-green background,
// translucent card, date header, player columns with the winner's score in
// #4CD964, and up to 5 hand rows with 🌙 marking a shot moon. Differences from
// the in-app card are intentional: no trash icon and no "+N more hands"
// caption, since a static image can't be interacted with.

import { ImageResponse } from "@vercel/og";
import { decodePayload, formatDate } from "../lib/payload";

export const config = { runtime: "edge" };

const FELT_GREEN = "#2D5A27";
const WINNER_GREEN = "#4CD964";
const DIVIDER = "rgba(255,255,255,0.18)";
const IMAGE_HAND_LIMIT = 5; // matches GameHistoryCard.previewHandLimit

export default function handler(req: Request): Response {
  const url = new URL(req.url);
  const payload = decodePayload(url.searchParams.get("p") ?? "");
  if (!payload) {
    return new Response("Invalid game link.", { status: 400 });
  }

  const hands = payload.h.slice(0, IMAGE_HAND_LIMIT);

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: FELT_GREEN,
        }}
      >
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            width: 840,
            backgroundColor: "rgba(255,255,255,0.08)",
            borderRadius: 28,
            padding: 36,
          }}
        >
          {/* Header — date (no trash icon in the static image) */}
          <div
            style={{
              display: "flex",
              fontSize: 26,
              color: "rgba(255,255,255,0.6)",
            }}
          >
            {formatDate(payload)}
          </div>

          <div
            style={{
              display: "flex",
              height: 2,
              backgroundColor: DIVIDER,
              marginTop: 20,
              marginBottom: 20,
            }}
          />

          {/* Player names + final scores */}
          <div style={{ display: "flex" }}>
            {payload.n.map((name, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  flexGrow: 1,
                  flexBasis: 0,
                }}
              >
                <div
                  style={{
                    display: "flex",
                    fontSize: 28,
                    color: "#fff",
                    fontWeight: i === payload.w ? 700 : 400,
                  }}
                >
                  {name}
                </div>
                <div
                  style={{
                    display: "flex",
                    fontSize: 48,
                    fontWeight: 600,
                    marginTop: 4,
                    color: i === payload.w ? WINNER_GREEN : "#fff",
                  }}
                >
                  {payload.s[i] ?? 0}
                </div>
              </div>
            ))}
          </div>

          {hands.length > 0 && (
            <div
              style={{
                display: "flex",
                height: 2,
                backgroundColor: DIVIDER,
                marginTop: 20,
                marginBottom: 14,
              }}
            />
          )}

          {/* Hand-by-hand mini grid, capped at 5 — no overflow caption */}
          {hands.map((hand, row) => (
            <div key={row} style={{ display: "flex", marginTop: 8 }}>
              {payload.n.map((_, i) => (
                <div
                  key={i}
                  style={{
                    display: "flex",
                    justifyContent: "center",
                    flexGrow: 1,
                    flexBasis: 0,
                    fontSize: 26,
                    color: "rgba(255,255,255,0.75)",
                  }}
                >
                  {hand.m === i ? "🌙" : String(hand.s[i] ?? 0)}
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
      emoji: "twemoji",
      headers: {
        "Cache-Control": "public, max-age=86400",
      },
    },
  );
}

// What's next:
// - After first deploy, sanity-check /og/<payload> rendering in a browser
//   and tune spacing if a 4-player + 5-hand game overflows the card.
