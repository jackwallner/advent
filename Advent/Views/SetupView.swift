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
    @State private var to = ""
    @State private var from = ""
    @State private var note = ""
    @FocusState private var focused: Field?

    private enum Field { case to, from, note }

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                VStack(spacing: 22) {
                    BrandTitle().padding(.top, 12)
                    card
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(alignment: .topTrailing) {
            if canClose {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.cream.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .accessibilityLabel("Close")
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
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
                    Chip(title: c.name, selected: categories.contains(c), tint: Theme.berry) {
                        if categories.contains(c) { categories.remove(c) } else { categories.insert(c) }
                    }
                    .accessibilityIdentifier("cat-\(c.rawValue)")
                }
            }
            .padding(.bottom, 22)

            heading("Budget")
            HStack(spacing: 8) {
                ForEach(Budget.allCases) { b in
                    Chip(title: b.name, selected: budget == b, tint: Theme.pine, fill: true) { budget = b }
                        .accessibilityIdentifier("budget-\(b.rawValue)")
                }
            }
            .padding(.bottom, 22)

            if mode == .gift { giftFields }

            Button(action: submit) {
                Text(mode == .edit ? "Save" : mode == .gift ? "Make the gift" : "Make my calendar")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(categories.isEmpty)
            .accessibilityIdentifier("make")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.cream).shadow(color: .black.opacity(0.35), radius: 20, y: 14))
        .environment(\.colorScheme, .light)
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
            .font(Theme.serif(20))
            .foregroundStyle(Theme.ink)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }

    private func prefill() {
        guard mode == .edit, let mine = store.mine else { return }
        categories = Set(mine.categories)
        budget = mine.budget
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
            store.create(categories: cats, budget: budget)
            Task { if let year = store.mine?.year { _ = await Reminders.enable(year: year) } }
            if canClose { dismiss() }
        case .edit:
            store.update(categories: cats, budget: budget)
            dismiss()
        case .gift:
            let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
            onGift(store.makeGift(categories: cats, budget: budget, to: trim(to), from: trim(from), note: trim(note)))
        }
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let tint: Color
    var fill = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? .white : Theme.ink)
                .padding(.horizontal, fill ? 4 : 14)
                .padding(.vertical, 10)
                .frame(maxWidth: fill ? .infinity : nil)
                .background(Capsule().fill(selected ? tint : .white))
                .overlay(Capsule().strokeBorder(selected ? tint : Theme.line, lineWidth: 1.5))
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
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
    }
}
