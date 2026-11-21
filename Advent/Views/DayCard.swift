import SwiftUI

/// What is behind a door. A door opened for the first time is frosted over until it is wiped clear.
struct DayCard: View {
    let day: Int
    let item: Item
    let rating: Int
    let fresh: Bool
    let onRate: (Int) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var stars = 0
    @State private var frosted = false
    @State private var burst = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: item.category.symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Theme.silhouette)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFFE9AE), Color(hex: 0xE9B14C)], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: 40))
                        .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 2))
                        .shadow(color: Theme.gold.opacity(0.4), radius: 8, y: 6)
                )
                .accessibilityHidden(true)

            Text("Day \(day) \u{00B7} \(item.category.name)")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundStyle(Theme.berry)
                .padding(.top, 18)

            Text(item.title)
                .font(Theme.serif(28))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .accessibilityIdentifier("day-title")

            Text(item.detail)
                .font(.system(size: 17))
                .lineSpacing(3)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if let reveal = item.reveal {
                Group {
                    if revealed {
                        Text(reveal)
                            .font(Theme.serif(19, .regular)).italic()
                            .foregroundStyle(Theme.pine)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    } else {
                        Button(item.category == .humor ? "Punchline" : "Answer") {
                            withAnimation(.easeOut(duration: 0.2)) { revealed = true }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.pine)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.pine.opacity(0.1)))
                        .accessibilityIdentifier("reveal")
                    }
                }
                .padding(.top, 14)
            }

            Divider().overlay(Theme.line).padding(.top, 22).padding(.bottom, 16)
            rate
        }
        .padding(EdgeInsets(top: 30, leading: 24, bottom: 24, trailing: 24))
        .frame(maxWidth: 400, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0xFFFAF0), Color(hex: 0xF6ECD8)], startPoint: .top, endPoint: .bottom))
        .accessibilityHidden(frosted)
        .overlay {
            if frosted {
                FrostView(day: day) { withAnimation(.easeOut(duration: 0.75)) { frosted = false } }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(frosted ? .white.opacity(0.6) : Theme.ink.opacity(0.07)))
            }
            .accessibilityLabel("Close")
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.goldLight.opacity(0.7), lineWidth: 1))
        .shadow(color: Color(hex: 0xFFBE5A).opacity(0.35), radius: 40)
        .shadow(color: .black.opacity(0.55), radius: 30, y: 24)
        .environment(\.colorScheme, .light)
        .onAppear {
            stars = rating
            frosted = fresh && !reduceMotion
        }
    }

    private var rate: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    stars = n
                    onRate(n)
                    Bells.shared.star(n)
                    if n == 5 { burst += 1 }
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(n <= stars ? Theme.gold : Color(hex: 0xDCCFB6))
                        .scaleEffect(n == stars ? 1.08 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(n) star\(n == 1 ? "" : "s")")
                .accessibilityAddTraits(n <= stars ? .isSelected : [])
                .accessibilityIdentifier("star-\(n)")
                .overlay { if n == 5 { Sparks(trigger: burst) } }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: stars)
        .sensoryFeedback(.selection, trigger: stars)
    }
}

/// A ring of gold sparks that flies out each time `trigger` changes.
private struct Sparks: View {
    let trigger: Int
    @State private var flying = false

