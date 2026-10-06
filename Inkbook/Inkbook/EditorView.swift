import SwiftUI
import PencilKit
import PDFKit
import UIKit

struct EditorView: View {
    @EnvironmentObject private var store: NotebookStore
    @StateObject private var controller = DrawingController()

    let notebookID: UUID
    @State private var selectedPageID: UUID?
    @State private var selectedTool: DrawingTool = .pen
    @State private var inkColor: Color = .black
    @State private var inkWidth: Double = 3
    @State private var fingerDrawing = false
    @State private var shareItem: PDFShareItem?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let notebook = store.notebook(notebookID),
               let page = selectedPage(in: notebook) {
                HStack(spacing: 0) {
                    pageStrip(notebook)
                        .frame(width: 132)
                        .background(Color(uiColor: .secondarySystemBackground))
                    Divider()
                    VStack(spacing: 0) {
                        HStack {
                            Text("Page \(pageNumber(page, in: notebook)) of \(notebook.pages.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !fingerDrawing {
                                Label("Apple Pencil", systemImage: "pencil.tip")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)

                        pageCanvas(page, in: notebook)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        toolPalette
                    }
                }
                .navigationTitle(notebook.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            ForEach(PageStyle.templates) { style in
                                Button(style.title) {
                                    store.addPage(to: notebookID, style: style)
                                    selectedPageID = store.notebook(notebookID)?.pages.last?.id
                                }
                            }
                        } label: {
                            Label("Add page", systemImage: "plus.rectangle.on.rectangle")
                        }
                        Menu {
                            Toggle("Draw with finger", isOn: $fingerDrawing)
                            Button("Clear current page", systemImage: "trash") {
                                controller.clear()
                            }
                            Button("Toggle ruler", systemImage: "ruler") {
                                controller.canvas?.isRulerActive.toggle()
                            }
                        } label: {
                            Label("More options", systemImage: "ellipsis.circle")
                        }
                        Button("Export PDF", systemImage: "square.and.arrow.up") {
                            do {
                                shareItem = PDFShareItem(url: try store.exportPDF(notebook))
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Notebook unavailable", systemImage: "book.closed")
            }
        }
        .sheet(item: $shareItem) { item in
            ActivitySheet(url: item.url)
        }
        .alert("Could not export PDF", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func selectedPage(in notebook: Notebook) -> NotebookPage? {
        notebook.pages.first { $0.id == selectedPageID } ?? notebook.pages.first
    }

    private func pageNumber(_ page: NotebookPage, in notebook: Notebook) -> Int {
        (notebook.pages.firstIndex(of: page) ?? 0) + 1
    }

    private func pageStrip(_ notebook: Notebook) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(notebook.pages) { page in
                    Button {
                        selectedPageID = page.id
                    } label: {
                        VStack(spacing: 5) {
                            pageBackground(page, in: notebook)
                                .frame(width: 78, height: 104)
                                .clipped()
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(selectedPage(in: notebook)?.id == page.id
                                                ? Color.indigo : Color.gray.opacity(0.3),
                                                lineWidth: selectedPage(in: notebook)?.id == page.id
                                                ? 3 : 1)
                                }
                            Text("\(pageNumber(page, in: notebook))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if notebook.pages.count > 1 {
                            Button("Delete page", systemImage: "trash", role: .destructive) {
                                if selectedPageID == page.id {
                                    selectedPageID = notebook.pages.first { $0.id != page.id }?.id
                                }
                                store.deletePage(page.id, from: notebookID)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 18)
        }
    }

    private func pageCanvas(_ page: NotebookPage, in notebook: Notebook) -> some View {
        let size = CGSize(width: CGFloat(page.width), height: CGFloat(page.height))
        return ScrollView([.horizontal, .vertical]) {
            ZStack {
                pageBackground(page, in: notebook)
                DrawingCanvas(
                    drawing: store.drawing(notebookID: notebookID, pageID: page.id),
                    size: size,
                    tool: selectedTool,
                    color: inkColor,
                    width: CGFloat(inkWidth),
                    fingerDrawing: fingerDrawing,
                    controller: controller
                ) { drawing in
                    store.saveDrawing(drawing, notebookID: notebookID, pageID: page.id)
                }
                .id(page.id)
            }
            .frame(width: size.width, height: size.height)
            .background(.white)
            .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
            .padding(32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder
    private func pageBackground(_ page: NotebookPage, in notebook: Notebook) -> some View {
        let size = CGSize(width: CGFloat(page.width), height: CGFloat(page.height))
        if let index = page.pdfPageIndex,
           let pdfPage = store.pdfDocument(for: notebook)?.page(at: index) {
            Image(uiImage: pdfPage.thumbnail(
                of: CGSize(width: size.width * 2, height: size.height * 2),
                for: .mediaBox
            ))
            .resizable()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(uiImage: TemplateRenderer.image(for: page.style, size: size))
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var toolPalette: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(DrawingTool.allCases) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tool.symbol)
                                .font(.title3)
                                .frame(width: 34, height: 30)
                            Text(tool.title)
                                .font(.caption2)
                        }
                        .frame(width: 70, height: 55)
                        .foregroundColor(selectedTool == tool ? .white : .primary)
                        .background(selectedTool == tool ? Color.indigo : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tool.title)
                }

                Divider().frame(height: 36)
                ColorPicker("Ink color", selection: $inkColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44)
                    .accessibilityLabel("Ink color")
                HStack {
                    Image(systemName: "line.diagonal")
                    Slider(value: $inkWidth, in: 1...20)
                        .frame(width: 100)
                }
                .accessibilityLabel("Stroke width")
                Divider().frame(height: 36)
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    controller.undo()
                }
                Button("Redo", systemImage: "arrow.uturn.forward") {
                    controller.redo()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }
}

private struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
