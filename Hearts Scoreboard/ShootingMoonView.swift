//
//  ShootingMoonView.swift
//  Hearts Scoreboard
//
//  A crescent moon that shoots in a bezier arch across the top of the screen
//  leaving a glowing particle trail. Pure SwiftUI — no packages.
//
//  How it works:
//    • `progress` (0 → 1) is animated over `duration` seconds.
//    • The moon's position is computed from a quadratic bezier each frame.
//    • Trail dots are placed at slightly earlier t-values of the same curve,
//      giving a natural comet-tail effect without any Timer or Canvas complexity.
//

import SwiftUI

struct ShootingMoonView: View {
    var onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var opacity:  Double  = 1

    private let duration:   Double  = 1.9
    private let moonSize:   CGFloat = 30
    private let trailCount: Int     = 16

    // Bezier control points (in screen coordinates, ignoring safe area).
    // arcY   — vertical position of the start / end (sits in the header band).
    // peakY  — control point; negative means above the physical screen top,
    //           creating a crisp arch that dips briefly out of sight.
    private let arcY:  CGFloat = 130
    private let peakY: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Trail dots ──────────────────────────────────────────────
                ForEach(0..<trailCount) { i in
                    let t        = max(0, progress - CGFloat(i + 1) * 0.045)
                    let pos      = bezier(t: t, size: geo.size)
                    let fade     = Double(trailCount - i) / Double(trailCount)
                    let dotSize  = fade * 8 + 1

                    Circle()
                        .fill(Color(hex: "FFE55C").opacity(fade * 0.55))
                        .frame(width: dotSize, height: dotSize)
                        .blur(radius: 0.8)
                        .position(pos)
                }

                // ── Soft glow halo behind the moon ──────────────────────────
                let moonPos = bezier(t: progress, size: geo.size)

                Circle()
                    .fill(Color(hex: "FFE55C").opacity(0.22))
                    .frame(width: moonSize + 22, height: moonSize + 22)
                    .blur(radius: 12)
                    .position(moonPos)

                // ── Crescent moon ────────────────────────────────────────────
                //  `moon.fill` is already a crescent in SF Symbols.
                //  We rotate it to face the direction of travel along the arc.
                Image(systemName: "moon.fill")
                    .font(.system(size: moonSize, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FFF5A0"), Color(hex: "FFD700")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(tangentAngle(at: progress, size: geo.size)))
                    .shadow(color: Color(hex: "FFE55C").opacity(0.95), radius: 7)
                    .position(moonPos)
            }
        }
        .opacity(opacity)
        .ignoresSafeArea()
        .onAppear {
            // 1. Fly across the screen.
            withAnimation(.easeInOut(duration: duration)) {
                progress = 1.0
            }
            // 2. Fade out just after landing, then call back.
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
                withAnimation(.easeOut(duration: 0.28)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    onComplete()
                }
            }
        }
    }

    // MARK: - Bezier Math

    /// Position on the quadratic bezier at parameter t ∈ [0, 1].
    /// P0: left edge (off-screen), P1: control point (peaks above/at header top),
    /// P2: right edge (off-screen). Both endpoints sit at `arcY`.
    private func bezier(t: CGFloat, size: CGSize) -> CGPoint {
        let p0 = CGPoint(x: -55,               y: arcY)
        let p1 = CGPoint(x: size.width * 0.5,  y: peakY)
        let p2 = CGPoint(x: size.width + 55,   y: arcY)
        let u  = 1 - t
        return CGPoint(
            x: u*u*p0.x + 2*u*t*p1.x + t*t*p2.x,
            y: u*u*p0.y + 2*u*t*p1.y + t*t*p2.y
        )
    }

    /// Angle (degrees) of the bezier tangent at t — used to rotate the moon
    /// so it always faces its direction of travel.
    private func tangentAngle(at t: CGFloat, size: CGSize) -> Double {
        let p0 = CGPoint(x: -55,               y: arcY)
        let p1 = CGPoint(x: size.width * 0.5,  y: peakY)
        let p2 = CGPoint(x: size.width + 55,   y: arcY)
        let dx = 2*(1-t)*(p1.x - p0.x) + 2*t*(p2.x - p1.x)
        let dy = 2*(1-t)*(p1.y - p0.y) + 2*t*(p2.y - p1.y)
        // atan2 gives angle from +x axis; subtract 90° so the moon's
        // crescent tip points forward rather than sideways.
        return Double(atan2(dy, dx)) * 180.0 / Double.pi - 90.0
    }
}

#Preview {
    ZStack {
        feltGreen.ignoresSafeArea()
        // Fake header band so the preview looks like the real scoreboard.
        VStack {
            Color.black.opacity(0.30).frame(height: 90)
            Spacer()
        }
        ShootingMoonView { }
    }
}
