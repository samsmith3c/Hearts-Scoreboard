//
//  StatsViewModel.swift
//  Hearts Scoreboard
//

import Foundation

// MARK: - Per-player aggregated stats

struct PlayerStats: Identifiable {
    let id: String          // identity key — "gc:<playerID>" or "name:<lowercased>"
    let name: String
    let gcPlayerID: String?

    // Lifetime totals
    let gamesPlayed: Int
    let totalPoints: Int
    let moonShootCount: Int
    let mostMoonsInSingleGame: Int
    let timesFinishedLast: Int

    // Scoring
    let lowestSingleGameScore: Int?
    let averageScorePerGame: Double?
    let averageScorePerHand: Double?

    // Win / Loss
    let wins: Int
    let losses: Int
    var winPercentage: Double? {
        gamesPlayed > 0 ? Double(wins) / Double(gamesPlayed) * 100 : nil
    }

    // Streaks
    let currentStreakIsWin: Bool
    let currentStreakCount: Int
    let longestWinStreak: Int
    let longestLosingStreak: Int
}

// MARK: - Computation engine

struct StatsViewModel {

    func computeStats(games: [SavedGame]) -> [PlayerStats] {
        guard !games.isEmpty else { return [] }

        let sorted = games.sorted { $0.date < $1.date }
        var accumulators: [String: PlayerAccumulator] = [:]

        for game in sorted {
            guard !game.finalScores.isEmpty, !game.playerNames.isEmpty else { continue }
            let count = min(game.playerNames.count, game.finalScores.count)

            let maxScore = game.finalScores.prefix(count).max() ?? 0
            let moonsPerPlayer = moonCounts(in: game)
            let totalHands = game.hands.count

            for i in 0..<count {
                let key = identityKey(for: i, in: game)
                if accumulators[key] == nil {
                    accumulators[key] = PlayerAccumulator(
                        id: key,
                        name: game.playerNames[i],
                        gcPlayerID: gcID(for: i, in: game)
                    )
                }
                accumulators[key]!.addGame(
                    score: game.finalScores[i],
                    won: i == game.winnerIndex,
                    finishedLast: game.finalScores[i] == maxScore,
                    moonsInGame: moonsPerPlayer[i] ?? 0,
                    totalHands: totalHands
                )
            }
        }

        return accumulators.values.map { $0.toStats() }.sorted { $0.name < $1.name }
    }

    // MARK: - Identity helpers

    private func identityKey(for index: Int, in game: SavedGame) -> String {
        if let selfIdx = game.selfPlayerIndex, selfIdx == index,
           let gcPlayerID = game.gameCenterPlayerID {
            return "gc:\(gcPlayerID)"
        }
        return "name:\(game.playerNames[index].lowercased())"
    }

    private func gcID(for index: Int, in game: SavedGame) -> String? {
        guard let selfIdx = game.selfPlayerIndex, selfIdx == index else { return nil }
        return game.gameCenterPlayerID
    }

    private func moonCounts(in game: SavedGame) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        for hand in game.hands where hand.isMoonShoot {
            if let idx = hand.moonShooterIndex {
                counts[idx, default: 0] += 1
            }
        }
        return counts
    }
}

// MARK: - Mutable accumulator (private)

private class PlayerAccumulator {
    let id: String
    let name: String
    let gcPlayerID: String?

    var gamesPlayed = 0
    var totalPoints = 0
    var wins = 0
    var losses = 0
    var timesFinishedLast = 0
    var moonShootCount = 0
    var mostMoonsInSingleGame = 0
    var lowestSingleGameScore: Int? = nil
    var totalHandsPlayed = 0
    var gameResults: [Bool] = []    // true = win, oldest first

    init(id: String, name: String, gcPlayerID: String?) {
        self.id = id
        self.name = name
        self.gcPlayerID = gcPlayerID
    }

    func addGame(score: Int, won: Bool, finishedLast: Bool, moonsInGame: Int, totalHands: Int) {
        gamesPlayed += 1
        totalPoints += score
        won ? (wins += 1) : (losses += 1)
        if finishedLast { timesFinishedLast += 1 }
        moonShootCount += moonsInGame
        mostMoonsInSingleGame = max(mostMoonsInSingleGame, moonsInGame)
        lowestSingleGameScore = lowestSingleGameScore.map { min($0, score) } ?? score
        totalHandsPlayed += totalHands
        gameResults.append(won)
    }

    func toStats() -> PlayerStats {
        let avgPerGame: Double? = gamesPlayed > 0 ? Double(totalPoints) / Double(gamesPlayed) : nil
        let avgPerHand: Double? = totalHandsPlayed > 0 ? Double(totalPoints) / Double(totalHandsPlayed) : nil

        // Longest streaks
        var longestWin = 0, longestLoss = 0
        var runWin = 0, runLoss = 0
        for result in gameResults {
            if result { runWin += 1; runLoss = 0 } else { runLoss += 1; runWin = 0 }
            longestWin  = max(longestWin,  runWin)
            longestLoss = max(longestLoss, runLoss)
        }

        // Current streak — walk backwards until the result changes
        var currentCount = 0
        let currentIsWin = gameResults.last ?? false
        for result in gameResults.reversed() {
            guard result == currentIsWin else { break }
            currentCount += 1
        }

        return PlayerStats(
            id: id,
            name: name,
            gcPlayerID: gcPlayerID,
            gamesPlayed: gamesPlayed,
            totalPoints: totalPoints,
            moonShootCount: moonShootCount,
            mostMoonsInSingleGame: mostMoonsInSingleGame,
            timesFinishedLast: timesFinishedLast,
            lowestSingleGameScore: lowestSingleGameScore,
            averageScorePerGame: avgPerGame,
            averageScorePerHand: avgPerHand,
            wins: wins,
            losses: losses,
            currentStreakIsWin: currentIsWin,
            currentStreakCount: currentCount,
            longestWinStreak: longestWin,
            longestLosingStreak: longestLoss
        )
    }
}
