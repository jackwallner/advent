import CoreMotion
import SwiftUI

/// Continuous motion (snow, twinkle, flicker) is decoration. UI tests pass `-StillScene` to hold it still,
/// because XCUITest waits for the app to go idle and a scene that never rests makes every tap wait.
enum Motion {
    static let still = ProcessInfo.processInfo.arguments.contains("-StillScene")
}

/// Night sky: twinkling stars, a slow aurora and the moon in its real phase.
struct SkyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star { let x, y, r, phase, speed: Double }
    private static let stars: [Star] = {
        var r = SeededRandom(seed: 2412)
        return (0..<150).map { _ in Star(x: r.next(), y: r.next() * 0.75, r: 0.4 + r.next() * 1.1, phase: r.next() * 6.3, speed: 0.4 + r.next() * 1.6) }
    }()

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Theme.skyTop, location: 0), .init(color: Theme.skyMid, location: 0.38),
                    .init(color: Theme.skyLow, location: 0.72), .init(color: Theme.skyHorizon, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion || Motion.still)) { context in
                Canvas { ctx, size in
                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)
                    Self.aurora(&ctx, size, t)
                    Self.starfield(&ctx, size, t)
                    Self.moon(&ctx, size)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private static func aurora(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        var glow = ctx
        glow.blendMode = .screen
        glow.drawLayer { layer in
            layer.addFilter(.blur(radius: 14))
            let slices = 48
            let w = size.width * 1.2 / Double(slices)
            let sy = size.height * 0.7 / 60
            for i in 0..<slices {
                let x = Double(i) * 2
                let y0 = (4 + 7 * sin(x * 0.09 + t * 0.25) + 4 * sin(x * 0.23 - t * 0.17)) * sy
                let h = (26 + 10 * sin(x * 0.05 + t * 0.2 + 1)) * sy
                let a = max(0, 0.42 + 0.5 * sin(x * 0.17 + t * 0.4) * sin(x * 0.06 - t * 0.22) + 0.18 * sin(x * 0.5 + t))
                let rect = CGRect(x: -size.width * 0.1 + Double(i) * w, y: y0, width: w + 1, height: h)
                let gradient = Gradient(stops: [
                    .init(color: Color(red: 0.59, green: 0.35, blue: 1).opacity(0), location: 0),
                    .init(color: Color(red: 0.47, green: 0.47, blue: 1).opacity(a * 0.55), location: 0.45),
                    .init(color: Color(red: 0.27, green: 1, blue: 0.69).opacity(a), location: 0.86),
                    .init(color: Color(red: 0.27, green: 1, blue: 0.69).opacity(0), location: 1),
                ])
                layer.fill(Path(rect), with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: y0), endPoint: CGPoint(x: 0, y: y0 + h)))
            }
        }
    }

    private static func starfield(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        for s in stars {
            let alpha = (0.3 + 0.7 * (0.5 + 0.5 * sin(t * s.speed + s.phase))) * (1 - s.y * 0.7)
            let rect = CGRect(x: s.x * size.width - s.r, y: s.y * size.height - s.r, width: s.r * 2, height: s.r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
        }
    }

    /// 0 is a new moon, 0.5 a full one. Held away from new so there is always a moon to see.
    static func moonPhase(_ date: Date = Date()) -> Double {
        var p = ((date.timeIntervalSince1970 - 947_182_440) / 86_400 / 29.530588853).truncatingRemainder(dividingBy: 1)
        if p < 0 { p += 1 }
        return min(0.9, max(0.1, p))
    }

    private static func moon(_ ctx: inout GraphicsContext, _ size: CGSize) {
        var p = moonPhase()
        let waning = p > 0.5
        if waning { p = 1 - p }
        let r = 24.0
        let c = CGPoint(x: size.width * 0.8, y: max(size.height * 0.09, 86))
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - r * 2.6, y: c.y - r * 2.6, width: r * 5.2, height: r * 5.2)),
            with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF4C8).opacity(0.3), .clear]), center: c, startRadius: r * 0.8, endRadius: r * 2.6)
        )
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0x1C2750).opacity(0.55)))
        let rx = r * abs(cos(2 * .pi * p)) * (p < 0.25 ? 1 : -1)
        let flip = waning ? -1.0 : 1.0
        var lit = Path()
        let steps = 40
        for i in 0...steps {
            let a = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            let point = CGPoint(x: c.x + flip * r * cos(a), y: c.y + r * sin(a))
            if i == 0 { lit.move(to: point) } else { lit.addLine(to: point) }
        }
        for i in 0...steps {
            let a = Double.pi / 2 - Double.pi * Double(i) / Double(steps)
            lit.addLine(to: CGPoint(x: c.x + flip * rx * cos(a), y: c.y + r * sin(a)))
        }
        lit.closeSubpath()
        ctx.fill(lit, with: .radialGradient(
            Gradient(colors: [Color(hex: 0xFFFBE8), Color(hex: 0xE9DFB8)]),
            center: CGPoint(x: c.x - r * 0.2, y: c.y - r * 0.2), startRadius: 0, endRadius: r * 1.4
        ))
    }
}

