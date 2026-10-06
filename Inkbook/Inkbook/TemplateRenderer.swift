import UIKit

enum TemplateRenderer {
    static func image(for style: PageStyle, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(style, in: CGRect(origin: .zero, size: size))
        }
    }

    static func draw(_ style: PageStyle, in rect: CGRect) {
        UIColor.white.setFill()
        UIRectFill(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setStrokeColor(UIColor(red: 0.82, green: 0.85, blue: 0.90, alpha: 1).cgColor)
        context.setFillColor(UIColor(red: 0.76, green: 0.80, blue: 0.86, alpha: 1).cgColor)
        context.setLineWidth(0.65)

        switch style {
        case .blank, .pdf:
            break
        case .lined:
            var y: CGFloat = 56
            while y < rect.height - 24 {
                context.move(to: CGPoint(x: 28, y: y))
                context.addLine(to: CGPoint(x: rect.width - 28, y: y))
                y += 28
            }
            context.strokePath()
        case .grid:
            var x: CGFloat = 24
            while x < rect.width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: rect.height))
                x += 24
            }
            var y: CGFloat = 24
            while y < rect.height {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: rect.width, y: y))
                y += 24
            }
            context.strokePath()
        case .dotted:
            var y: CGFloat = 24
            while y < rect.height {
                var x: CGFloat = 24
                while x < rect.width {
                    context.fillEllipse(in: CGRect(x: x - 0.8, y: y - 0.8,
                                                   width: 1.6, height: 1.6))
                    x += 24
                }
                y += 24
            }
        }
        context.restoreGState()
    }
}
