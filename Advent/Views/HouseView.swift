import SwiftUI

/// The house front in a 400 by 720 design space, matching `slot` in docs/scene.js.
enum HouseGeometry {
    enum Kind { case round, arch, rect, door }

    static let size = CGSize(width: 400, height: 720)

    static func slot(_ i: Int) -> (rect: CGRect, kind: Kind) {
        if i == 0 { return (CGRect(x: 177, y: 92, width: 46, height: 46), .round) }
        if i <= 20 {
            let row = (i - 1) / 4, col = (i - 1) % 4
            return (CGRect(x: 60 + col * 78, y: 176 + row * 80, width: 46, height: 58), row % 2 == 1 ? .rect : .arch)
        }
        if i == CalendarBuilder.frontDoor { return (CGRect(x: 161, y: 586, width: 78, height: 92), .door) }
        return (CGRect(x: i == 21 ? 60 : 294, y: 596, width: 46, height: 60), .arch)
    }

    /// Corner radii (top, bottom) of a window of this kind.
    static func radii(_ kind: Kind) -> (top: CGFloat, bottom: CGFloat) {
        switch kind {
        case .round: (23, 23)
        case .arch: (23, 3)
        case .rect: (3, 3)
        case .door: (39, 0)
        }
    }
}

/// The house with its 24 shuttered windows. Fits itself to the space it is given, standing on the bottom edge.
struct HouseView: View {
    let style: HouseStyle
    let seed: UInt32
    let days: [String]
    let unlocked: Int
    let opened: Set<Int>
    let item: (String) -> Item?
    var hasNote = false
    /// Day tapped and where its window is on screen.
    let onTap: (Int, CGPoint) -> Void
    var onNote: (CGPoint) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let k = min(geo.size.width / 400, geo.size.height / 720, 1.35)
            let frame = geo.frame(in: .global)
            let global = { (p: CGPoint) in CGPoint(x: frame.midX + (p.x - 200) * k, y: frame.maxY - (720 - p.y) * k) }
            ZStack(alignment: .topLeading) {
                GroundShape()
                    .fill(LinearGradient(colors: [Color(hex: 0xF6F9FF), Color(hex: 0xD3DEF5), Color(hex: 0xB9C8EA)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: 0xAAC3FF).opacity(0.28), radius: 20, y: -8)
                    .frame(width: 2400, height: 700)
                    .position(x: 200, y: 676 + 350)
                    .allowsHitTesting(false)
                HouseBackdrop(style: style)
                    .frame(width: 480, height: 720)
                    .position(x: 200, y: 360)
                    .allowsHitTesting(false)
                HouseLights(lit: !opened.isEmpty, star: opened.contains(24))
                    .frame(width: 480, height: 720)
                    .position(x: 200, y: 360)
                    .allowsHitTesting(false)
                ForEach(Array(CalendarBuilder.layout(seed: seed).enumerated()), id: \.element) { i, day in
                    let g = HouseGeometry.slot(i)
                    WindowView(
                        day: day, kind: g.kind, style: style,
                        item: days.indices.contains(day - 1) ? item(days[day - 1]) : nil,
                        isOpen: opened.contains(day), canOpen: day <= unlocked,
                        isToday: day == unlocked && !opened.contains(day),
                        onTap: { onTap(day, global(CGPoint(x: g.rect.midX, y: g.rect.midY))) }
                    )
                    .frame(width: g.rect.width, height: g.rect.height)
                    .position(x: g.rect.midX, y: g.rect.midY)
                }
                if hasNote {
                    LetterButton { onNote(global(CGPoint(x: 49, y: 668))) }
                        .position(x: 49, y: 668)
                }
            }
            .frame(width: 400, height: 720)
            .scaleEffect(k, anchor: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// Everything about the house that never moves. Drawn 40 points in from the left so the tree and snowman fit.
private struct HouseBackdrop: View {
    let style: HouseStyle

    var body: some View {
        Canvas { ctx, _ in
            ctx.translateBy(x: 40, y: 0)
            func poly(_ pts: [(Double, Double)]) -> Path {
                var p = Path()
                p.addLines(pts.map { CGPoint(x: $0.0, y: $0.1) })
                p.closeSubpath()
                return p
            }
            func line(_ pts: [(Double, Double)]) -> Path {
                var p = Path()
                p.addLines(pts.map { CGPoint(x: $0.0, y: $0.1) })
                return p
            }
            func circle(_ x: Double, _ y: Double, _ r: Double) -> Path { Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)) }
            let dark = Color(hex: 0x141A33)
            let round = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)

            ctx.fill(Path(ellipseIn: CGRect(x: -5, y: 671, width: 410, height: 26)), with: .color(Color(hex: 0x3B4F8A).opacity(0.3)))

            // Pine tree
            ctx.fill(poly([(14, 598), (36, 636), (-8, 636)]), with: .color(Color(hex: 0x1C4A3A)))
            ctx.fill(poly([(14, 620), (41, 662), (-13, 662)]), with: .color(Color(hex: 0x173F31)))
            ctx.fill(poly([(14, 646), (45, 690), (-17, 690)]), with: .color(Color(hex: 0x12362A)))
            ctx.fill(poly([(14, 598), (22, 612), (14, 609), (6, 612)]), with: .color(.white))
            ctx.fill(poly([(14, 620), (25, 637), (14, 633), (3, 637)]), with: .color(.white.opacity(0.95)))
            ctx.fill(poly([(14, 646), (27, 664), (14, 660), (1, 664)]), with: .color(.white.opacity(0.95)))

            // Chimney
            let chimney = CGRect(x: 276, y: 66, width: 28, height: 60)
            ctx.fill(Path(chimney), with: .color(style.wall))
            for y in stride(from: 66.0, to: 126, by: 9) {
                ctx.fill(Path(CGRect(x: 276, y: y, width: 28, height: 1.2)), with: .color(.black.opacity(0.16)))
            }
            ctx.fill(Path(roundedRect: CGRect(x: 271, y: 58, width: 38, height: 11), cornerRadius: 5.5), with: .color(.white))

            // Wall
            let wall = poly([(44, 682), (44, 160), (200, 56), (356, 160), (356, 682)])
            ctx.fill(wall, with: .linearGradient(Gradient(colors: [style.wall, style.wall2]), startPoint: CGPoint(x: 44, y: 56), endPoint: CGPoint(x: 356, y: 682)))
            ctx.drawLayer { layer in
                layer.clip(to: wall)
                for y in stride(from: 56.0, to: 682, by: 9) {
                    layer.fill(Path(CGRect(x: 44, y: y, width: 312, height: 1.2)), with: .color(.black.opacity(0.16)))
                    layer.fill(Path(CGRect(x: 44, y: y + 1.2, width: 312, height: 1)), with: .color(.white.opacity(0.05)))
                }
                layer.fill(Path(CGRect(x: 44, y: 56, width: 312, height: 626)), with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(0.28)]), center: CGPoint(x: 200, y: 682), startRadius: 0, endRadius: 560
                ))
            }

            // Roof and the snow on it
            var edge = round
            edge.lineWidth = 17
            ctx.stroke(line([(22, 172), (200, 52), (378, 172)]), with: .color(style.roof), style: edge)
            ctx.stroke(line([(22, 166), (200, 46), (378, 166)]), with: .color(.white), style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round, dash: [11, 13]))
            edge.lineWidth = 12
            ctx.stroke(line([(20, 163), (200, 42), (380, 163)]), with: .color(.white), style: edge)

            // Wire for the lights
            var wire = Path()
            wire.move(to: CGPoint(x: 40, y: HouseLights.roofY(40) + 16))
            for bulb in HouseLights.bulbs { wire.addLine(to: CGPoint(x: bulb.x, y: bulb.y - 2.5)) }
            ctx.stroke(wire, with: .color(Color(hex: 0x0A0F22).opacity(0.7)), lineWidth: 1)

            // Stoop and drifts
            ctx.fill(Path(roundedRect: CGRect(x: 150, y: 676, width: 100, height: 10), cornerRadius: 3), with: .color(Color(hex: 0xCFD6EA)))
            ctx.fill(Path(roundedRect: CGRect(x: 146, y: 672, width: 108, height: 7), cornerRadius: 3.5), with: .color(.white))
            var drift = Path()
            drift.move(to: CGPoint(x: 36, y: 688))
            drift.addCurve(to: CGPoint(x: 66, y: 685), control1: CGPoint(x: 44, y: 676), control2: CGPoint(x: 58, y: 676))
            drift.addCurve(to: CGPoint(x: 96, y: 688), control1: CGPoint(x: 75, y: 676), control2: CGPoint(x: 90, y: 677))
            drift.closeSubpath()
            drift.move(to: CGPoint(x: 300, y: 688))
            drift.addCurve(to: CGPoint(x: 330, y: 685), control1: CGPoint(x: 308, y: 677), control2: CGPoint(x: 322, y: 677))
            drift.addCurve(to: CGPoint(x: 364, y: 688), control1: CGPoint(x: 339, y: 677), control2: CGPoint(x: 356, y: 678))
            drift.closeSubpath()
            ctx.fill(drift, with: .color(.white))

            // Snowman
            ctx.translateBy(x: -7, y: 0)
            ctx.fill(circle(384, 668, 17), with: .color(.white))
            ctx.fill(circle(384, 644, 12), with: .color(.white))
            ctx.fill(circle(384, 626, 9), with: .color(.white))
            ctx.fill(Path(roundedRect: CGRect(x: 373, y: 633.5, width: 22, height: 5.5), cornerRadius: 2.5), with: .color(style.shutter))
            ctx.fill(poly([(391, 638), (396, 651), (391, 650)]), with: .color(style.shutter))
            ctx.fill(Path(roundedRect: CGRect(x: 376, y: 608, width: 16, height: 11), cornerRadius: 1.5), with: .color(dark))
            ctx.fill(Path(roundedRect: CGRect(x: 372, y: 617, width: 24, height: 3), cornerRadius: 1.5), with: .color(dark))
            ctx.fill(circle(381, 624, 1.1), with: .color(dark))
            ctx.fill(circle(387, 624, 1.1), with: .color(dark))
            ctx.fill(poly([(384, 627), (375, 629), (384, 630.4)]), with: .color(Color(hex: 0xF08A2C)))
            ctx.fill(circle(384, 643, 1.2), with: .color(dark))
            ctx.fill(circle(384, 650, 1.2), with: .color(dark))
        }
        .accessibilityHidden(true)
    }
}

