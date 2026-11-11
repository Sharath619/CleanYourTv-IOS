import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

enum ImageProcessor {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func decodeDownsampled(data: Data, maxPixelSize: Int) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        if let cgThumb = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) {
            return UIImage(cgImage: cgThumb)
        }
        return UIImage(data: data)
    }

    static func gaussianBlur(image: UIImage, radius: CGFloat) -> UIImage {
        let r = max(0.5, radius)
        guard let cg = image.cgImage else { return image }
        let ciInput = CIImage(cgImage: cg)
        let clamped = ciInput.clampedToExtent()
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = clamped
        blur.radius = Float(r)
        guard let output = blur.outputImage?.cropped(to: ciInput.extent),
              let resultCg = ciContext.createCGImage(output, from: ciInput.extent) else {
            return image
        }
        return UIImage(cgImage: resultCg)
    }

    static func applyTone(image: UIImage, brightnessDelta: Float, contrastMult: Float) -> UIImage {
        if abs(brightnessDelta) < 0.005 && abs(contrastMult - 1.0) < 0.005 {
            return image
        }
        guard let cg = image.cgImage else { return image }
        let ciInput = CIImage(cgImage: cg)
        let filter = CIFilter.colorControls()
        filter.inputImage = ciInput
        filter.brightness = max(-0.45, min(0.45, brightnessDelta))
        filter.contrast = max(0.4, min(1.6, contrastMult))
        guard let output = filter.outputImage,
              let resultCg = ciContext.createCGImage(output, from: ciInput.extent) else {
            return image
        }
        return UIImage(cgImage: resultCg)
    }

    static func makeBlurredCover(from src: UIImage, outSize: CGSize = CGSize(width: 480, height: 270), radius: CGFloat = 22) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let smallRenderer = UIGraphicsImageRenderer(size: outSize, format: format)
        let small = smallRenderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: outSize))
            let sw = src.size.width
            let sh = src.size.height
            guard sw > 0, sh > 0 else { return }
            let scale = max(outSize.width / sw, outSize.height / sh)
            let dw = sw * scale
            let dh = sh * scale
            let rect = CGRect(
                x: (outSize.width - dw) / 2.0,
                y: (outSize.height - dh) / 2.0,
                width: dw,
                height: dh
            )
            src.draw(in: rect)
        }
        return gaussianBlur(image: small, radius: radius)
    }

    static func render16x9(
        source: UIImage,
        targetW: Int,
        targetH: Int,
        fitBlurMode: Bool,
        leftNorm: CGFloat,
        topNorm: CGFloat,
        scaleRelWidth: CGFloat,
        brightnessDelta: Float = 0,
        contrastMult: Float = 1,
        vignetteStrength: Float = 0
    ) -> UIImage {
        let toned = applyTone(image: source, brightnessDelta: brightnessDelta, contrastMult: contrastMult)
        let size = CGSize(width: targetW, height: targetH)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            if fitBlurMode {
                let bg = makeBlurredCover(from: toned, outSize: CGSize(width: 480, height: 270), radius: 24)
                bg.draw(in: CGRect(origin: .zero, size: size))
                UIColor.black.withAlphaComponent(0.25).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }

            let scale = scaleRelWidth * CGFloat(targetW)
            let tx = leftNorm * CGFloat(targetW)
            let ty = topNorm * CGFloat(targetH)
            let dw = toned.size.width * scale
            let dh = toned.size.height * scale
            toned.draw(in: CGRect(x: tx, y: ty, width: dw, height: dh))

            if vignetteStrength > 0.01 {
                let edgeAlpha = min(0.86, CGFloat(vignetteStrength) * 0.78)
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let colors = [
                    UIColor.clear.cgColor,
                    UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(edgeAlpha).cgColor
                ] as CFArray
                let locs: [CGFloat] = [0.0, 0.42, 1.0]
                if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locs) {
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
                    let radius = max(size.width, size.height) * 0.68
                    ctx.cgContext.drawRadialGradient(
                        gradient,
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

    static func jpegData(from image: UIImage, quality: CGFloat = 0.90) -> Data? {
        image.jpegData(compressionQuality: quality)
    }
}

