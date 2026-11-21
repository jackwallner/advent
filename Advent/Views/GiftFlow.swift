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
                VStack(spacing: 20) {
                    Text(gift.to.isEmpty ? "Your gift" : "For \(gift.to)")
                        .font(Theme.serif(34))
                        .foregroundStyle(Theme.cream)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 9, y: 2)
                        .padding(.top, 34)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        MiniHouse(style: HouseStyle.at(gift.theme))
                            .frame(width: 92, height: 92)
                            .shadow(color: Color(hex: 0xFFC864).opacity(0.45), radius: 16)
                            .padding(.bottom, 14)
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
                    .modifier(GlassPanel())
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .fullScreenCover(isPresented: $previewing) {
            GiftPreview(gift: gift)
        }
    }
}

struct GhostButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.cream.opacity(0.7))
            .padding(.top, 15)
    }
}

/// What the recipient will see, with every door unlocked. Opening doors here is not saved.
struct GiftPreview: View {
    let gift: Gift
    @Environment(\.dismiss) private var dismiss
    @State private var opened: Set<Int> = []
    @State private var ratings: [Int: Int] = [:]

    var body: some View {
        HouseScene(
            style: HouseStyle.at(gift.theme), seed: gift.seed, days: gift.days, unlocked: CalendarBuilder.dayCount,
            opened: opened, ratings: ratings,
            note: (gift.to, gift.from, gift.note),
            onOpen: { day in withAnimation(.easeInOut(duration: 0.85)) { _ = opened.insert(day) } },
            onRate: { day, stars in ratings[day] = stars },
            header: {
                VStack(spacing: 2) {
                    Text(gift.to.isEmpty ? "Advent Doors" : "For \(gift.to)")
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.cream)
                    if !gift.from.isEmpty {
                        Text("from \(gift.from)")
                            .font(Theme.serif(17, .regular)).italic()
                            .foregroundStyle(Theme.goldLight)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 9, y: 2)
                .padding(.top, 8)
            },
            footer: { Color.clear }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gift-board")
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.cream.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .accessibilityLabel("Close preview")
            .accessibilityIdentifier("close-preview")
            .padding(.leading, 16)
            .padding(.top, 8)
        }
    }
}
