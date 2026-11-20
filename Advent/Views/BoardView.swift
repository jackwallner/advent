import SwiftUI

/// The 24-door board. Used for your own calendar and for previewing a gift.
struct BoardView: View {
    let slots: [DoorSlot]
    let days: [String]
    let unlocked: Int
    let opened: Set<Int>
    let ratings: [Int: Int]
    let item: (String) -> Item?
    let onOpen: (Int) -> Void
    let onLocked: (Int) -> Void

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(CalendarBuilder.rows(slots).enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row, id: \.day) { slot in
                        door(slot).gridCellColumns(slot.wide ? 2 : 1)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Theme.berryDark, Theme.berryDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.goldLight.opacity(0.45), lineWidth: 2))
                .shadow(color: .black.opacity(0.45), radius: 22, y: 18)
        )
    }

    private func door(_ slot: DoorSlot) -> some View {
        let d = slot.day
        let id = days.indices.contains(d - 1) ? days[d - 1] : ""
        return DoorView(
            slot: slot,
            item: item(id),
            isOpen: opened.contains(d),
            canOpen: d <= unlocked,
            isToday: d == unlocked && !opened.contains(d),
            rating: ratings[d] ?? 0,
            onOpen: { onOpen(d) },
            onLocked: { onLocked(d) }
        )
    }
}

struct DoorView: View {
    let slot: DoorSlot
    let item: Item?
    let isOpen: Bool
    let canOpen: Bool
    let isToday: Bool
    let rating: Int
    let onOpen: () -> Void
    let onLocked: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swinging = false
    @State private var shakes: CGFloat = 0
    @State private var pulse = false

    var body: some View {
        ZStack {
            inside
            if !isOpen || swinging {
                face
                    .rotation3DEffect(.degrees(swinging ? -108 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.55)
                    .opacity(swinging ? 0 : 1)
            }
        }
        .frame(height: 78)
        .frame(maxWidth: .infinity)
        .modifier(ShakeEffect(animatableData: shakes))
        .contentShape(Rectangle())
        .onTapGesture(perform: tap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("door-\(slot.day)")
        .onAppear {
            guard isToday, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var label: String {
        if isOpen, let item { return "Day \(slot.day), \(item.title)" }
        return canOpen ? "Open day \(slot.day)" : "Day \(slot.day), opens December \(slot.day)"
    }

    private func tap() {
        guard canOpen else {
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
            onLocked()
            return
        }
        guard !isOpen else { return onOpen() }
        if reduceMotion { return onOpen() }
        withAnimation(.easeInOut(duration: 0.65)) { swinging = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onOpen() }
    }

    private var inside: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(RadialGradient(colors: [Color(hex: 0x2D5A48), Color(hex: 0x163A2D)], center: .center, startRadius: 2, endRadius: 70))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.black.opacity(0.35), lineWidth: 2))
            .overlay {
                VStack(spacing: 4) {
                    Text("\(slot.day)").font(Theme.serif(15, .medium)).opacity(0.75)
                    if rating > 0 {
                        Text(String(repeating: "\u{2605}", count: rating))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.gold)
                    } else if let item, isOpen || swinging {
                        Image(systemName: item.category.symbol).font(.system(size: 14, weight: .medium)).opacity(0.85)
                    }
                }
                .foregroundStyle(Theme.goldLight)
            }
    }

    private var face: some View {
        let (bg, fg) = colors
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(bg)
            if slot.color == 2 {
                Stripes().clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Text("\(slot.day)")
                .font(Theme.serif(30))
                .foregroundStyle(fg)
            if slot.wide {
                Circle().fill(fg.opacity(0.45)).frame(width: 5, height: 5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 10)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 0, y: 2)
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.goldLight, lineWidth: 2)
                    .shadow(color: Theme.goldLight.opacity(pulse ? 0.9 : 0.6), radius: pulse ? 14 : 9)
            }
        }
    }

    private var colors: (Color, Color) {
        switch slot.color {
        case 0: (Theme.cream, Theme.berry)
        case 1: (Theme.doorPine, Theme.goldLight)
        case 2: (Theme.cream, Theme.berry)
        default: (Theme.doorGold, Theme.ink)
        }
    }
}

/// Candy-stripe door face.
struct Stripes: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 18
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + 9, y: 0))
                p.addLine(to: CGPoint(x: x + 9 + size.height, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(Theme.stripe))
                x += step
            }
        }
        .allowsHitTesting(false)
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(animatableData * .pi * 4), y: 0))
    }
}
