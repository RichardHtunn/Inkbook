import SwiftUI
import PencilKit

enum DrawingTool: String, CaseIterable, Identifiable {
    case pen, pencil, marker, highlighter, eraser, lasso

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen: return "Pen"
        case .pencil: return "Pencil"
        case .marker: return "Marker"
        case .highlighter: return "Highlighter"
        case .eraser: return "Eraser"
        case .lasso: return "Lasso"
        }
    }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "paintbrush.pointed"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        }
    }

    func pencilKitTool(color: UIColor, width: CGFloat) -> PKTool {
        switch self {
        case .pen:
            return PKInkingTool(.pen, color: color, width: width)
        case .pencil:
            return PKInkingTool(.pencil, color: color, width: width)
        case .marker:
            return PKInkingTool(.marker, color: color, width: max(width * 2, 6))
        case .highlighter:
            return PKInkingTool(.marker,
                                color: color.withAlphaComponent(0.35),
                                width: max(width * 5, 18))
        case .eraser:
            return PKEraserTool(.vector)
        case .lasso:
            return PKLassoTool()
        }
    }
}

final class DrawingController: ObservableObject {
    weak var canvas: PKCanvasView?

    func undo() { canvas?.undoManager?.undo() }
    func redo() { canvas?.undoManager?.redo() }
    func clear() { canvas?.drawing = PKDrawing() }
}

struct DrawingCanvas: UIViewRepresentable {
    let drawing: PKDrawing
    let size: CGSize
    let tool: DrawingTool
    let color: Color
    let width: CGFloat
    let fingerDrawing: Bool
    let controller: DrawingController
    let onChange: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView(frame: CGRect(origin: .zero, size: size))
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.isScrollEnabled = false
        canvas.alwaysBounceHorizontal = false
        canvas.alwaysBounceVertical = false
        canvas.contentSize = size
        canvas.drawing = drawing
        canvas.tool = tool.pencilKitTool(color: UIColor(color), width: width)
        canvas.drawingPolicy = fingerDrawing ? .anyInput : .pencilOnly
        canvas.delegate = context.coordinator
        controller.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.tool = tool.pencilKitTool(color: UIColor(color), width: width)
        canvas.drawingPolicy = fingerDrawing ? .anyInput : .pencilOnly
        context.coordinator.onChange = onChange
        controller.canvas = canvas
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onChange: (PKDrawing) -> Void

        init(onChange: @escaping (PKDrawing) -> Void) {
            self.onChange = onChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing)
        }
    }
}
