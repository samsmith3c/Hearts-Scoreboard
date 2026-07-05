//
//  SharePayload.swift
//  Hearts Scoreboard
//
//  Wire format for v1.3 recap-sharing links. The entire game travels in the
//  URL itself (compact JSON → base64url) — the web service is stateless and
//  stores nothing. The same JSON shape is decoded by share-service (TypeScript),
//  so any change here is a breaking change there; bump `v` if the shape changes.
//

import Foundation

enum ShareConfig {
    /// Set to the deployed Vercel domain in plan step 9/10.
    static let baseURL = URL(string: "https://PENDING.vercel.app")!
    /// Path prefix for recap links; must match the AASA `components` pattern
    /// and the share-service rewrite.
    static let gamePathPrefix = "g"
}

struct SharePayload: Codable, Equatable {

    struct Hand: Codable, Equatable {
        /// Per-player scores for the hand, same order as `playerNames`.
        var s: [Int]
        /// Moon shooter's player index, if this hand was a shot moon.
        var m: Int?
    }

    /// Payload format version.
    var v: Int = 1
    /// The game's stable shareID (lowercase UUID string) — dedupe key.
    var id: String
    /// Game date as Unix seconds.
    var d: Int
    /// Sharer's UTC offset in minutes at game time, so the web recap can show
    /// the wall-clock time the game was played. Optional for forward compat.
    var z: Int?
    /// Player names, seat order.
    var n: [String]
    /// Final cumulative scores, same order.
    var s: [Int]
    /// Winner (lowest score) index.
    var w: Int
    /// Hands in play order.
    var h: [Hand]

    // MARK: - Build from a saved game

    init?(game: SavedGame) {
        guard let shareID = game.shareID else { return nil }
        self.id = shareID.uuidString.lowercased()
        self.d = Int(game.date.timeIntervalSince1970)
        self.z = TimeZone.current.secondsFromGMT(for: game.date) / 60
        self.n = game.playerNames
        self.s = game.finalScores
        self.w = game.winnerIndex
        self.h = (game.hands ?? [])
            .sorted { $0.handNumber < $1.handNumber }
            .map { Hand(s: $0.scores, m: $0.isMoonShoot ? $0.moonShooterIndex : nil) }
    }

    // MARK: - URL encoding

    /// base64url (RFC 4648 §5, unpadded) of the compact JSON.
    func encodedString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let json = try? encoder.encode(self) else { return nil }
        return json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Full share URL: https://<host>/g/<payload>
    func shareURL() -> URL? {
        guard let encoded = encodedString() else { return nil }
        return ShareConfig.baseURL
            .appendingPathComponent(ShareConfig.gamePathPrefix)
            .appendingPathComponent(encoded)
    }

    // MARK: - URL decoding (incoming Universal Link)

    init?(encodedString: String) {
        var base64 = encodedString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONDecoder().decode(SharePayload.self, from: data),
              payload.v == 1,
              UUID(uuidString: payload.id) != nil,
              !payload.n.isEmpty,
              payload.n.count == payload.s.count
        else { return nil }
        self = payload
    }

    /// Parses an incoming Universal Link of the form https://<host>/g/<payload>.
    init?(url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == ShareConfig.gamePathPrefix else { return nil }
        self.init(encodedString: parts[1])
    }

    // MARK: - Import as a SavedGame

    /// Materializes the payload as a new SavedGame, preserving the incoming
    /// shareID so dedupe keeps working if this copy is shared onward.
    func makeSavedGame() -> SavedGame {
        let game = SavedGame(
            date: Date(timeIntervalSince1970: TimeInterval(d)),
            playerNames: n,
            finalScores: s,
            winnerIndex: w,
            shareID: UUID(uuidString: id)
        )
        var savedHands: [SavedHand] = []
        for (i, hand) in h.enumerated() {
            let savedHand = SavedHand(
                handNumber: i,
                scores: hand.s,
                isMoonShoot: hand.m != nil,
                moonShooterIndex: hand.m,
                game: game
            )
            savedHands.append(savedHand)
        }
        game.hands = savedHands
        return game
    }
}

// What's next:
// - share-service decodes this exact JSON shape (plan steps 5–6).
// - Replace ShareConfig.baseURL placeholder with the deployed Vercel domain (step 9/10).
// - ShareLink in GameDetailView builds the URL via SharePayload(game:) (step 10).
// - Incoming Universal Links decode via SharePayload(url:) (step 12).
