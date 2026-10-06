import SwiftUI

@main
struct InkbookApp: App {
    @StateObject private var store = NotebookStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
        }
    }
}
