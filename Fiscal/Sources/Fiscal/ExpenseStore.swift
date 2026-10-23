import Combine
import Foundation

struct ExpenseCategory: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var symbol: String
    var colorName: String

    static let defaults: [ExpenseCategory] = [
        .init(id: "food", name: "Food", symbol: "fork.knife", colorName: "orange"),
        .init(id: "transport", name: "Transport", symbol: "car.fill", colorName: "blue"),
        .init(id: "groceries", name: "Groceries", symbol: "cart.fill", colorName: "green"),
        .init(id: "shopping", name: "Shopping", symbol: "bag.fill", colorName: "pink"),
        .init(id: "bills", name: "Bills", symbol: "bolt.fill", colorName: "yellow"),
        .init(id: "health", name: "Health", symbol: "cross.case.fill", colorName: "red"),
        .init(id: "fun", name: "Fun", symbol: "sparkles", colorName: "purple"),
        .init(id: "other", name: "Other", symbol: "ellipsis", colorName: "gray")
    ]
}

struct Expense: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var amount: Double
    var note: String
    var categoryID: String
    var date: Date

    init(id: UUID = UUID(), amount: Double, note: String, categoryID: String, date: Date) {
        self.id = id; self.amount = amount; self.note = note; self.categoryID = categoryID; self.date = date
    }

    private enum CodingKeys: String, CodingKey { case id, amount, note, categoryID, category, date }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decode(UUID.self, forKey: .id)
        amount = try box.decode(Double.self, forKey: .amount)
        note = try box.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try box.decode(Date.self, forKey: .date)
        if let current = try box.decodeIfPresent(String.self, forKey: .categoryID) {
            categoryID = current
        } else {
            categoryID = (try box.decodeIfPresent(String.self, forKey: .category) ?? "Other").lowercased()
        }
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(id, forKey: .id); try box.encode(amount, forKey: .amount)
        try box.encode(note, forKey: .note); try box.encode(categoryID, forKey: .categoryID); try box.encode(date, forKey: .date)
    }
}

@MainActor
final class ExpenseStore: ObservableObject {
    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var categories: [ExpenseCategory] = []
    @Published var currencyCode: String {
        didSet { UserDefaults.standard.set(currencyCode, forKey: "currencyCode") }
    }
    private let expensesURL: URL
    private let categoriesURL: URL

    init() {
        currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "INR"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        expensesURL = documents.appendingPathComponent("expenses.json")
        categoriesURL = documents.appendingPathComponent("categories.json")
        load()
    }

    func category(_ id: String) -> ExpenseCategory {
        categories.first { $0.id == id } ?? categories.first { $0.id == "other" } ?? ExpenseCategory.defaults.last!
    }

    func add(amount: Double, note: String, categoryID: String, date: Date) {
        expenses.append(.init(amount: amount, note: clean(note), categoryID: categoryID, date: date)); persistExpenses()
    }

    func update(_ expense: Expense, amount: Double, note: String, categoryID: String, date: Date) {
        guard let index = expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        expenses[index].amount = amount; expenses[index].note = clean(note)
        expenses[index].categoryID = categoryID; expenses[index].date = date; persistExpenses()
    }

    func delete(_ expense: Expense) { expenses.removeAll { $0.id == expense.id }; persistExpenses() }
    func deleteAll() { expenses.removeAll(); persistExpenses() }

    func addCategory(name: String, symbol: String, colorName: String) {
        let name = clean(name); guard !name.isEmpty else { return }
        categories.append(.init(id: UUID().uuidString, name: name, symbol: symbol, colorName: colorName)); persistCategories()
    }

    func renameCategory(_ category: ExpenseCategory, to name: String) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }), !clean(name).isEmpty else { return }
        categories[index].name = clean(name); persistCategories()
    }

    func deleteCategory(_ category: ExpenseCategory) {
        guard category.id != "other" else { return }
        expenses = expenses.map {
            guard $0.categoryID == category.id else { return $0 }
            return Expense(id: $0.id, amount: $0.amount, note: $0.note, categoryID: "other", date: $0.date)
        }
        categories.removeAll { $0.id == category.id }; persistCategories(); persistExpenses()
    }

    func expenses(in month: Date) -> [Expense] {
        expenses.filter { Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    func mostUsedCategories(limit: Int = 2) -> [ExpenseCategory] {
        let counts = Dictionary(grouping: expenses, by: \.categoryID).mapValues(\.count)
        let categoryOrder = Dictionary(uniqueKeysWithValues: categories.enumerated().map { ($1.id, $0) })
        return categories
            .sorted {
                let left = counts[$0.id, default: 0]
                let right = counts[$1.id, default: 0]
                return left == right ? categoryOrder[$0.id, default: 0] < categoryOrder[$1.id, default: 0] : left > right
            }
            .prefix(limit)
            .map { $0 }
    }

    func amountText(_ amount: Double) -> String {
        if currencyCode == "INR" {
            return "₹" + amount.formatted(.number.precision(.fractionLength(0...2)))
        }
        return amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0...2)))
    }

    var csv: String {
        let iso = ISO8601DateFormatter()
        let rows = expenses.map {
            let note = $0.note.replacingOccurrences(of: "\"", with: "\"\"")
            return "\(iso.string(from: $0.date)),\($0.amount),\(currencyCode),\(category($0.categoryID).name),\"\(note)\""
        }
        return (["date,amount,currency,category,note"] + rows).joined(separator: "\n")
    }

    private func clean(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func load() {
        if let data = try? Data(contentsOf: categoriesURL), let saved = try? JSONDecoder().decode([ExpenseCategory].self, from: data), !saved.isEmpty { categories = saved }
        else { categories = ExpenseCategory.defaults }
        if let data = try? Data(contentsOf: expensesURL), let saved = try? JSONDecoder().decode([Expense].self, from: data) { expenses = saved }
        sortExpenses()
    }
    private func sortExpenses() { expenses.sort { $0.date > $1.date } }
    private func persistExpenses() { sortExpenses(); if let data = try? JSONEncoder().encode(expenses) { try? data.write(to: expensesURL, options: .atomic) } }
    private func persistCategories() { if let data = try? JSONEncoder().encode(categories) { try? data.write(to: categoriesURL, options: .atomic) } }
}
