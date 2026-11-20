import SwiftUI

enum Theme {
    static let night = Color(hex: 0x102A22)
    static let night2 = Color(hex: 0x0A1D17)
    static let nightTop = Color(hex: 0x1A3F32)
    static let berry = Color(hex: 0xA3283A)
    static let berryDark = Color(hex: 0x7D1C2B)
    static let berryDeep = Color(hex: 0x5E1420)
    static let gold = Color(hex: 0xD9A441)
    static let goldLight = Color(hex: 0xECC77A)
    static let cream = Color(hex: 0xF7F0E3)
    static let paper = Color(hex: 0xEFE4CF)
    static let line = Color(hex: 0xD8CBB2)
    static let ink = Color(hex: 0x2A1D14)
    static let inkSoft = Color(hex: 0x3B2E24)
    static let muted = Color(hex: 0x7A6A58)
    static let pine = Color(hex: 0x1F4D3C)
    static let doorPine = Color(hex: 0x2A5A47)
    static let doorGold = Color(hex: 0xE2BF73)
    static let stripe = Color(hex: 0xF1D9D4)

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct NightBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.night, Theme.night2], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.nightTop, .clear], center: .top, startRadius: 0, endRadius: 520)
            Snowfall()
        }
        .ignoresSafeArea()
    }
}

/// A light, slow snowfall drawn on a canvas. Off with Reduce Motion.
struct Snowfall: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let flakes: [(x: Double, size: Double, speed: Double, phase: Double, alpha: Double)] = (0..<34).map { i in
        var r = SeededRandom(seed: UInt32(i * 7919 + 11))
        return (r.next(), 1.6 + r.next() * 2.6, 0.025 + r.next() * 0.04, r.next(), 0.18 + r.next() * 0.4)
    }

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                Canvas { ctx, size in
                    let t = context.date.timeIntervalSinceReferenceDate
                    for f in flakes {
                        let progress = (f.phase + t * f.speed).truncatingRemainder(dividingBy: 1)
                        let y = progress * (size.height + 20) - 10
                        let x = f.x * size.width + sin(t * 0.4 + f.phase * 6) * 14 + progress * 24
                        let rect = CGRect(x: x, y: y, width: f.size, height: f.size)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(f.alpha)))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct BrandTitle: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.gold)
            Text("Advent Doors").font(Theme.serif(34)).foregroundStyle(Theme.cream)
            Image(systemName: "sparkle").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.gold)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.berry)
                    .shadow(color: Theme.berryDark, radius: 0, y: configuration.isPressed ? 2 : 5)
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indexes {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indexes: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let needed = row.indexes.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indexes.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indexes.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indexes.append(i)
        }
        if !row.indexes.isEmpty { rows.append(row) }
        return rows
    }
}
