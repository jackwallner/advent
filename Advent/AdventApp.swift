import SwiftUI

@main
struct AdventApp: App {
    @State private var store: CalendarStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UITesting"), let bundle = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundle)
        }
        let store = CalendarStore()
        #if DEBUG
        if let i = args.firstIndex(of: "-DebugDay"), args.indices.contains(i + 1), let day = Int(args[i + 1]) {
            store.debugDay = day
        }
        #endif
        _store = State(initialValue: store)
        ReviewPromptTracker().recordLaunch()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            store.now = Date()
            if let year = store.mine?.year, UserDefaults.standard.object(forKey: "reminders.on") as? Bool ?? true {
                Task { if await Reminders.isAuthorized() { await Reminders.schedule(year: year) } }
            }
        }
    }
}

struct RootView: View {
    @Environment(CalendarStore.self) private var store
    @State private var gift: Gift?

    var body: some View {
        Group {
            if store.mine != nil {
                CalendarView()
                    .transition(.opacity)
            } else if let gift {
                GiftShareView(gift: gift, onDone: { withAnimation { self.gift = nil } })
            } else {
                SetupView(mode: .mine, onGift: { made in withAnimation { gift = made } })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.mine == nil)
    }
}
