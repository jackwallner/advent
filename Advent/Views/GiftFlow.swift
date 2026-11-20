import SwiftUI

/// Make a calendar for someone else and send it as a link they open in any browser.
struct GiftFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gift: Gift?

    var body: some View {
        if let gift {
            GiftShareView(gift: gift, onDone: { dismiss() })
        } else {
            SetupView(mode: .gift, canClose: true, onGift: { made in withAnimation { gift = made } })
        }
    }
}

struct GiftShareView: View {
    let gift: Gift
    var onDone: () -> Void

    @Environment(CalendarStore.self) private var store
    @State private var previewing = false
    @State private var copied = false

    private var message: String {
        let lead = gift.to.isEmpty ? "I made you an advent calendar." : "\(gift.to), I made you an advent calendar."
        return lead + " Open one door each day in December."
    }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 0) {
                    Text(gift.to.isEmpty ? "Your gift" : "For \(gift.to)")
                        .font(Theme.serif(34))
                        .foregroundStyle(Theme.cream)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ShareLink(item: gift.url, message: Text(message)) {
                            Text("Send it")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("send")

                        Button(copied ? "Copied" : "Copy link") {
                            UIPasteboard.general.url = gift.url
                            copied = true
                        }
                        .modifier(GhostButton())
                        .accessibilityIdentifier("copy")
                        Button("Preview") { previewing = true }
                            .modifier(GhostButton())
                            .accessibilityIdentifier("preview")
                        Button("Done", action: onDone)
                            .modifier(GhostButton())
                            .accessibilityIdentifier("done")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 22)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.cream).shadow(color: .black.opacity(0.35), radius: 20, y: 14))
                    .padding(.top, 22)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $previewing) {
            GiftPreview(gift: gift)
        }
    }
}

struct GhostButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.muted)
            .padding(.top, 14)
    }
}

/// What the recipient will see. Opening doors here is not saved.
struct GiftPreview: View {
    let gift: Gift
    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var opened: Set<Int> = []
    @State private var ratings: [Int: Int] = [:]
    @State private var sheet: OpenDay?

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 0) {
                    Text(gift.to.isEmpty ? "Advent Doors" : "For \(gift.to)")
                        .font(Theme.serif(34))
                        .foregroundStyle(Theme.cream)
                        .padding(.top, 28)
                    if !gift.from.isEmpty {
                        Text("from \(gift.from)")
                            .font(Theme.serif(17, .regular)).italic()
                            .foregroundStyle(Theme.goldLight)
                            .padding(.top, 6)
                    }
                    if !gift.note.isEmpty {
                        Text(gift.note)
                            .font(Theme.serif(17, .regular)).italic()
                            .foregroundStyle(Theme.cream.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .padding(.top, 14)
                            .padding(.horizontal, 20)
                    }
                    BoardView(
                        slots: CalendarBuilder.layout(seed: gift.seed),
                        days: gift.days,
                        unlocked: CalendarBuilder.dayCount,
                        opened: opened,
                        ratings: ratings,
                        item: store.item,
                        onOpen: { day in
                            opened.insert(day)
                            sheet = OpenDay(day: day)
                        },
                        onLocked: { _ in }
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("gift-board")
                    .padding(.top, 22)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.cream.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .accessibilityLabel("Close")
            .padding(16)
        }
        .sheet(item: $sheet) { open in
            if let item = store.item(gift.days[open.day - 1]) {
                DaySheet(day: open.day, item: item, rating: ratings[open.day] ?? 0) { ratings[open.day] = $0 }
            }
        }
    }
}
