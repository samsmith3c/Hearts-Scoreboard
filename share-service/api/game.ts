// Fallback recap page for /g/<payload>. Recipients with the app installed
// never see this — the Universal Link routes straight into the app. This page
// serves the OG tags for the iMessage/Safari preview card, a human-readable
// recap, and an App Store install link.

import {
  decodePayload,
  escapeHtml,
  formatDate,
  type SharePayload,
} from "../lib/payload";

export const config = { runtime: "edge" };

// TODO(release): replace with the app's real App Store link
// (https://apps.apple.com/app/id<AppleID>) once the App Store Connect record
// exists — tracked as PR #1 checklist item 8. Placeholder for now so the
// install button is testable.
const APP_STORE_URL = "https://www.apple.com/app-store/";

function ogTitle(p: SharePayload): string {
  return `♥ Hearts: ${p.n[p.w]} wins with ${p.s[p.w]}!`;
}

function ogDescription(p: SharePayload): string {
  const scores = p.n.map((name, i) => `${name} ${p.s[i]}`).join(" · ");
  const hands = `${p.h.length} hand${p.h.length === 1 ? "" : "s"}`;
  return `${formatDate(p)} — ${scores} (${hands})`;
}

export default function handler(req: Request): Response {
  const url = new URL(req.url);
  const encoded = url.searchParams.get("p") ?? "";
  const payload = decodePayload(encoded);

  if (!payload) {
    return new Response("Invalid or expired game link.", {
      status: 400,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }

  const title = escapeHtml(ogTitle(payload));
  const description = escapeHtml(ogDescription(payload));
  const ogImageURL = `${url.origin}/og/${encoded}`;
  const pageURL = `${url.origin}/g/${encoded}`;

  const scoreRows = payload.n
    .map((name, i) => {
      const isWinner = i === payload.w;
      return `<div class="player${isWinner ? " winner" : ""}">
        <div class="name">${escapeHtml(name)}</div>
        <div class="score">${payload.s[i]}</div>
      </div>`;
    })
    .join("");

  const handRows = payload.h
    .map(
      (hand) => `<div class="hand">${payload.n
        .map((_, i) =>
          hand.m === i
            ? `<span>🌙</span>`
            : `<span>${hand.s[i] ?? 0}</span>`,
        )
        .join("")}</div>`,
    )
    .join("");

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta property="og:type" content="website">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:image" content="${ogImageURL}">
<meta property="og:url" content="${pageURL}">
<meta name="twitter:card" content="summary_large_image">
<style>
  body {
    margin: 0; min-height: 100vh;
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    background: #2D5A27; color: #fff;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    padding: 24px; box-sizing: border-box;
  }
  .card {
    background: rgba(255,255,255,0.08); border-radius: 12px;
    padding: 20px; width: 100%; max-width: 420px;
  }
  .date { font-size: 13px; color: rgba(255,255,255,0.6); text-align: center; }
  .divider { height: 1px; background: rgba(255,255,255,0.18); margin: 12px 0; }
  .players { display: flex; }
  .player { flex: 1; text-align: center; }
  .player .name { font-size: 13px; }
  .player .score { font-size: 22px; font-weight: 600; margin-top: 2px; }
  .player.winner .name { font-weight: 700; }
  .player.winner .score { color: #4CD964; }
  .hand { display: flex; margin-top: 6px; }
  .hand span { flex: 1; text-align: center; font-size: 13px; color: rgba(255,255,255,0.75); }
  a.install {
    display: inline-block; background: #C8102E; color: #fff;
    font-weight: 600; text-decoration: none; margin-top: 28px;
    padding: 12px 28px; border-radius: 24px; font-size: 16px;
  }
</style>
</head>
<body>
  <div class="card">
    <div class="date">${escapeHtml(formatDate(payload))}</div>
    <div class="divider"></div>
    <div class="players">${scoreRows}</div>
    <div class="divider"></div>
    ${handRows}
  </div>
  <a class="install" href="${APP_STORE_URL}">Get the App</a>
</body>
</html>`;

  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=86400",
    },
  });
}

// What's next:
// - Set APP_STORE_URL once Sam provides the real App Store link (plan step 8).
// - api/og.tsx renders the og:image referenced above (plan step 6).
