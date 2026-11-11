import UIKit

enum GradientRenderer {
    static func render(
        width: Int,
        height: Int,
        preset: GradientPreset,
        glowStrength: Float,
        vignetteStrength: Float,
        topLeftGlow: Bool
    ) -> UIImage {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            let topColor = UIColor(hex32: preset.baseTop)
            let bottomColor = UIColor(hex32: preset.baseBottom)
            let midColor = blend(topColor, bottomColor, t: 0.55)

            let baseColors = [topColor.cgColor, midColor.cgColor, bottomColor.cgColor] as CFArray
            let baseLocs: [CGFloat] = [0.0, 0.55, 1.0]
            if let baseGrad = CGGradient(colorsSpace: colorSpace, colors: baseColors, locations: baseLocs) {
                cg.drawLinearGradient(
                    baseGrad,
                    start: .zero,
                    end: CGPoint(x: size.width * 0.65, y: size.height),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }

            let gClamped = max(0, min(1, CGFloat(glowStrength)))
            if gClamped > 0.01 {
                let glowBase = UIColor(hex32: preset.glowColor)
                let core = glowBase.withAlphaComponent((145.0 / 255.0) * gClamped)
                let mid = glowBase.withAlphaComponent((54.0 / 255.0) * gClamped)
                let edge = glowBase.withAlphaComponent(0)
                let glowColors = [core.cgColor, mid.cgColor, edge.cgColor] as CFArray
                let glowLocs: [CGFloat] = [0.0, 0.48, 1.0]
                if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: glowLocs) {
                    let center = CGPoint(
                        x: topLeftGlow ? size.width * 0.30 : size.width * 0.72,
                        y: topLeftGlow ? size.height * 0.28 : size.height * 0.34
                    )
                    let radius = max(size.width, size.height) * 0.85
                    cg.drawRadialGradient(
                        glowGrad,
                        startCenter: center,
                        startRadius: 0,
                        endCenter: center,
                        endRadius: radius,
                        options: []
                    )
                }
            }

            let vClamped = max(0, min(1, CGFloat(vignetteStrength)))
            if vClamped > 0.01 {
                let edgeAlpha = (195.0 / 255.0) * vClamped
                let vigColors = [
                    UIColor.clear.cgColor,
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(edgeAlpha).cgColor
                ] as CFArray
                let vigLocs: [CGFloat] = [0.0, 0.45, 1.0]
                if let vigGrad = CGGradient(colorsSpace: colorSpace, colors: vigColors, locations: vigLocs) {
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
                    let radius = max(size.width, size.height) * 0.72
                    cg.drawRadialGradient(
                        vigGrad,
                        startCenter: center,
                        startRadius: 0,
                        endCenter: center,
                        endRadius: radius,
                        options: [.drawsAfterEndLocation]
                    )
                }
            }
        }
    }

    private static func blend(_ a: UIColor, _ b: UIColor, t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(
            red: ar * (1 - t) + br * t,
            green: ag * (1 - t) + bg * t,
            blue: ab * (1 - t) + bb * t,
            alpha: 1.0
        )
    }
}

