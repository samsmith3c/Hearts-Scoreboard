# Hearts Score — share service

Stateless Vercel project backing v1.3 Recap Sharing. Serves three things:

| Route | What it does |
|---|---|
| `/.well-known/apple-app-site-association` | Universal Links association file (static, JSON content type via `vercel.json`) |
| `/g/<payload>` | Fallback recap page: OG tags for the iMessage/Safari preview card, human-readable recap, App Store install link |
| `/og/<payload>` | Per-game `og:image` (1200×630) rendered with `@vercel/og`, styled after the app's `GameHistoryCard` |

`<payload>` is the entire game encoded as compact JSON → unpadded base64url; nothing is stored server-side. The format is defined in both [`lib/payload.ts`](lib/payload.ts) and `SharePayload.swift` in the iOS app — keep them in sync.

## Deploying (one-time setup, Vercel Hobby plan)

1. vercel.com → Add New → Project → import the `Hearts-Scoreboard` GitHub repo.
2. Set **Root Directory** to `share-service` (Framework Preset: **Other**). Leave build command and output directory empty.
3. Deploy. The free `<project>.vercel.app` domain is all we need — no purchased domain required.
4. Verify `https://<project>.vercel.app/.well-known/apple-app-site-association` returns the JSON directly (no redirect).

The iOS app's `ShareConfig.baseURL` and Associated Domains entitlement must match the deployed domain.
