//
//  SharePayload.swift
//  Hearts Scoreboard
//
//  Wire format for v1.3 recap-sharing links. The entire game travels in the
//  URL itself (compact JSON → raw DEFLATE → base64url) — the web service is
//  stateless and stores nothing. Compression matters: iMessage silently
//  truncates long URLs, so the link must stay short even for many-hand games.
//  The same format is decoded by share-service (TypeScript); any change here
//  is a breaking change there — bump `v` if the shape changes.
//

import Foundation
import Compression

enum ShareConfig {
    /// Must match the Associated Domains entitlement and the deployed
    /// share-service project.
    static let baseURL = URL(string: "https://hearts-scoreboard.vercel.app")!
    /// Path prefix for recap links; must match the AASA `components` pattern
    /// and the share-service rewrite.
    static let gamePathPrefix = "g"
}

struct SharePayload: Codable, Equatable {

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
    /// Hands in play order. Each hand is one score per player (n.count of
    /// them), with an optional trailing element: the moon shooter's player
    /// index. Still v1 — for 4-player games the encoding is byte-identical to
    /// pre-v1.4 links, and no older app build ever shipped publicly.
    var h: [[Int]]

    // MARK: - Build from a saved game

    init?(game: SavedGame) {
        guard let shareID = game.shareID else { return nil }
        self.id = shareID.uuidString.lowercased()
        self.d = Int(game.date.timeIntervalSince1970)
        self.z = TimeZone.current.secondsFromGMT(for: game.date) / 60
        self.n = game.playerNames
        self.s = game.finalScores
        self.w = game.winnerIndex
        let playerCount = game.playerNames.count
        self.h = (game.hands ?? [])
            .sorted { $0.handNumber < $1.handNumber }
            .map { hand in
                var arr = Array(hand.scores.prefix(playerCount))
                while arr.count < playerCount { arr.append(0) }
                if hand.isMoonShoot, let shooter = hand.moonShooterIndex {
                    arr.append(shooter)
                }
                return arr
            }
    }

    // MARK: - URL encoding

    /// base64url (RFC 4648 §5, unpadded) of the raw-DEFLATE-compressed JSON.
    func encodedString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let json = try? encoder.encode(self),
              let compressed = json.deflated() else { return nil }
        return compressed.base64EncodedString()
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
        guard let compressed = Data(base64Encoded: base64),
              let json = compressed.inflated(),
              let payload = try? JSONDecoder().decode(SharePayload.self, from: json),
              payload.v == 1,
              UUID(uuidString: payload.id) != nil,
              (3...6).contains(payload.n.count),
              payload.n.count == payload.s.count,
              payload.h.allSatisfy({ $0.count == payload.n.count || $0.count == payload.n.count + 1 })
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
        let playerCount = n.count
        for (i, arr) in h.enumerated() {
            let shooter = arr.count == playerCount + 1 ? arr[playerCount] : nil
            let savedHand = SavedHand(
                handNumber: i,
                scores: Array(arr.prefix(playerCount)),
                isMoonShoot: shooter != nil,
                moonShooterIndex: shooter,
                game: game
            )
            savedHands.append(savedHand)
        }
        game.hands = savedHands
        return game
    }
}

// MARK: - Raw DEFLATE helpers
// Apple's COMPRESSION_ZLIB is raw DEFLATE (RFC 1951, no zlib header/checksum),
// matching fflate's deflateSync/inflateSync on the web side.

private extension Data {
    func deflated() -> Data? {
        guard !isEmpty else { return nil }
        return withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data? in
            guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let capacity = count + 256
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
            defer { dst.deallocate() }
            let written = compression_encode_buffer(
                dst, capacity, srcPtr, count, nil, COMPRESSION_ZLIB
            )
            return written > 0 ? Data(bytes: dst, count: written) : nil
        }
    }

    func inflated(maxSize: Int = 1 << 16) -> Data? {
        guard !isEmpty else { return nil }
        return withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data? in
            guard let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: maxSize)
            defer { dst.deallocate() }
            let written = compression_decode_buffer(
                dst, maxSize, srcPtr, count, nil, COMPRESSION_ZLIB
            )
            return written > 0 ? Data(bytes: dst, count: written) : nil
        }
    }
}

// What's next:
// - share-service/lib/payload.ts mirrors this format (fflate inflateSync) —
//   the variable-count validation there must match this file exactly.
// - The deployed service only picks this up when main redeploys; 3/5/6-player
//   links shared before then hit the old validation and show the damaged-link
//   page (in-app open via Universal Link works regardless).
