import StoreKit
import SwiftUI

/// A door whose card is showing, and where on screen its window is.
struct OpenCard: Equatable {
    let day: Int
    let fresh: Bool
    let anchor: CGPoint
}

/// Sky, house, snow and the card that grows out of a tapped window. Used for your own calendar and for a gift preview.
struct HouseScene<Header: View, Footer: View>: View {
    let style: HouseStyle
    let seed: UInt32
    let days: [String]
    let unlocked: Int
    let opened: Set<Int>
    let ratings: [Int: Int]
    var note: (to: String, from: String, text: String)?
    let onOpen: (Int) -> Void
    let onRate: (Int, Int) -> Void
    var onLocked: (Int) -> Void = { _ in }
    var onCardClosed: () -> Void = {}
    @ViewBuilder var header: Header
    @ViewBuilder var footer: Footer

    @Environment(CalendarStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snow = SnowModel()
    @State private var card: OpenCard?
    @State private var noteAnchor: CGPoint?

    var body: some View {
        GeometryReader { root in
            let frame = root.frame(in: .global)
            let unit = { (p: CGPoint) in
                UnitPoint(x: (p.x - frame.minX) / max(frame.width, 1), y: (p.y - frame.minY) / max(frame.height, 1))
            }
            ZStack {
                SkyView()
                    .contentShape(Rectangle())
                    .onTapGesture { point in snow.gust(from: point.x, width: root.size.width) }
                VStack(spacing: 0) {
                    header.frame(minHeight: 30)
                    HouseView(
                        style: style, seed: seed, days: days, unlocked: unlocked, opened: opened, item: store.item,
                        hasNote: !(note?.text.isEmpty ?? true),
                        onTap: tap,
                        onNote: { point in withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { noteAnchor = point } }
                    )
                    footer.frame(height: 56)
                }
                SnowView(model: snow)
                if card != nil || noteAnchor != nil {
                    RadialGradient(
                        colors: [Color(hex: 0xFFC460).opacity(0.3), Theme.skyTop.opacity(0.84)],
                        center: UnitPoint(x: 0.5, y: 0.46), startRadius: 0, endRadius: 430
                    )
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .transition(.opacity)
                    .zIndex(1)
                }
                if let card, days.indices.contains(card.day - 1), let item = store.item(days[card.day - 1]) {
                    DayCard(
                        day: card.day, item: item, rating: ratings[card.day] ?? 0, fresh: card.fresh,
                        onRate: { onRate(card.day, $0) }, onClose: close
                    )
                    .padding(20)
                    .transition(.scale(scale: 0.12, anchor: unit(card.anchor)).combined(with: .opacity))
                    .zIndex(2)
                }
                if let noteAnchor, let note {
                    NoteCard(to: note.to, from: note.from, note: note.text, onClose: close)
                        .padding(20)
                        .transition(.scale(scale: 0.12, anchor: unit(noteAnchor)).combined(with: .opacity))
                        .zIndex(2)
                }
            }
        }
    }

    private func tap(_ day: Int, at point: CGPoint) {
        guard card == nil, noteAnchor == nil else { return }
        guard day <= unlocked else {
            Haptics.locked()
            return onLocked(day)
        }
        let fresh = !opened.contains(day)
        let show = { withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { card = OpenCard(day: day, fresh: fresh, anchor: point) } }
        guard fresh else { return show() }
        // The shutters swing open first; the card follows them out.
        onOpen(day)
        Haptics.open()
        Bells.shared.chime(day: day)
        if reduceMotion { show() } else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) { show() } }
    }

    private func close() {
        let wasDay = card != nil
        withAnimation(.easeInOut(duration: 0.3)) {
            card = nil
            noteAnchor = nil
        }
        if wasDay { onCardClosed() }
    }
}

