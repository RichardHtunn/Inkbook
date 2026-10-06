import Foundation

enum PageStyle: String, Codable, CaseIterable, Identifiable {
    case blank, lined, grid, dotted, pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: return "Blank"
        case .lined: return "Lined"
        case .grid: return "Grid"
        case .dotted: return "Dotted"
        case .pdf: return "PDF"
        }
    }

    static var templates: [PageStyle] { [.blank, .lined, .grid, .dotted] }
}

struct NotebookPage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var style: PageStyle = .blank
    var width: Double = 612
    var height: Double = 792
    var pdfPageIndex: Int? = nil
}

struct Notebook: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var modifiedAt: Date = .now
    var pages: [NotebookPage]
    var importedPDF: String? = nil
}
