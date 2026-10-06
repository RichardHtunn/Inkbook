import Foundation
import SwiftUI
import PencilKit
import PDFKit
import UIKit

@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var notebooks: [Notebook] = []

    private let fileManager = FileManager.default
    private let root: URL
    private let indexURL: URL

    init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = documents.appendingPathComponent("Inkbook", isDirectory: true)
        indexURL = root.appendingPathComponent("notebooks.json")
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([Notebook].self, from: data) {
            notebooks = decoded
        }
    }

    @discardableResult
    func createNotebook(title: String = "Untitled notebook", style: PageStyle = .lined) -> UUID {
        let notebook = Notebook(title: title, pages: [NotebookPage(style: style)])
        notebooks.insert(notebook, at: 0)
        persistIndex()
        return notebook.id
    }

    func notebook(_ id: UUID) -> Notebook? {
        notebooks.first { $0.id == id }
    }

    func rename(_ id: UUID, to title: String) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notebooks[index].title = trimmed
        touch(index)
    }

    func delete(_ id: UUID) {
        notebooks.removeAll { $0.id == id }
        try? fileManager.removeItem(at: folder(for: id))
        persistIndex()
    }

    func addPage(to id: UUID, style: PageStyle) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { return }
        notebooks[index].pages.append(NotebookPage(style: style))
        touch(index)
    }

    func deletePage(_ pageID: UUID, from notebookID: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }),
              notebooks[index].pages.count > 1 else { return }
        notebooks[index].pages.removeAll { $0.id == pageID }
        try? fileManager.removeItem(at: drawingURL(notebookID: notebookID, pageID: pageID))
        touch(index)
    }

    func movePage(in notebookID: UUID, from offsets: IndexSet, to destination: Int) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        notebooks[index].pages.move(fromOffsets: offsets, toOffset: destination)
        touch(index)
    }

    func drawing(notebookID: UUID, pageID: UUID) -> PKDrawing {
        guard let data = try? Data(contentsOf: drawingURL(notebookID: notebookID, pageID: pageID)),
              let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
        return drawing
    }

    func saveDrawing(_ drawing: PKDrawing, notebookID: UUID, pageID: UUID) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebookID }) else { return }
        let folder = folder(for: notebookID)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? drawing.dataRepresentation().write(
            to: drawingURL(notebookID: notebookID, pageID: pageID), options: .atomic
        )
        notebooks[index].modifiedAt = .now
        persistIndex()
    }

    func pdfDocument(for notebook: Notebook) -> PDFDocument? {
        guard let name = notebook.importedPDF else { return nil }
        return PDFDocument(url: folder(for: notebook.id).appendingPathComponent(name))
    }

    func importPDF(from source: URL) throws -> UUID {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        guard let pdf = PDFDocument(url: source), pdf.pageCount > 0 else {
            throw NotebookError.invalidPDF
        }

        let id = UUID()
        let folder = folder(for: id)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("source.pdf")
        do {
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            try? fileManager.removeItem(at: folder)
            throw error
        }

        let pages = (0..<pdf.pageCount).compactMap { pageIndex -> NotebookPage? in
            guard let page = pdf.page(at: pageIndex) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            return NotebookPage(style: .pdf, width: Double(bounds.width),
                                height: Double(bounds.height), pdfPageIndex: pageIndex)
        }
        guard !pages.isEmpty else {
            try? fileManager.removeItem(at: folder)
            throw NotebookError.invalidPDF
        }
        let title = source.deletingPathExtension().lastPathComponent
        notebooks.insert(Notebook(id: id, title: title, pages: pages,
                                  importedPDF: "source.pdf"), at: 0)
        persistIndex()
        return id
    }

    func exportPDF(_ notebook: Notebook) throws -> URL {
        let safeTitle = notebook.title.replacingOccurrences(
            of: "[^A-Za-z0-9 _-]", with: "", options: .regularExpression
        )
        let output = fileManager.temporaryDirectory
            .appendingPathComponent("\(safeTitle.isEmpty ? "Notebook" : safeTitle)-\(notebook.id).pdf")
        let sourcePDF = pdfDocument(for: notebook)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try renderer.writePDF(to: output) { context in
            for page in notebook.pages {
                let rect = CGRect(x: 0, y: 0, width: page.width, height: page.height)
                context.beginPage(withBounds: rect, pageInfo: [:])
                if let index = page.pdfPageIndex, let pdfPage = sourcePDF?.page(at: index) {
                    context.cgContext.saveGState()
                    context.cgContext.translateBy(x: 0, y: rect.height)
                    context.cgContext.scaleBy(x: 1, y: -1)
                    pdfPage.draw(with: .mediaBox, to: context.cgContext)
                    context.cgContext.restoreGState()
                } else {
                    TemplateRenderer.draw(page.style, in: rect)
                }
                let ink = drawing(notebookID: notebook.id, pageID: page.id)
                ink.image(from: rect, scale: 2).draw(in: rect)
            }
        }
        return output
    }

    private func folder(for notebookID: UUID) -> URL {
        root.appendingPathComponent(notebookID.uuidString, isDirectory: true)
    }

    private func drawingURL(notebookID: UUID, pageID: UUID) -> URL {
        folder(for: notebookID).appendingPathComponent("\(pageID.uuidString).drawing")
    }

    private func touch(_ index: Int) {
        notebooks[index].modifiedAt = .now
        persistIndex()
    }

    private func persistIndex() {
        guard let data = try? JSONEncoder().encode(notebooks) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

enum NotebookError: LocalizedError {
    case invalidPDF
    var errorDescription: String? { "This file is not a readable PDF." }
}
