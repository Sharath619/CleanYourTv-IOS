import SwiftUI

struct TvGuideOverlayView: View {
    var restMode: Bool
    var columns: Int

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            guard w > 0, h > 0 else { return }

            if restMode {
                drawRestGuide(in: context, w: w, h: h)
            } else {
                drawHomeGuide(in: context, w: w, h: h, cols: max(4, min(7, columns)))
            }
        }
        .allowsHitTesting(false)
    }

    private func drawHomeGuide(in ctx: GraphicsContext, w: CGFloat, h: CGFloat, cols: Int) {
        let px = w * 0.048
        let py = h * 0.068

        let greetText = Text("GOOD EVENING")
            .font(Outfit.light(h * 0.036))
            .foregroundColor(Color.white.opacity(0.80))
        ctx.draw(greetText, at: CGPoint(x: px, y: py), anchor: .topLeading)

        let clockText = Text("7:45")
            .font(Outfit.light(h * 0.095))
            .foregroundColor(Color.white.opacity(0.94))
        ctx.draw(clockText, at: CGPoint(x: px, y: py + h * 0.044), anchor: .topLeading)

        // Top right utility pills
        let pillH = h * 0.068
        let pillW = w * 0.088
        let gap = w * 0.012
        var right = w - px
        for _ in 0..<3 {
            let rect = CGRect(x: right - pillW, y: py + h * 0.02, width: pillW, height: pillH)
            let path = Path(roundedRect: rect, cornerRadius: pillH / 2.0)
            ctx.fill(path, with: .color(Color.white.opacity(0.20)))
            ctx.stroke(path, with: .color(Color.white.opacity(0.33)), lineWidth: max(0.8, w * 0.002))
            right -= (pillW + gap)
        }

        // Bottom dock band & tiles
        let bandTop = h * 0.67
        ctx.fill(Path(CGRect(x: 0, y: bandTop, width: w, height: h - bandTop)),
                 with: .color(Color(hex: 0x080A0E, alpha: 0.22)))

        let tileGap = w * 0.018
        let availW = w - px * 2.0 - tileGap * CGFloat(cols - 1)
        let tileW = availW / CGFloat(cols)
        let tileH = tileW * 0.56
        let tileTop = h * 0.725
        let r = h * 0.022
        for i in 0..<cols {
            let x = px + CGFloat(i) * (tileW + tileGap)
            let tileRect = CGRect(x: x, y: tileTop, width: tileW, height: tileH)
            let tilePath = Path(roundedRect: tileRect, cornerRadius: r)
            ctx.fill(tilePath, with: .color(Color.white.opacity(0.16)))
            ctx.stroke(tilePath, with: .color(Color.white.opacity(0.27)), lineWidth: max(0.8, w * 0.002))
        }
    }

    private func drawRestGuide(in ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        let right = w * 0.93
        let bottom = h * 0.87

        let timeText = Text("5:03 PM")
            .font(Outfit.light(h * 0.16))
            .foregroundColor(Color.white.opacity(0.92))
        ctx.draw(timeText, at: CGPoint(x: right, y: bottom - h * 0.045), anchor: .bottomTrailing)

        let dateText = Text("WEDNESDAY 11 NOVEMBER")
            .font(Outfit.light(h * 0.036))
            .foregroundColor(Color.white.opacity(0.65))
        ctx.draw(dateText, at: CGPoint(x: right, y: bottom), anchor: .bottomTrailing)
    }
}