/// Snow that keeps its own state, so a gust or a tilt of the phone can push it around.
final class SnowModel: @unchecked Sendable {
    struct Flake { var x, y, z, r, v, phase: Double }

    private(set) var flakes: [Flake] = []
    private var wind = 0.0
    private var tilt = 0.0
    private var last = 0.0
    private var size = CGSize.zero
    private var motion: CMMotionManager?

    func gust(from x: Double, width: Double) { wind += (x < width / 2 ? 1 : -1) * 420 }

    func startTilt() {
        guard motion == nil else { return }
        let m = CMMotionManager()
        guard m.isDeviceMotionAvailable else { return }
        m.deviceMotionUpdateInterval = 1 / 20
        m.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let x = data?.gravity.x else { return }
            self?.tilt = x
        }
        motion = m
    }

    func stopTilt() {
        motion?.stopDeviceMotionUpdates()
        motion = nil
        tilt = 0
    }

    private func make(anywhere: Bool) -> Flake {
        let z = Double.random(in: 0...1)
        return Flake(
            x: .random(in: 0...max(size.width, 1)), y: anywhere ? .random(in: 0...max(size.height, 1)) : -8,
            z: z, r: 0.7 + z * z * 3.2, v: 14 + z * 46, phase: .random(in: 0...6.3)
        )
    }

    func step(to t: Double, in newSize: CGSize) {
        if newSize != size {
            size = newSize
            let count = Int(min(size.width * size.height / 7000, 170))
            flakes = (0..<count).map { _ in make(anywhere: true) }
        }
        let dt = min(0.05, max(0, t - last))
        last = t
        wind *= pow(0.25, dt)
        let push = wind + tilt * 160
        for i in flakes.indices {
            flakes[i].y += flakes[i].v * dt
            flakes[i].x += (sin(t * 0.8 + flakes[i].phase) * 10 + push * (0.4 + flakes[i].z)) * dt
            if flakes[i].y > size.height + 8 { flakes[i] = make(anywhere: false) }
            if flakes[i].x < -10 { flakes[i].x = size.width + 10 } else if flakes[i].x > size.width + 10 { flakes[i].x = -10 }
        }
    }
}

struct SnowView: View {
    let model: SnowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || Motion.still)) { context in
            Canvas { ctx, size in
                model.step(to: context.date.timeIntervalSinceReferenceDate, in: size)
                for f in model.flakes {
                    let rect = CGRect(x: f.x - f.r, y: f.y - f.r, width: f.r * 2, height: f.r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.35 + f.z * 0.55)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { if !reduceMotion, !Motion.still { model.startTilt() } }
        .onDisappear { model.stopTilt() }
    }
}

/// Sky with snow over it, for screens that have no house. A tap sends a gust through the snow.
struct NightBackground: View {
    @State private var snow = SnowModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SkyView()
                    .contentShape(Rectangle())
                    .onTapGesture { point in snow.gust(from: point.x, width: geo.size.width) }
                SnowView(model: snow)
            }
        }
        .ignoresSafeArea()
    }
}

/// A snowy rise with a gently curved top.
struct GroundShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 34))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 34), control: CGPoint(x: rect.midX, y: rect.minY - 34))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
