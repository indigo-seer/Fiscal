import AppIntents
import SwiftUI

@main
struct FiscalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ExpenseStore()
    @StateObject private var quickAddRouter = QuickAddRouter.shared

    init() {
        FiscalAppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(quickAddRouter)
                .preferredColorScheme(.dark)
                .task { QuickActionRegistry.update(using: store) }
                .onChange(of: store.expenses) { _, _ in QuickActionRegistry.update(using: store) }
                .onChange(of: store.categories) { _, _ in QuickActionRegistry.update(using: store) }
        }
    }
}
