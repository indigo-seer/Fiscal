import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var quickAddRouter: QuickAddRouter
    @State private var tab: AppTab = .add
    @State private var addRequest = 0
    @State private var canAddExpense = false

    @ViewBuilder
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                modernTabs
                    .tabBarMinimizeBehavior(.never)
                    .tabViewBottomAccessory {
                        AddExpenseAccessory(selection: $tab, addRequest: $addRequest, canSubmit: canAddExpense)
                    }
            } else {
                legacyTabs
            }
        }
        .onOpenURL { quickAddRouter.open(url: $0) }
        .onChange(of: quickAddRouter.request) { _, request in
            guard request != nil else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.16)) { tab = .add }
        }
        .task {
            if quickAddRouter.request != nil { tab = .add }
        }
    }

    @available(iOS 18.0, *)
    private var modernTabs: some View {
        TabView(selection: $tab) {
            Tab("Add", systemImage: "plus.circle.fill", value: .add) {
                AddExpenseView(tab: $tab, submitRequest: addRequest, canSubmit: $canAddExpense, quickAddRequest: quickAddRouter.request)
            }
            Tab("History", systemImage: "list.bullet.rectangle.fill", value: .history) {
                HistoryView()
            }
            Tab("Summary", systemImage: "chart.pie.fill", value: .summary) {
                SummaryView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .tint(.cyan)
        .sensoryFeedback(.selection, trigger: tab)
    }

    private var legacyTabs: some View {
        TabView(selection: $tab) {
            AddExpenseView(tab: $tab, submitRequest: addRequest, canSubmit: $canAddExpense, quickAddRequest: quickAddRouter.request)
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(AppTab.add)
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet.rectangle.fill") }
                .tag(AppTab.history)
            SummaryView()
                .tabItem { Label("Summary", systemImage: "chart.pie.fill") }
                .tag(AppTab.summary)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(.cyan)
        .sensoryFeedback(.selection, trigger: tab)
    }
}

@available(iOS 26.0, *)
struct AddExpenseAccessory: View {
    @Binding var selection: AppTab
    @Binding var addRequest: Int
    let canSubmit: Bool
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        Button {
            if selection == .add {
                addRequest += 1
            } else {
                withAnimation(.spring(duration: 0.4, bounce: 0.16)) { selection = .add }
            }
        } label: {
            if placement == .inline {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            } else {
                Label("Add Expense", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(selection == .add ? (canSubmit ? Color.cyan : Color.secondary) : Color.primary)
        .disabled(selection == .add && !canSubmit)
        .accessibilityHint(selection == .add ? "Saves the expense" : "Switches to the new expense form")
    }
}

enum AppTab: Hashable, CaseIterable {
    case add, history, summary, settings
    var title: String { switch self { case .add: "Add"; case .history: "History"; case .summary: "Summary"; case .settings: "Settings" } }
    var symbol: String { switch self { case .add: "plus"; case .history: "list.bullet.rectangle.fill"; case .summary: "chart.pie.fill"; case .settings: "gearshape.fill" } }
}

struct AddExpenseView: View {
    private enum Field { case amount, note }

    @EnvironmentObject private var store: ExpenseStore
    @Binding var tab: AppTab
    let submitRequest: Int
    @Binding var canSubmit: Bool
    let quickAddRequest: QuickAddRequest?
    @State private var amount = ""
    @State private var note = ""
    @State private var categoryID = "food"
    @State private var date = Date()
    @State private var saved = 0
    @FocusState private var focus: Field?

    private var value: Double? { Double(amount.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Amount", systemImage: "banknote").sectionLabel()

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(currencySymbol)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                            TextField("0", text: $amount)
                                .font(.system(size: 52, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .focused($focus, equals: .amount)
                        }
                        .contentShape(.rect)
                        .onTapGesture { focus = .amount }   // only the amount row, not the whole card

                        Divider()

                        Text("Note").font(.caption.weight(.semibold)).foregroundStyle(.secondary)

                        TextEditor(text: $note)
                            .focused($focus, equals: .note)
                            .frame(minHeight: 40, maxHeight: 64)
                            .scrollContentBackground(.hidden)
                            .overlay(alignment: .topLeading) {
                                if note.isEmpty {
                                    Text("What was this for?")
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    .padding(20)
                    .cardSurface()

                    VStack(alignment: .leading, spacing: 14) {
                        Label("Category", systemImage: "tag.fill").sectionLabel()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                            ForEach(store.categories) { item in
                                Button {
                                    withAnimation(.spring(duration: 0.32, bounce: 0.22)) { categoryID = item.id }
                                } label: {
                                    Label(item.name, systemImage: item.symbol)
                                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 11)
                                }
                                .buttonStyle(CategoryButtonStyle(selected: categoryID == item.id, tint: item.color))
                            }
                        }
                    }
                    .padding(20).cardSurface().sensoryFeedback(.selection, trigger: categoryID)

                    HStack {
                        Label("Date", systemImage: "calendar").font(.headline)
                        Spacer()
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date).labelsHidden()
                    }
                    .padding(20).cardSurface()

                }
                .padding(.horizontal, 20).padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
        }
        .sensoryFeedback(.success, trigger: saved)
        .onChange(of: submitRequest) { _, _ in addExpense() }
        .onChange(of: amount) { _, _ in canSubmit = (value ?? 0) > 0 }
        .onChange(of: quickAddRequest) { _, request in apply(request) }
        .onAppear {
            canSubmit = (value ?? 0) > 0
            apply(quickAddRequest)
        }
    }

    private func addExpense() {
        guard let value, value > 0 else { focus = .amount; return }
        focus = nil
        store.add(amount: value, note: note, categoryID: categoryID, date: date)
        withAnimation(.spring(duration: 0.4, bounce: 0.25)) { amount = ""; note = ""; saved += 1; tab = .history }
    }

    private func apply(_ request: QuickAddRequest?) {
        guard let requestedID = request?.categoryID,
              store.categories.contains(where: { $0.id == requestedID }) else { return }
        categoryID = requestedID
    }

    private var currencySymbol: String {
        if store.currencyCode == "INR" { return "₹" }
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = store.currencyCode
        return formatter.currencySymbol ?? store.currencyCode
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: ExpenseStore
    @State private var month = Date()
    @State private var query = ""
    @State private var categoryFilter: String? = nil
    @State private var sort: HistorySort = .newest
    @State private var editing: Expense?

    private var items: [Expense] {
        var result = store.expenses(in: month)
        if let categoryFilter { result = result.filter { $0.categoryID == categoryFilter } }
        if !query.isEmpty {
            result = result.filter {
                $0.note.localizedCaseInsensitiveContains(query) || store.category($0.categoryID).name.localizedCaseInsensitiveContains(query)
            }
        }
        switch sort {
        case .newest: result.sort { $0.date > $1.date }
        case .oldest: result.sort { $0.date < $1.date }
        case .highest: result.sort { $0.amount > $1.amount }
        case .lowest: result.sort { $0.amount < $1.amount }
        case .category: result.sort { store.category($0.categoryID).name < store.category($1.categoryID).name }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("No expenses", systemImage: "tray", description: Text("Expenses for this month will appear here."))
                } else {
                    List {
                        ForEach(groupedDays, id: \.day) { group in
                            Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                                ForEach(group.items) { expense in
                                    ExpenseRow(expense: expense).contentShape(.rect).onTapGesture { editing = expense }.swipeActions {
                                        Button(role: .destructive) { store.delete(expense) } label: { Label("Delete", systemImage: "trash") }
                                            .tint(.red)
                                        Button { editing = expense } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden)
                }
            }
            .background(AppBackground()).navigationTitle("History")
            .searchable(text: $query, prompt: "Search notes or categories")
            .safeAreaInset(edge: .top) {
                VStack(spacing: 10) {
                    MonthPicker(month: $month)
                    HStack {
                        Menu {
                            Button("All Categories") { categoryFilter = nil }
                            ForEach(store.categories) { item in Button(item.name) { categoryFilter = item.id } }
                        } label: {
                            Label(categoryFilter.map { store.category($0).name } ?? "All Categories", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        Spacer()
                        Menu {
                            Picker("Sort", selection: $sort) { ForEach(HistorySort.allCases) { Text($0.title).tag($0) } }
                        } label: { Label(sort.title, systemImage: "arrow.up.arrow.down") }
                    }.font(.subheadline.weight(.semibold))
                }.padding(.horizontal, 24).padding(.bottom, 8)
            }
            .sheet(item: $editing) { EditExpenseView(expense: $0) }
        }
    }

    private var groupedDays: [(day: Date, items: [Expense])] {
        let groups = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }
}

struct ExpenseRow: View {
    @EnvironmentObject private var store: ExpenseStore
    let expense: Expense
    private var category: ExpenseCategory { store.category(expense.categoryID) }
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: category.symbol).font(.headline).foregroundStyle(category.color)
                .frame(width: 42, height: 42).background(category.color.opacity(0.14), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name).font(.headline)
                Text(expense.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                if !expense.note.isEmpty { Text(expense.note).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer()
            Text(store.amountText(expense.amount)).font(.headline.monospacedDigit())
        }
        .padding(.vertical, 4).listRowBackground(Color.clear)
    }
}

struct SummaryView: View {
    @EnvironmentObject private var store: ExpenseStore
    @State private var period: SummaryPeriod = .monthly
    @State private var periodDate = Date()
    private var items: [Expense] {
        switch period {
        case .monthly:
            store.expenses(in: periodDate)
        case .yearly:
            store.expenses.filter { Calendar.current.isDate($0.date, equalTo: periodDate, toGranularity: .year) }
        }
    }
    private var total: Double { items.reduce(0) { $0 + $1.amount } }
    private var breakdown: [(ExpenseCategory, Double)] {
        Dictionary(grouping: items, by: \.categoryID)
            .map { (store.category($0.key), $0.value.reduce(0) { $0 + $1.amount }) }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Summary period", selection: $period) {
                        ForEach(SummaryPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    SummaryPeriodPicker(period: period, date: $periodDate)
                    VStack(spacing: 8) {
                        Text("Total Spent").font(.subheadline).foregroundStyle(.secondary)
                        Text(store.amountText(total)).font(.system(size: 42, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: total))
                        Text("\(items.count) transaction\(items.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 28).cardSurface()

                    if breakdown.isEmpty {
                        ContentUnavailableView("Nothing to summarize", systemImage: "chart.pie", description: Text("Add an expense to see your breakdown."))
                            .frame(minHeight: 280).cardSurface()
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Breakdown").font(.headline)
                            DonutChart(values: breakdown, total: total).frame(height: 220)
                            ForEach(breakdown, id: \.0) { category, amount in
                                HStack {
                                    Circle().fill(category.color).frame(width: 9, height: 9)
                                    Label(category.name, systemImage: category.symbol)
                                    Spacer(); Text(store.amountText(amount)).monospacedDigit()
                                    Text((amount / total).formatted(.percent.precision(.fractionLength(0))))
                                        .foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                                }.font(.subheadline)
                            }
                        }
                        .padding(20).cardSurface()
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 28)
            }
            .background(AppBackground()).navigationTitle("Summary")
            .animation(.spring(duration: 0.45, bounce: 0.12), value: periodDate)
            .animation(.spring(duration: 0.35, bounce: 0.1), value: period)
        }
    }
}

enum SummaryPeriod: String, CaseIterable, Identifiable {
    case monthly, yearly
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct SummaryPeriodPicker: View {
    let period: SummaryPeriod
    @Binding var date: Date

    var body: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 0) {
                if period == .monthly {
                    Text(date.formatted(.dateTime.month(.wide))).font(.headline)
                    Text(date.formatted(.dateTime.year())).font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text(date.formatted(.dateTime.year())).font(.headline)
                    Text("Yearly overview").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .contentTransition(.numericText())
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .disabled(isCurrentPeriod)
        }
        .sensoryFeedback(.selection, trigger: date)
    }

    private var isCurrentPeriod: Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: period == .monthly ? .month : .year)
    }

    private func move(_ offset: Int) {
        let component: Calendar.Component = period == .monthly ? .month : .year
        withAnimation(.spring(duration: 0.35, bounce: 0.12)) {
            date = Calendar.current.date(byAdding: component, value: offset, to: date) ?? date
        }
    }
}

struct DonutChart: View {
    let values: [(ExpenseCategory, Double)]; let total: Double
    var body: some View {
        ZStack {
            ForEach(Array(values.enumerated()), id: \.element.0) { index, item in
                Circle().trim(from: edge(index), to: edge(index + 1))
                    .stroke(item.0.color, style: StrokeStyle(lineWidth: 38, lineCap: .butt)).rotationEffect(.degrees(-90))
            }
            VStack(spacing: 4) {
                Text("\(values.count)").font(.system(size: 34, weight: .bold, design: .rounded))
                Text(values.count == 1 ? "category" : "categories").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(22).animation(.spring(duration: 0.6, bounce: 0.15), value: total)
    }
    private func edge(_ index: Int) -> Double { total > 0 ? values.prefix(index).reduce(0) { $0 + $1.1 } / total : 0 }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ExpenseStore
    @State private var confirmDelete = false
    @State private var manageCategories = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Data") {
                    Picker("Currency", systemImage: "banknote", selection: $store.currencyCode) {
                        ForEach(["INR", "USD", "EUR", "GBP", "JPY"], id: \.self) { Text($0).tag($0) }
                    }
                    ShareLink(item: store.csv, subject: Text("Expense export"), message: Text("CSV export from Fiscal")) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    LabeledContent("Stored locally", value: "\(store.expenses.count) items")
                    Button { manageCategories = true } label: { Label("Manage Categories", systemImage: "tag") }
                }
                Section("Privacy") {
                    Label("No account", systemImage: "person.crop.circle.badge.xmark")
                    Label("No analytics or cloud sync", systemImage: "icloud.slash")
                    Label("Data stays on this iPhone", systemImage: "iphone.gen3.lock")
                }
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete All Data", systemImage: "trash") }
                } footer: { Text("This permanently removes every saved expense from this device.") }
                Section("About") { LabeledContent("App", value: "Fiscal"); LabeledContent("Version", value: "1.0") }
            }
            .scrollContentBackground(.hidden).background(AppBackground()).navigationTitle("Settings")
            .confirmationDialog("Delete all expense data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { store.deleteAll() }; Button("Cancel", role: .cancel) {}
            } message: { Text("This cannot be undone.") }
            .sheet(isPresented: $manageCategories) { CategoryManagerView() }
        }
    }
}

enum HistorySort: String, CaseIterable, Identifiable {
    case newest, oldest, highest, lowest, category
    var id: String { rawValue }
    var title: String {
        switch self { case .newest: "Newest"; case .oldest: "Oldest"; case .highest: "Highest Amount"; case .lowest: "Lowest Amount"; case .category: "Category" }
    }
}

struct EditExpenseView: View {
    @EnvironmentObject private var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    let expense: Expense
    @State private var amount: String
    @State private var note: String
    @State private var categoryID: String
    @State private var date: Date
    @State private var confirmDelete = false

    init(expense: Expense) {
        self.expense = expense
        _amount = State(initialValue: expense.amount.formatted(.number.grouping(.never).precision(.fractionLength(0...2))))
        _note = State(initialValue: expense.note); _categoryID = State(initialValue: expense.categoryID); _date = State(initialValue: expense.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    Picker("Category", selection: $categoryID) { ForEach(store.categories) { Label($0.name, systemImage: $0.symbol).tag($0.id) } }
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                Section("Note") { TextEditor(text: $note).frame(minHeight: 120) }
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete Expense", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Expense").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value > 0 else { return }
                        store.update(expense, amount: value, note: note, categoryID: categoryID, date: date); dismiss()
                    }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Delete this expense?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Expense", role: .destructive) { store.delete(expense); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
}

struct CategoryManagerView: View {
    @EnvironmentObject private var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var symbol = "tag.fill"
    @State private var color = "cyan"
    @State private var renaming: ExpenseCategory?
    @State private var renameText = ""
    private let symbols = ["tag.fill", "cup.and.saucer.fill", "airplane", "house.fill", "graduationcap.fill", "gamecontroller.fill"]
    private let colors = ["cyan", "blue", "green", "orange", "pink", "purple", "red", "yellow"]

    var body: some View {
        NavigationStack {
            List {
                Section("New Category") {
                    TextField("Name", text: $newName)
                    Picker("Icon", selection: $symbol) { ForEach(symbols, id: \.self) { Image(systemName: $0).tag($0) } }
                    Picker("Color", selection: $color) { ForEach(colors, id: \.self) { Text($0.capitalized).tag($0) } }
                    Button("Add Category", systemImage: "plus") { store.addCategory(name: newName, symbol: symbol, colorName: color); newName = "" }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section("Categories") {
                    ForEach(store.categories) { item in
                        Label(item.name, systemImage: item.symbol).foregroundStyle(item.color)
                            .swipeActions(edge: .leading) {
                                Button { renaming = item; renameText = item.name } label: { Label("Rename", systemImage: "pencil") }.tint(.blue)
                            }
                            .swipeActions {
                                if item.id != "other" { Button(role: .destructive) { store.deleteCategory(item) } label: { Label("Delete", systemImage: "trash") } }
                            }
                    }
                }
            }
            .navigationTitle("Categories").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Rename Category", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $renameText)
                Button("Save") { if let renaming { store.renameCategory(renaming, to: renameText) }; renaming = nil }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
        }
    }
}

struct MonthPicker: View {
    @Binding var month: Date
    var body: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 0) {
                Text(month.formatted(.dateTime.month(.wide))).font(.headline)
                Text(month.formatted(.dateTime.year())).font(.caption2).foregroundStyle(.secondary)
            }.contentTransition(.opacity)
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .disabled(Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month))
        }
        .sensoryFeedback(.selection, trigger: month)
    }
    private func move(_ offset: Int) {
        withAnimation(.spring(duration: 0.35, bounce: 0.12)) { month = Calendar.current.date(byAdding: .month, value: offset, to: month) ?? month }
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [.cyan.opacity(0.12), .clear], center: .topTrailing, startRadius: 20, endRadius: 420)
            RadialGradient(colors: [.purple.opacity(0.08), .clear], center: .bottomLeading, startRadius: 30, endRadius: 440)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct CategoryButtonStyle: ButtonStyle {
    let selected: Bool; let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(selected ? .white : .secondary)
            .background(selected ? tint.opacity(0.32) : Color.white.opacity(0.07), in: .capsule)
            .overlay(Capsule().stroke(selected ? tint.opacity(0.7) : .clear, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.22, bounce: 0.28), value: configuration.isPressed)
    }
}

extension View {
    func sectionLabel() -> some View { font(.subheadline.weight(.medium)).foregroundStyle(.secondary) }

    // Glass is applied as a background so it never sits in the hit-testing path of
    // the interactive content (TextField / TextEditor) inside the card.
    @ViewBuilder func cardSurface() -> some View {
        if #available(iOS 26.0, *) {
            self.background {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .allowsHitTesting(false)
            }
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    @ViewBuilder func prominentGlassButton(enabled: Bool) -> some View {
        if #available(iOS 26.0, *) { self.buttonStyle(.glassProminent).tint(enabled ? .cyan : .gray) }
        else { self.buttonStyle(.borderedProminent).tint(enabled ? .cyan : .gray).clipShape(.capsule) }
    }
}

extension ExpenseCategory {
    var color: Color {
        switch colorName {
        case "orange": .orange
        case "blue": .blue
        case "green": .green
        case "pink": .pink
        case "yellow": .yellow
        case "red": .red
        case "purple": .purple
        case "cyan": .cyan
        default: .gray
        }
    }
}