    var body: some View {
        ZStack {
            if trigger > 0 {
                ForEach(0..<14, id: \.self) { i in
                    let a = Double(i) / 14 * 2 * .pi
                    let d = 34.0 + Double((i * 37) % 30)
                    Circle().fill(Theme.goldLight)
                        .frame(width: 7, height: 7)
                        .scaleEffect(flying ? 0.2 : 1)
                        .offset(x: flying ? cos(a) * d : 0, y: flying ? sin(a) * d : 0)
                        .opacity(flying ? 0 : 1)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in
            flying = false
            withAnimation(.easeOut(duration: 0.7)) { flying = true }
        }
    }
}

/// Frost over a card. Wipe it clear with a finger, or tap to let it melt.
struct FrostView: View {
    let day: Int
    let onClear: () -> Void

    @State private var strokes: [[CGPoint]] = []
    @State private var seen: Set<Int> = []
    @State private var travelled: CGFloat = 0
    @State private var ticks = 0
    @State private var touching = false
    @State private var touched = false
    @State private var cleared = false
    private let ferns: [Path]

    init(day: Int, onClear: @escaping () -> Void) {
        self.day = day
        self.onClear = onClear
        ferns = Self.grow(seed: UInt32(day) &* 977 &+ 13)
    }

    private static let space = CGSize(width: 320, height: 420)

    /// Ice ferns growing in from the edges, grouped by branch depth so each group is one stroke.
    private static func grow(seed: UInt32) -> [Path] {
        var r = SeededRandom(seed: seed)
        var paths = [Path(), Path(), Path()]
        func branch(_ p: CGPoint, _ a: Double, _ len: Double, _ depth: Int) {
            guard depth >= 0, len >= 5 else { return }
            let e = CGPoint(x: p.x + cos(a) * len, y: p.y + sin(a) * len)
            paths[depth].move(to: p)
            paths[depth].addLine(to: e)
            for k in 1...4 {
                let u = Double(k) / 5
                let b = CGPoint(x: p.x + (e.x - p.x) * u, y: p.y + (e.y - p.y) * u)
                let l = len * 0.36 * (1 - u * 0.4)
                branch(b, a + 0.9, l, depth - 1)
                branch(b, a - 0.9, l, depth - 1)
            }
        }
        for i in 0..<22 {
            let side = i % 4
            let px = side == 0 ? 0 : side == 1 ? space.width : r.next() * space.width
            let py = side == 2 ? 0 : side == 3 ? space.height : r.next() * space.height
            let aim = atan2(space.height / 2 - py, space.width / 2 - px) + (r.next() - 0.5) * 1.1
            branch(CGPoint(x: px, y: py), aim, 50 + r.next() * 90, 2)
        }
        return paths
    }

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xF7FCFF), Color(hex: 0xD3E6F6), Color(hex: 0xEFF7FD)]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
                ))
                let number = Text("\(day)")
                    .font(.system(size: min(size.width * 0.55, 210), weight: .semibold, design: .serif))
                    .foregroundStyle(Color(hex: 0x4C76AA).opacity(0.3))
                let resolved = ctx.resolve(number)
                ctx.draw(resolved, at: CGPoint(x: size.width / 2, y: size.height / 2))
                let fit = CGAffineTransform(scaleX: size.width / Self.space.width, y: size.height / Self.space.height)
                for (depth, fern) in ferns.enumerated() {
                    let path = fern.applying(fit)
                    ctx.stroke(path.offsetBy(dx: 1, dy: 1), with: .color(Color(hex: 0x78A0CD).opacity(0.35)), style: StrokeStyle(lineWidth: CGFloat(depth) + 1.2, lineCap: .round))
                    ctx.stroke(path, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: CGFloat(depth) + 0.6, lineCap: .round))
                }
                ctx.blendMode = .destinationOut
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 9))
                    for stroke in strokes {
                        var path = Path()
                        path.addLines(stroke.count == 1 ? [stroke[0], CGPoint(x: stroke[0].x + 0.1, y: stroke[0].y)] : stroke)
                        layer.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 58, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in wipe(value.location, in: geo.size) }
                    .onEnded { value in
                        touching = false
                        if hypot(value.translation.width, value.translation.height) < 10 { clear() }
                    }
            )
            .task { await hint(in: geo.size) }
        }
        .accessibilityElement()
        .accessibilityLabel("Reveal day \(day)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("frost")
        .accessibilityAction { clear() }
    }

    private func wipe(_ point: CGPoint, in size: CGSize) {
        guard !cleared else { return }
        if !touching {
            touching = true
            touched = true
            strokes.append([point])
        } else if let last = strokes.last?.last {
            travelled += hypot(point.x - last.x, point.y - last.y)
            strokes[strokes.count - 1].append(point)
            if travelled > CGFloat(ticks) * 46 {
                ticks += 1
                Haptics.tick()
            }
        }
        mark(point, in: size)
        if seen.count > 43 { clear() }
    }

    /// Tracks how much of the card has been wiped on a 9 by 12 grid.
    private func mark(_ point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let x = min(8, max(0, Int(point.x / size.width * 9)))
        let y = min(11, max(0, Int(point.y / size.height * 12)))
        seen.insert(y * 9 + x)
    }

    private func clear() {
        guard !cleared else { return }
        cleared = true
        Haptics.done()
        onClear()
    }

    /// A first stroke draws itself, so the frost shows what to do.
    private func hint(in size: CGSize) async {
        try? await Task.sleep(for: .milliseconds(450))
        guard !touched, !cleared else { return }
        strokes.append([])
        for step in 0...26 {
            guard !touched, !cleared else { return }
            let u = Double(step) / 26
            let e = u * u * (3 - 2 * u)
            strokes[0].append(CGPoint(x: size.width * (0.16 + 0.68 * e), y: size.height * (0.3 + 0.12 * sin(e * 3.1))))
            try? await Task.sleep(for: .milliseconds(24))
        }
    }
}

/// The note that came with a gift.
struct NoteCard: View {
    let to: String
    let from: String
    let note: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFFD9A0))
                .frame(width: 44, height: 44)
                .background(Circle().fill(RadialGradient(colors: [Color(hex: 0xD2495C), Color(hex: 0x8C1F30)], center: UnitPoint(x: 0.38, y: 0.34), startRadius: 0, endRadius: 30)))
                .shadow(color: Color(hex: 0x8C1F30).opacity(0.4), radius: 5, y: 4)
                .padding(.bottom, 14)
                .accessibilityHidden(true)
            if !to.isEmpty {
                Text("\(to),").font(Theme.serif(28)).foregroundStyle(Theme.ink).padding(.bottom, 12)
            }
            Text(note)
                .font(Theme.serif(19, .regular)).italic()
                .lineSpacing(3)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("note-text")
            if !from.isEmpty {
                Text(from).font(Theme.serif(17, .regular)).foregroundStyle(Theme.berry).padding(.top, 14)
            }
        }
        .padding(EdgeInsets(top: 30, leading: 24, bottom: 26, trailing: 24))
        .frame(maxWidth: 400)
        .background(LinearGradient(colors: [Color(hex: 0xFFFAF0), Color(hex: 0xF6ECD8)], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.ink.opacity(0.07)))
            }
            .accessibilityLabel("Close")
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.goldLight.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 24)
        .environment(\.colorScheme, .light)
    }
}
