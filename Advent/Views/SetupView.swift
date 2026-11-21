import SwiftUI

struct SetupView: View {
    enum Mode { case mine, edit, gift }

    @Environment(CalendarStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var mode: Mode
    var canClose = false
    var onGift: (Gift) -> Void = { _ in }

    @State private var categories: Set<Category> = []
    @State private var budget: Budget = .none
    @State private var theme = 0
    @State private var to = ""
    @State private var from = ""
    @State private var note = ""
    @FocusState private var focused: Field?

    private enum Field { case to, from, note }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 20) {
                    BrandTitle().padding(.top, 34)
                    card
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                // The close button rides with the content, so it never sits on top of a chip once the form scrolls.
                .overlay(alignment: .topLeading) {
                    if canClose {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.cream.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.white.opacity(0.1)))
                        }
                        .accessibilityLabel("Close")
                        .padding(.leading, 16)
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear(perform: prefill)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            if mode != .edit, !canCloseOnlyGift {
                Picker("Calendar", selection: $mode) {
                    Text("For me").tag(Mode.mine)
                    Text("For someone").tag(Mode.gift)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 20)
            }

            heading("What's inside")
            FlowLayout(spacing: 8) {
                ForEach(Category.allCases) { c in
                    Chip(title: c.name, symbol: c.symbol, selected: categories.contains(c)) {
                        if categories.contains(c) { categories.remove(c) } else { categories.insert(c) }
                    }
                    .accessibilityIdentifier("cat-\(c.rawValue)")
                }
            }
            .padding(.bottom, 22)

            heading("Budget")
            HStack(spacing: 8) {
                ForEach(Budget.allCases) { b in
                    Chip(title: b.name, selected: budget == b, fill: true) { budget = b }
                        .accessibilityIdentifier("budget-\(b.rawValue)")
                }
            }
            .padding(.bottom, 22)

            heading("House")
            HStack(spacing: 10) {
                ForEach(HouseStyle.all) { style in
                    Button { theme = style.id } label: {
                        MiniHouse(style: style)
                            .frame(width: 56, height: 56)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(theme == style.id ? Theme.goldLight.opacity(0.14) : .white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(theme == style.id ? Theme.goldLight : Theme.cream.opacity(0.18), lineWidth: theme == style.id ? 2 : 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(style.name) house")
                    .accessibilityAddTraits(theme == style.id ? .isSelected : [])
                    .accessibilityIdentifier("house-\(style.id)")
                }
            }
            .animation(.easeOut(duration: 0.15), value: theme)
            .padding(.bottom, 22)

            if mode == .gift { giftFields }

            Button(action: submit) {
                Text(mode == .edit ? "Save" : mode == .gift ? "Make the gift" : "Make my calendar")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(categories.isEmpty)
            .accessibilityIdentifier("make")
        }
        .modifier(GlassPanel())
    }

    /// When opened from "Make one for someone", the gift mode is the point, so skip the toggle.
    private var canCloseOnlyGift: Bool { canClose && mode == .gift }

    private var giftFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Who's it for")
            HStack(spacing: 10) {
                field("To", text: $to, focus: .to)
                field("From", text: $from, focus: .from)
            }
            TextField("Note (optional)", text: $note, axis: .vertical)
                .lineLimit(3...4)
                .focused($focused, equals: .note)
                .modifier(FieldStyle())
                .accessibilityIdentifier("note")
        }
        .padding(.bottom, 14)
    }

    private func field(_ title: String, text: Binding<String>, focus: Field) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($focused, equals: focus)
            .submitLabel(.next)
            .modifier(FieldStyle())
            .accessibilityIdentifier(title.lowercased())
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(Theme.serif(19))
            .foregroundStyle(Theme.goldLight)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }

    private func prefill() {
        guard mode == .edit, let mine = store.mine else { return }
        categories = Set(mine.categories)
        budget = mine.budget
        theme = mine.theme ?? 0
    }

    private func submit() {
        let cats = Category.allCases.filter(categories.contains)
        guard !cats.isEmpty else { return }
        // Ending editing commits text the keyboard still holds as a suggestion; read the fields a tick later.
        if focused != nil {
            focused = nil
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            DispatchQueue.main.async { finish(cats) }
            return
        }
        finish(cats)
    }

    private func finish(_ cats: [Category]) {
        switch mode {
        case .mine:
            store.create(categories: cats, budget: budget, theme: theme)
            Task { if let year = store.mine?.year { _ = await Reminders.enable(year: year) } }
            if canClose { dismiss() }
        case .edit:
            store.update(categories: cats, budget: budget, theme: theme)
            dismiss()
        case .gift:
            let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
            onGift(store.makeGift(categories: cats, budget: budget, theme: theme, to: trim(to), from: trim(from), note: trim(note)))
        }
    }
}

struct Chip: View {
    let title: String
    var symbol: String?
    let selected: Bool
    var fill = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Theme.ink : Theme.cream)
            .padding(.horizontal, fill ? 4 : 13)
            .padding(.vertical, 10)
            .frame(maxWidth: fill ? .infinity : nil)
            .background(Capsule().fill(selected ? Theme.goldLight : .white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(selected ? Theme.goldLight : Theme.cream.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundStyle(Theme.cream)
            .tint(Theme.goldLight)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.cream.opacity(0.22), lineWidth: 1))
    }
}