/// The parts that move: twinkling string lights, chimney smoke once someone is home, and the star on Christmas Eve.
private struct HouseLights: View {
    let lit: Bool
    let star: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func roofY(_ x: Double) -> Double { 52 + 0.674 * abs(x - 200) }

    static let bulbs: [CGPoint] = stride(from: 52.0, through: 348, by: 14.8).enumerated().map { i, x in
        CGPoint(x: x, y: roofY(x) + 19.5 + (i % 2 == 1 ? 1.5 : 0))
    }
    private static let colors = [Color(hex: 0xFF6B6B), Color(hex: 0xFFD166), Color(hex: 0x6BD5FF), Color(hex: 0x8BE28B)]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion || Motion.still)) { context in
            Canvas { ctx, _ in
                ctx.translateBy(x: 40, y: 0)
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000)
                if lit {
                    for i in 0..<3 {
                        let u = (t / 4.8 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                        let alpha = u < 0.15 ? u / 0.15 * 0.42 : 0.42 * (1 - (u - 0.15) / 0.85)
                        let r = 7 * (0.5 + 1.6 * u)
                        ctx.fill(Path(ellipseIn: CGRect(x: 290 - 26 * u - r, y: 54 - 70 * u - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xDFE6FF).opacity(alpha)))
                    }
                }
                for (i, bulb) in Self.bulbs.enumerated() {
                    let alpha = 0.675 + 0.325 * cos(2 * .pi * (t + Double(i) * 0.37) / 2.2)
                    let color = Self.colors[i % 4]
                    ctx.fill(Path(ellipseIn: CGRect(x: bulb.x - 6, y: bulb.y - 6, width: 12, height: 12)), with: .radialGradient(
                        Gradient(colors: [color.opacity(alpha * 0.55), color.opacity(0)]), center: bulb, startRadius: 1, endRadius: 6
                    ))
                    ctx.fill(Path(ellipseIn: CGRect(x: bulb.x - 3.1, y: bulb.y - 3.1, width: 6.2, height: 6.2)), with: .color(color.opacity(alpha)))
                }
                if star {
                    let c = CGPoint(x: 200, y: 24)
                    let pulse = 0.5 + 0.12 * sin(t * 2.6)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 34, y: c.y - 34, width: 68, height: 68)), with: .radialGradient(
                        Gradient(colors: [Color(hex: 0xFFD978).opacity(pulse), .clear]), center: c, startRadius: 4, endRadius: 34
                    ))
                    var p = Path()
                    for i in 0..<10 {
                        let a = -Double.pi / 2 + Double(i) * .pi / 5
                        let r = i % 2 == 0 ? 20.0 : 8.6
                        let point = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
                        if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
                    }
                    p.closeSubpath()
                    ctx.fill(p, with: .color(Color(hex: 0xFFE08A)))
                    ctx.stroke(p, with: .color(Color(hex: 0xFFF3C9)), lineWidth: 1)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// One window, or the front door. Shutters cover it until its day; behind them the room is lit.
