import StoreKit
import SwiftUI

struct OpenDay: Identifiable {
    let day: Int
    var id: Int { day }
}

struct CalendarView: View {
    @Environment(CalendarStore.self) private var store
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @AppStorage("reminders.on") private var remindersOn = true

    @State private var sheet: OpenDay?
    @State private var ratedInSheet = false
    @State private var editing = false
    @State private var gifting = false
    @State private var toast: String?
    private let reviews = ReviewPromptTracker()

    var body: some View {
        ZStack {
            NightBackground()
            if let cal = store.mine {
                ScrollView {
                    VStack(spacing: 0) {
                        BrandTitle().padding(.top, 12)
                        status(cal)
                        BoardView(
                            slots: CalendarBuilder.layout(seed: cal.seed),
                            days: cal.days,
                            unlocked: store.unlocked,
                            opened: Set(store.progress.opened.keys),
                            ratings: store.progress.ratings,
                            item: store.item,
                            onOpen: { day in
                                store.open(day)
                                ratedInSheet = false
                                sheet = OpenDay(day: day)
                            },
                            onLocked: { day in show("Opens December \(day)") }
                        )
                        .padding(.top, 22)
                        footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .overlay(alignment: .topTrailing) { menu }
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $sheet, onDismiss: askForReviewIfDue) { open in
            if let cal = store.mine, let item = store.item(cal.days[open.day - 1]) {
                DaySheet(day: open.day, item: item, rating: store.progress.ratings[open.day] ?? 0) { stars in
                    store.rate(open.day, stars: stars)
                    ratedInSheet = true
                }
            }
        }
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
                .font(Theme.serif(17, .regular).italic())
                .foregroundStyle(Theme.goldLight)
                .padding(.top, 6)
                .accessibilityIdentifier("countdown")
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
        .foregroundStyle(Theme.goldLight)
        .padding(.top, 22)
    }

    private var menu: some View {
        Menu {
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
        .padding(.trailing, 10)
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
                .background(Capsule().fill(Theme.ink))
                .padding(.bottom, 24)
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

    /// Positive moment: a door was rated. Ask after the sheet is gone, if the tracker allows.
    private func askForReviewIfDue() {
        guard ratedInSheet, reviews.shouldAsk() else { return }
        ratedInSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard sheet == nil, !editing, !gifting else { return }
            reviews.didAsk()
            requestReview()
        }
    }
}

enum AppInfo {
    /// Set once the App Store record exists.
    static let appStoreID: String? = nil
    static let feedbackEmail = "jackwallner@gmail.com"
    static let privacyURL = URL(string: "https://jackwallner.com/ios/advent/privacy-policy.html")!
}
