import Foundation

enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case selfcare, family, fitness, music, puzzles, food, humor, books

    var id: String { rawValue }

    var name: String {
        switch self {
        case .selfcare: "Self care"
        case .family: "Family fun"
        case .fitness: "Fitness"
        case .music: "Music"
        case .puzzles: "Puzzles"
        case .food: "Food"
        case .humor: "Humor"
        case .books: "Books"
        }
    }

    /// One-letter code used in gift links. Must match `CATS` in docs/calendar.js.
    var code: Character {
        switch self {
        case .selfcare: "s"
        case .family: "f"
        case .fitness: "x"
        case .music: "m"
        case .puzzles: "p"
        case .food: "o"
        case .humor: "h"
        case .books: "b"
        }
    }

    var symbol: String {
        switch self {
        case .selfcare: "cup.and.saucer.fill"
        case .family: "person.2.fill"
        case .fitness: "dumbbell.fill"
        case .music: "music.note"
        case .puzzles: "puzzlepiece.fill"
        case .food: "birthday.cake.fill"
        case .humor: "face.smiling.inverse"
        case .books: "book.fill"
        }
    }
}

enum Budget: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, low, medium, high

    var id: String { rawValue }

    var name: String {
        switch self {
        case .none: "Free"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var rank: Int { Budget.allCases.firstIndex(of: self)! }
}

enum Kind: String, Codable, Sendable {
    case `do`, read, think

    var name: String {
        switch self {
        case .do: "Do"
        case .read: "Read"
        case .think: "Think"
        }
    }
}

struct Item: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let category: Category
    let budget: Budget
    let kind: Kind
    let title: String
    let detail: String
    let reveal: String?
}
