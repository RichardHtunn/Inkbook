import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: NotebookStore
    @State private var path: [UUID] = []
    @State private var searchText = ""
    @State private var showImporter = false
    @State private var renaming: Notebook?
    @State private var errorMessage: String?

    private var filteredNotebooks: [Notebook] {
        let sorted = store.notebooks.sorted { $0.modifiedAt > $1.modifiedAt }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.notebooks.isEmpty {
                    ContentUnavailableView(
                        "Your notebook library",
                        systemImage: "pencil.and.scribble",
                        description: Text("Create a notebook or import a PDF to start writing.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredNotebooks) { notebook in
                        Button {
                            path.append(notebook.id)
                        } label: {
                            notebookRow(notebook)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                renaming = notebook
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                store.delete(notebook.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inkbook")
            .searchable(text: $searchText, prompt: "Search notebooks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import PDF", systemImage: "square.and.arrow.down") {
                        showImporter = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(PageStyle.templates) { style in
                            Button(style.title) {
                                path.append(store.createNotebook(style: style))
                            }
                        }
                    } label: {
                        Label("New notebook", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                EditorView(notebookID: id)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
                do {
                    let url = try result.get()
                    path.append(try store.importPDF(from: url))
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(item: $renaming) { notebook in
                RenameNotebookSheet(notebook: notebook) { title in
                    store.rename(notebook.id, to: title)
                }
            }
            .alert("Could not import PDF", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func notebookRow(_ notebook: Notebook) -> some View {
        HStack(spacing: 16) {
            Image(systemName: notebook.importedPDF == nil ? "book.closed.fill" : "doc.richtext.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 52, height: 62)
                .background(.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(notebook.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(notebook.pages.count) page\(notebook.pages.count == 1 ? "" : "s") · Edited \(notebook.modifiedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
    }
}

private struct RenameNotebookSheet: View {
    @Environment(\.dismiss) private var dismiss
    let notebook: Notebook
    let onSave: (String) -> Void
    @State private var title: String

    init(notebook: Notebook, onSave: @escaping (String) -> Void) {
        self.notebook = notebook
        self.onSave = onSave
        _title = State(initialValue: notebook.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Notebook name", text: $title)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("Rename notebook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
