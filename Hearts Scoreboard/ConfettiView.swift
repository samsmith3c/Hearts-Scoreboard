//
//  ConfettiView.swift
//  Hearts Scoreboard
//
//  Pure SwiftUI confetti — no third-party packages.
//  Each piece is pre-seeded with random size/speed/drift so values stay
//  stable across redraws, then animated with repeatForever once on appear.
//

import SwiftUI

// MARK: - Particle data (generated once on appear)

private struct ConfettiParticle: Identifiable {
    let id: Int
    let startX: CGFloat
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let delay: Double
    let duration: Double
    let driftX: CGFloat
    let finalRotation: Double
}

// MARK: - Container view

struct ConfettiView: View {
    private static let palette: [Color] = [
        .red, .orange, .yellow,
        Color(hex: "FFD700"),   // gold
        Color(hex: "FF69B4"),   // hot pink
        .blue, .purple, .cyan, .white,
        Color(hex: "00E5FF"),   // electric blue
    ]

    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    FallingPiece(particle: p, screenHeight: geo.size.height)
                }
            }
            .onAppear {
                guard particles.isEmpty else { return }
                particles = (0..<90).map { i in
                    ConfettiParticle(
                        id: i,
                        startX: CGFloat.random(in: 0...geo.size.width),
                        color: Self.palette[i % Self.palette.count],
                        width: CGFloat.random(in: 7...15),
                        height: CGFloat.random(in: 4...9),
                        delay: Double.random(in: 0...2.2),
                        duration: Double.random(in: 2.4...4.2),
                        driftX: CGFloat.random(in: -90...90),
                        finalRotation: Double.random(in: 180...720)
                    )
                }
            }
        }
    }
}

// MARK: - Individual falling piece

private struct FallingPiece: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat

    @State private var y: CGFloat = -20
    @State private var x: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.width, height: particle.height)
            .rotationEffect(.degrees(rotation))
            .position(x: particle.startX + x, y: y)
            .onAppear {
                withAnimation(
                    .easeIn(duration: particle.duration)
                    .delay(particle.delay)
                    .repeatForever(autoreverses: false)
                ) {
                    y = screenHeight + 30
                    x = particle.driftX
                    rotation = particle.finalRotation
                }
            }
    }
}

#Preview {
    ZStack {
        feltGreen.ignoresSafeArea()
        ConfettiView()
    }
}
