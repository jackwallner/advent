import SwiftUI

enum Theme {
    static let skyTop = Color(hex: 0x04071A)
    static let skyMid = Color(hex: 0x0A1436)
    static let skyLow = Color(hex: 0x1D2A5C)
    static let skyHorizon = Color(hex: 0x3A3972)
    static let panel = Color(hex: 0x0C122C)
    static let berry = Color(hex: 0xA3283A)
    static let gold = Color(hex: 0xE0AA45)
    static let goldLight = Color(hex: 0xF6D58A)
    static let goldDeep = Color(hex: 0xA8792A)
    static let cream = Color(hex: 0xF7F0E3)
    static let paper = Color(hex: 0xEFE4CF)
    static let line = Color(hex: 0xE4D8C1)
    static let ink = Color(hex: 0x2A1D14)
    static let inkSoft = Color(hex: 0x3B2E24)
    static let muted = Color(hex: 0x7A6A58)
    static let pine = Color(hex: 0x1F4D3C)
    static let snowInk = Color(hex: 0x2B3B70)
    static let silhouette = Color(hex: 0x6A3411)

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

/// The three houses a calendar can live in. Order and colors match `THEMES` in docs/scene.js.
struct HouseStyle: Identifiable, Sendable {
    let id: Int
    let name: String
    let wall: Color
    let wall2: Color
    let roof: Color
    let trim: Color
    let shutter: Color
    let shutter2: Color
    let number: Color

    static let all: [HouseStyle] = [
        HouseStyle(id: 0, name: "Midnight", wall: Color(hex: 0x2A3A68), wall2: Color(hex: 0x1A2548), roof: Color(hex: 0x0F1630),
                   trim: Color(hex: 0xF3EAD6), shutter: Color(hex: 0xB8364A), shutter2: Color(hex: 0x8C2435), number: Color(hex: 0xF6D58A)),
        HouseStyle(id: 1, name: "Gingerbread", wall: Color(hex: 0xA36A3C), wall2: Color(hex: 0x7A4A27), roof: Color(hex: 0x4F2F19),
                   trim: Color(hex: 0xFFF8EC), shutter: Color(hex: 0xFBF4E6), shutter2: Color(hex: 0xE6D8C0), number: Color(hex: 0xA3283A)),
        HouseStyle(id: 2, name: "Nordic", wall: Color(hex: 0xB03D34), wall2: Color(hex: 0x882A25), roof: Color(hex: 0x241616),
                   trim: Color(hex: 0xFBF5EA), shutter: Color(hex: 0x22543F), shutter2: Color(hex: 0x173A2D), number: Color(hex: 0xF6D58A)),
    ]

    static func at(_ index: Int?) -> HouseStyle {
        all.indices.contains(index ?? 0) ? all[index ?? 0] : all[0]
    }
}

struct BrandTitle: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "sparkle").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.goldLight)
            Text("Advent Doors").font(Theme.serif(34)).foregroundStyle(Theme.cream)
        }
        .shadow(color: .black.opacity(0.5), radius: 9, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xF8DC98), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.goldDeep, radius: 0, y: configuration.isPressed ? 2 : 5)
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// The dark glass card that setup and sharing sit on.
struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.panel.opacity(0.55)))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.goldLight.opacity(0.26), lineWidth: 1))
                    .shadow(color: .black.opacity(0.45), radius: 30, y: 24)
            )
    }
}

/// A small picture of a house, for picking one and for the share screen.
struct MiniHouse: View {
    let style: HouseStyle

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 48, y: size.height / 48)
            var wall = Path()
            wall.addLines([CGPoint(x: 8, y: 44), CGPoint(x: 8, y: 22), CGPoint(x: 24, y: 9), CGPoint(x: 40, y: 22), CGPoint(x: 40, y: 44)])
            wall.closeSubpath()
            ctx.fill(wall, with: .color(style.wall))
            var roof = Path()
            roof.addLines([CGPoint(x: 5, y: 23), CGPoint(x: 24, y: 7), CGPoint(x: 43, y: 23)])
            ctx.stroke(roof, with: .color(.white), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
            let window = Path(roundedRect: CGRect(x: 12, y: 25, width: 9, height: 11), cornerRadius: 1)
            ctx.fill(window, with: .color(Color(hex: 0xFFC869)))
            ctx.stroke(window, with: .color(style.trim), lineWidth: 1.5)
            let door = UnevenRoundedRectangle(topLeadingRadius: 4.5, topTrailingRadius: 4.5).path(in: CGRect(x: 27, y: 26.5, width: 9, height: 17.5))
            ctx.fill(door, with: .color(style.shutter))
            ctx.stroke(door, with: .color(style.trim), lineWidth: 1.5)
        }
        .accessibilityHidden(true)
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