struct WindowView: View {
    let day: Int
    let kind: HouseGeometry.Kind
    let style: HouseStyle
    let item: Item?
    let isOpen: Bool
    let canOpen: Bool
    let isToday: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes: CGFloat = 0
    @State private var breathe = false
    @State private var flicker = false

    private var ready: Bool { canOpen && !isOpen }
    private var radii: (top: CGFloat, bottom: CGFloat) { HouseGeometry.radii(kind) }

    private func outline(grow: CGFloat = 0) -> UnevenRoundedRectangle {
        let r = radii
        return UnevenRoundedRectangle(
            topLeadingRadius: r.top + grow, bottomLeadingRadius: r.bottom + (r.bottom > 0 ? grow : 0),
            bottomTrailingRadius: r.bottom + (r.bottom > 0 ? grow : 0), topTrailingRadius: r.top + grow
        )
    }

    var body: some View {
        ZStack {
            glow
            outline(grow: 3).fill(style.trim).padding(-3)
                .shadow(color: .black.opacity(0.22), radius: 0, y: 3)
            glass
            shutter(left: true)
            shutter(left: false)
            if ready {
                Capsule().fill(Color(hex: 0xFFE2A0))
                    .frame(width: 1.5)
                    .padding(.vertical, kind == .round ? 2 : 5)
                    .shadow(color: Color(hex: 0xFFC35E), radius: 3.5)
            }
            number
            if kind == .arch || kind == .rect { sill }
            if isToday { candle }
        }
        .modifier(ShakeEffect(animatableData: shakes))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.85), value: isOpen)
        .contentShape(Rectangle().inset(by: -6))
        .onTapGesture {
            if !canOpen { withAnimation(.linear(duration: 0.4)) { shakes += 1 } }
            onTap()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("door-\(day)")
        .onAppear {
            guard isToday, !reduceMotion, !Motion.still else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathe = true }
            withAnimation(.easeInOut(duration: 0.22).repeatForever(autoreverses: true)) { flicker = true }
        }
    }

    private var label: String {
        if isOpen, let item { return "Day \(day), \(item.title)" }
        return canOpen ? "Open day \(day)" : "Day \(day), opens December \(day)"
    }

    private var glow: some View {
        Ellipse()
            .fill(RadialGradient(colors: [Color(hex: 0xFFC864).opacity(0.85), Color(hex: 0xFFAA3C).opacity(0)], center: .center, startRadius: 0, endRadius: 46))
            .padding(-16)
            .blur(radius: 5)
            .opacity(isOpen ? 1 : ready ? (isToday ? (breathe ? 0.85 : 0.45) : 0.38) : 0)
    }

    private var glass: some View {
        GeometryReader { geo in
            let split = kind == .round ? 0.5 : 0.32
            ZStack(alignment: .top) {
                if canOpen {
                    RadialGradient(
                        colors: [Color(hex: 0xFFF3C4), Color(hex: 0xFFCA6C), Color(hex: 0xE3902B)],
                        center: UnitPoint(x: 0.5, y: 0.64), startRadius: 0, endRadius: geo.size.height * 0.62
                    )
                } else {
                    Color(hex: 0x0A0F24)
                }
                if isOpen, let item {
                    if kind != .round {
                        Text("\(day)")
                            .font(Theme.serif(kind == .door ? 13 : 11))
                            .foregroundStyle(Color(hex: 0x7A3D12))
                            .frame(height: geo.size.height * split)
                    }
                    Image(systemName: item.category.symbol)
                        .font(.system(size: kind == .door ? 27 : 19, weight: .semibold))
                        .foregroundStyle(Theme.silhouette.opacity(0.92))
                        .position(x: geo.size.width / 2, y: geo.size.height * (kind == .round ? 0.5 : 0.66))
                }
                if kind != .round || !isOpen {
                    Rectangle().fill(style.trim).frame(height: 2).offset(y: geo.size.height * split)
                }
            }
        }
        .clipShape(outline())
    }

    private func shutter(left: Bool) -> some View {
        let r = radii
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: left ? r.top : 0, bottomLeadingRadius: left ? min(r.bottom, 23) : 0,
            bottomTrailingRadius: left ? 0 : min(r.bottom, 23), topTrailingRadius: left ? 0 : r.top
        )
        return GeometryReader { geo in
            shape
                .fill(LinearGradient(colors: [style.shutter, style.shutter2], startPoint: .top, endPoint: .bottom))
                .overlay {
                    if kind == .door {
                        RoundedRectangle(cornerRadius: 2).strokeBorder(.black.opacity(0.22), lineWidth: 1.5)
                            .padding(EdgeInsets(top: 38, leading: 7, bottom: 8, trailing: 7))
                        Circle().fill(Theme.goldLight).frame(width: 5, height: 5)
                            .shadow(color: .black.opacity(0.4), radius: 0, y: 1)
                            .position(x: left ? geo.size.width / 2 - 6.5 : 6.5, y: geo.size.height * 0.64)
                    } else {
                        Louvers().stroke(.black.opacity(0.2), lineWidth: 1.5)
                            .padding(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                            .clipShape(shape)
                    }
                }
                .overlay(shape.strokeBorder(.black.opacity(0.25), lineWidth: 1.5))
                .frame(width: geo.size.width / 2 + 0.25)
                .brightness(isOpen ? -0.2 : canOpen ? 0 : -0.1)
                .saturation(canOpen ? 1 : 0.85)
                .rotation3DEffect(.degrees(isOpen ? (left ? -114 : 114) : 0), axis: (x: 0, y: 1, z: 0), anchor: left ? .leading : .trailing, perspective: 0.7)
                .frame(maxWidth: .infinity, alignment: left ? .leading : .trailing)
        }
    }

    private var number: some View {
        VStack(spacing: 1) {
            if kind == .door { Wreath().frame(width: 38, height: 38) }
            Text("\(day)")
                .font(Theme.serif(kind == .door ? 24 : 21))
                .foregroundStyle(style.number)
                .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
        }
        .frame(maxHeight: .infinity, alignment: kind == .door ? .top : .center)
        .padding(.top, kind == .door ? 9 : 0)
        .opacity(isOpen ? 0 : canOpen ? 1 : 0.62)
    }

    private var sill: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 2).fill(style.trim)
                .shadow(color: .black.opacity(0.25), radius: 0, y: 2)
                .frame(width: geo.size.width + 14, height: 6)
                .position(x: geo.size.width / 2, y: geo.size.height + 7)
            Capsule().fill(.white)
                .frame(width: geo.size.width + 16, height: 7)
                .position(x: geo.size.width / 2, y: geo.size.height + 2.5)
        }
    }

    private var candle: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [Color(hex: 0xFFF8E6), Color(hex: 0xE8D9B8)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 5, height: 12)
                .position(x: geo.size.width / 2, y: geo.size.height - 1)
            Ellipse()
                .fill(RadialGradient(colors: [.white, Color(hex: 0xFFD76E), Color(hex: 0xFF8A2A), Color(hex: 0xFF8A2A).opacity(0)], center: UnitPoint(x: 0.5, y: 0.72), startRadius: 0, endRadius: 7))
                .frame(width: 8, height: 12)
                .scaleEffect(x: flicker ? 0.9 : 1, y: flicker ? 1.12 : 1, anchor: .bottom)
                .shadow(color: Color(hex: 0xFFBE50).opacity(0.95), radius: 6)
                .position(x: geo.size.width / 2, y: geo.size.height - 13)
        }
    }
}