struct CalendarView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @AppStorage("reminders.on") private var remindersOn = true
    @AppStorage("sound.on") private var soundOn = true

    @State private var rated = false
    @State private var editing = false
    @State private var gifting = false
    @State private var toast: String?
    private let reviews = ReviewPromptTracker()

    var body: some View {
        ZStack {
            if let cal = store.mine {
                HouseScene(
                    style: HouseStyle.at(cal.theme), seed: cal.seed, days: cal.days, unlocked: store.unlocked,
                    opened: Set(store.progress.opened.keys), ratings: store.progress.ratings,
                    onOpen: { store.open($0) },
                    onRate: { day, stars in
                        store.rate(day, stars: stars)
                        rated = true
                    },
                    onLocked: { day in show("Opens December \(day)") },
                    onCardClosed: askForReviewIfDue,
                    header: { status(cal) },
                    footer: { footer }
                )
            }
        }
        .overlay(alignment: .topLeading) { menu }
        .overlay(alignment: .bottom) { toastView }
        .fullScreenCover(isPresented: $editing) {
            SetupView(mode: .edit, canClose: true)
        }
        .fullScreenCover(isPresented: $gifting) {
            GiftFlow()
        }
    }

    @ViewBuilder
    private func status(_ cal: SavedCalendar) -> some View {
        let togo = store.daysToGo(year: cal.year)
        if store.unlocked == 0, togo > 0 {
            Text(togo == 1 ? "Opens tomorrow" : "\(togo) days to go")
                .font(Theme.serif(19, .regular)).italic()
                .foregroundStyle(Theme.goldLight)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                .padding(.top, 10)
                .accessibilityIdentifier("countdown")
        } else {
            Color.clear.frame(height: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: 26) {
            Button("Change") { editing = true }
                .accessibilityIdentifier("change")
            Button("Make one for someone") { gifting = true }
                .accessibilityIdentifier("gift")
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Theme.snowInk)
    }

    private var menu: some View {
        Menu {
            Toggle("Bells", isOn: $soundOn)
            Toggle("Morning reminders", isOn: $remindersOn)
            if let id = AppInfo.appStoreID {
                Button("Rate Advent Doors") {
                    reviews.didOpenWriteReview()
                    openURL(URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")!)
                }
            }
            Button("Send Feedback") {
                openURL(URL(string: "mailto:\(AppInfo.feedbackEmail)?subject=Advent%20Doors")!)
            }
            Button("Privacy Policy") { openURL(AppInfo.privacyURL) }
            #if DEBUG
            Section("Debug") {
                Picker("Unlocked doors", selection: Binding(get: { store.debugDay ?? -1 }, set: { store.debugDay = $0 < 0 ? nil : $0 })) {
                    Text("Real date").tag(-1)
                    ForEach(0...24, id: \.self) { Text("\($0)").tag($0) }
                }
                Button("Start over", role: .destructive) { store.reset() }
            }
            #endif
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.cream.opacity(0.75))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
        .accessibilityIdentifier("menu")
        .padding(.leading, 10)
        .onChange(of: remindersOn) { _, on in
            guard let year = store.mine?.year else { return }
            if on {
                Task { remindersOn = await Reminders.enable(year: year) }
            } else {
                Reminders.disable()
            }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.cream)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.skyTop.opacity(0.92)).overlay(Capsule().strokeBorder(Theme.goldLight.opacity(0.3), lineWidth: 1)))
                .padding(.bottom, 76)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("toast")
        }
    }

    private func show(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        let shown = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toast == shown { withAnimation(.easeIn(duration: 0.2)) { toast = nil } }
        }
    }

    /// Positive moment: a door was rated. Ask after the card is gone, if the tracker allows.
    private func askForReviewIfDue() {
        guard rated, reviews.shouldAsk() else { return }
        rated = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard !editing, !gifting else { return }
            reviews.didAsk()
            requestReview()
        }
    }
}

enum AppInfo {
    /// Set once the App Store record exists.
    static let appStoreID: String? = "6837399320"
    static let feedbackEmail = "jackwallner@gmail.com"
    static let privacyURL = URL(string: "https://jackwallner.com/ios/advent/privacy-policy.html")!
}
