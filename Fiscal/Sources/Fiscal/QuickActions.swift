import AppIntents
import Combine
import Foundation
import UIKit

struct QuickAddRequest: Equatable, Sendable {
    let id = UUID()
    let categoryID: String?
}

@MainActor
final class QuickAddRouter: ObservableObject {
    static let shared = QuickAddRouter()
    @Published private(set) var request: QuickAddRequest?

    private init() {}

    func open(categoryID: String? = nil) {
        request = QuickAddRequest(categoryID: categoryID)
    }

    func open(url: URL) {
        guard url.scheme == "fiscal", url.host == "add" else { return }
        let categoryID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "category" })?.value
        open(categoryID: categoryID)
    }
}

@MainActor
enum QuickActionHandler {
    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard item.type.hasPrefix(QuickActionRegistry.typePrefix) else { return false }
        let categoryID = item.userInfo?["categoryID"] as? String
        QuickAddRouter.shared.open(categoryID: categoryID)
        return true
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let item = options.shortcutItem {
            QuickActionHandler.handle(item)
        }

        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickActionHandler.handle(shortcutItem))
    }
}

@MainActor
enum QuickActionRegistry {
    static let typePrefix = "com.aadya.Fiscal.quick-add"

    static func update(using store: ExpenseStore) {
        let categories = store.mostUsedCategories().map { category in
            UIApplicationShortcutItem(
                type: "\(typePrefix).category",
                localizedTitle: category.name,
                localizedSubtitle: "Add expense",
                icon: UIApplicationShortcutIcon(systemImageName: category.symbol),
                userInfo: ["categoryID": category.id as NSString]
            )
        }
        // "Add Expense" is declared statically in Info.plist so Spotlight can
        // index it before the app has launched. These two dynamic items then
        // track the user's most-used categories.
        UIApplication.shared.shortcutItems = categories
        FiscalAppShortcuts.updateAppShortcutParameters()
    }
}

struct ExpenseCategoryEntity: AppEntity {
    static let defaultQuery = ExpenseCategoryEntityQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Expense Category")

    let id: String
    let name: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }
}

struct ExpenseCategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ExpenseCategoryEntity] {
        CategoryIntentData.categories()
            .filter { identifiers.contains($0.id) }
            .map(ExpenseCategoryEntity.init)
    }

    func suggestedEntities() async throws -> [ExpenseCategoryEntity] {
        CategoryIntentData.mostUsed(limit: 2).map(ExpenseCategoryEntity.init)
    }
}

private extension ExpenseCategoryEntity {
    init(_ category: ExpenseCategory) {
        id = category.id
        name = category.name
        symbol = category.symbol
    }
}

private enum CategoryIntentData {
    static func categories() -> [ExpenseCategory] {
        let url = documentsURL.appendingPathComponent("categories.json")
        guard let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([ExpenseCategory].self, from: data),
              !result.isEmpty else { return ExpenseCategory.defaults }
        return result
    }

    static func mostUsed(limit: Int) -> [ExpenseCategory] {
        let expenseURL = documentsURL.appendingPathComponent("expenses.json")
        let expenses = (try? Data(contentsOf: expenseURL))
            .flatMap { try? JSONDecoder().decode([Expense].self, from: $0) } ?? []
        let counts = Dictionary(grouping: expenses, by: \.categoryID).mapValues(\.count)
        let categories = categories()
        let categoryOrder = Dictionary(uniqueKeysWithValues: categories.enumerated().map { ($1.id, $0) })
        return categories
            .sorted {
                let left = counts[$0.id, default: 0]
                let right = counts[$1.id, default: 0]
                return left == right
                    ? categoryOrder[$0.id, default: 0] < categoryOrder[$1.id, default: 0]
                    : left > right
            }
            .prefix(limit)
            .map { $0 }
    }

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense"
    static let description = IntentDescription("Open Fiscal's new expense form.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickAddRouter.shared.open()
        return .result()
    }
}

struct AddExpenseForCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense for Category"
    static let description = IntentDescription("Open a new expense with a category already selected.")
    static let openAppWhenRun = true

    @Parameter(title: "Category")
    var category: ExpenseCategoryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add expense for \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickAddRouter.shared.open(categoryID: category.id)
        return .result()
    }
}

struct FiscalAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Log an expense in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: AddExpenseForCategoryIntent(),
            phrases: [
                "Add \(\.$category) expense in \(.applicationName)",
                "Log \(\.$category) expense in \(.applicationName)"
            ],
            shortTitle: "Add by Category",
            systemImageName: "tag.circle.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .teal }
}