private struct Louvers: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for y in stride(from: rect.minY + 0.75, to: rect.maxY, by: 5) {
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

private struct Wreath: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 40, y: size.height / 40)
            let ring = Path(ellipseIn: CGRect(x: 9, y: 7, width: 22, height: 22))
            ctx.stroke(ring, with: .color(Color(hex: 0x1D5A3D)), lineWidth: 7.5)
            ctx.stroke(ring, with: .color(Color(hex: 0x3B8F63)), style: StrokeStyle(lineWidth: 7.5, dash: [2.5, 5]))
            let red = Color(hex: 0xE5384D)
            for (x, y) in [(12.0, 11.0), (29, 14), (14, 27)] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1.7, y: y - 1.7, width: 3.4, height: 3.4)), with: .color(red))
            }
            var bow = Path()
            bow.addLines([CGPoint(x: 20, y: 27), CGPoint(x: 13, y: 35), CGPoint(x: 20, y: 32), CGPoint(x: 27, y: 35)])
            bow.closeSubpath()
            ctx.fill(bow, with: .color(Color(hex: 0xD42D43)))
            ctx.fill(Path(ellipseIn: CGRect(x: 17.3, y: 24.8, width: 5.4, height: 5.4)), with: .color(red))
        }
    }
}

/// The note that came with a gift, waiting in the snow by the door.
private struct LetterButton: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFFAF0), Color(hex: 0xF1E3C8)], startPoint: .top, endPoint: .bottom))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: 23, y: 18))
                    p.addLine(to: CGPoint(x: 46, y: 0))
                }
                .stroke(Color(hex: 0xD9C8A6), lineWidth: 1)
                Circle().fill(Theme.berry).frame(width: 11, height: 11).offset(y: 2)
            }
            .frame(width: 46, height: 32)
            .shadow(color: Color(hex: 0x141E46).opacity(0.35), radius: 4, y: 3)
            .rotationEffect(.degrees(up ? -6 : -9))
            .offset(y: up ? -3 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Note")
        .accessibilityIdentifier("letter")
        .onAppear {
            guard !reduceMotion, !Motion.still else { return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { up = true }
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 4 * sin(animatableData * .pi * 4), y: 0))
    }
}
