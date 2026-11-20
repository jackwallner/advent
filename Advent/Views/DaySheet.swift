import SwiftUI

struct DaySheet: View {
    let day: Int
    let item: Item
    let rating: Int
    let onRate: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var revealed = false
    @State private var stars = 0
    @State private var height: CGFloat = 360

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("Day \(day) \u{00B7} \(item.category.name) \u{00B7} \(item.kind.name)")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.berry)
                    .padding(.top, 8)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.paper))
                }
                .accessibilityLabel("Close")
            }

            Text(item.title)
                .font(Theme.serif(27))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .accessibilityIdentifier("day-title")

            Text(item.detail)
                .font(.system(size: 17))
                .lineSpacing(3)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if let reveal = item.reveal {
                Group {
                    if revealed {
                        Text(reveal)
                            .font(Theme.serif(19, .regular)).italic()
                            .foregroundStyle(Theme.pine)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    } else {
                        Button(item.category == .humor ? "Punchline" : "Answer") {
                            withAnimation(.easeOut(duration: 0.2)) { revealed = true }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.pine)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.paper))
                        .accessibilityIdentifier("reveal")
                    }
                }
                .padding(.top, 14)
            }

            Divider().overlay(Theme.line).padding(.top, 22).padding(.bottom, 16)

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { n in
                    Button {
                        stars = n
                        onRate(n)
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(n <= stars ? Theme.gold : Theme.line)
                            .scaleEffect(n == stars ? 1.08 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n) star\(n == 1 ? "" : "s")")
                    .accessibilityAddTraits(n <= stars ? .isSelected : [])
                    .accessibilityIdentifier("star-\(n)")
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: stars)
            .sensoryFeedback(.selection, trigger: stars)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { height = geo.size.height }
                .onChange(of: geo.size.height) { _, h in height = h }
        })
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationBackground(Theme.cream)
        .presentationCornerRadius(24)
        .presentationDetents([.height(max(height, 240)), .large])
        .presentationDragIndicator(.hidden)
        .environment(\.colorScheme, .light)
        .onAppear { stars = rating }
    }
}
