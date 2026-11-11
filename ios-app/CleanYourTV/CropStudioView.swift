import SwiftUI

struct CropStudioView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let item: CropInputItem

    @State private var sourceImage: UIImage?
    @State private var blurredBackdrop: UIImage?
    @State private var blurPreviewImage: UIImage?

    @State private var fitBlurMode: Bool = false
    @State private var showGuide: Bool = true
    @State private var uhd4k: Bool = false
    @State private var showToneDrawer: Bool = false
    @State private var selectedTarget: CropTarget
    @State private var saveToCollection: Bool = true

    // Tone sliders matching Android: 50 = neutral (brightness/contrast), 0 = no vignette
    @State private var activeToneChannel: Int = 0
    @State private var brightnessPct: Double = 50
    @State private var contrastPct: Double = 50
    @State private var vignettePct: Double = 0

    // Rest blur controls matching Android seekRestBlur (4..100, default 65)
    @State private var restBlurRadius: Double = 65
    @State private var previewingBlur: Bool = false

    // Interactive transform state
    @State private var cropSize: CGSize = CGSize(width: 320, height: 180)
    @State private var baseScale: CGFloat = 1.0
    @State private var baseTx: CGFloat = 0.0
    @State private var baseTy: CGFloat = 0.0
    @State private var liveScale: CGFloat = 1.0
    @State private var liveDrag: CGSize = .zero
    @State private var transformInitialized: Bool = false

    @State private var sending: Bool = false

    init(item: CropInputItem) {
        self.item = item
        _selectedTarget = State(initialValue: item.initialTarget)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                GeometryReader { geo in
                    let pad: CGFloat = 16
                    let availW = max(1, geo.size.width - pad * 2)
                    let availH = max(1, geo.size.height - pad * 2)
                    let cw = (availW * 9.0 / 16.0 > availH) ? (availH * 16.0 / 9.0) : availW
                    let ch = cw * 9.0 / 16.0

                    ZStack {
                        Color.black

                        cropCanvas(cw: cw, ch: ch)
                            .frame(width: cw, height: ch)
                            .clipped()
                            .overlay(
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        updateViewport(CGSize(width: cw, height: ch))
                    }
                    .onChange(of: geo.size) { _ in
                        updateViewport(CGSize(width: cw, height: ch))
                    }
                }

                bottomControls
            }

            if sourceImage == nil {
                ZStack {
                    Color.black.opacity(0.6)
                    ProgressView("Loading photo...")
                        .font(Outfit.medium(13.5))
                        .foregroundColor(Obsidian.textPrimary)
                        .tint(Obsidian.accent)
                }
                .ignoresSafeArea()
            }
        }
        .task {
            await loadSourceImage()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Obsidian.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Obsidian.surface2)
                            .overlay(Circle().stroke(Obsidian.outline, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("Frame Photo")
                    .font(Outfit.medium(16))
                    .foregroundColor(Obsidian.textPrimary)
                Text("Pinch & drag inside 16:9 TV frame")
                    .font(Outfit.regular(11.5))
                    .foregroundColor(Obsidian.textSecondary)
            }
            Spacer()

            SelectableChip(title: "TV Guide", isSelected: showGuide, height: 34) {
                showGuide.toggle()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func cropCanvas(cw: CGFloat, ch: CGFloat) -> some View {
        let brightnessDelta = Float((brightnessPct - 50) * 0.007)
        let contrastMult = Float(0.5 + contrastPct * 0.01)
        let vignette = Float(vignettePct / 100.0)

        ZStack {
            if previewingBlur, let blurImg = blurPreviewImage {
                Image(uiImage: blurImg)
                    .resizable()
                    .frame(width: cw, height: ch)
            } else if let img = sourceImage {
                if fitBlurMode, let bg = blurredBackdrop {
                    Image(uiImage: bg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cw, height: ch)
                        .brightness(Double(brightnessDelta))
                        .contrast(Double(contrastMult))
                        .clipped()

                    Color.black.opacity(0.25)
                }

                let t = effectiveTransform(for: img, cw: cw, ch: ch)
                let dw = img.size.width * t.scale
                let dh = img.size.height * t.scale

                Image(uiImage: img)
                    .resizable()
                    .frame(width: dw, height: dh)
                    .brightness(Double(brightnessDelta))
                    .contrast(Double(contrastMult))
                    .position(x: t.tx + dw * 0.5, y: t.ty + dh * 0.5)

                if vignette > 0.01 {
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.42),
                            .init(color: .black.opacity(min(0.86, Double(vignette) * 0.78)), location: 1.0)
                        ]),
                        center: UnitPoint(x: 0.5, y: 0.48),
                        startRadius: 0,
                        endRadius: max(cw, ch) * 0.68
                    )
                    .allowsHitTesting(false)
                }
            }

            if showGuide {
                TvGuideOverlayView(
                    restMode: selectedTarget == .restOnly || previewingBlur,
                    columns: item.columns
                )
            }
        }
        .frame(width: cw, height: ch, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard !previewingBlur else { return }
                    liveDrag = value.translation
                }
                .onEnded { value in
                    guard !previewingBlur, let img = sourceImage else { return }
                    let sNow = clampedScale(baseScale * liveScale, image: img, cw: cw, ch: ch)
                    let clamped = clampOffset(
                        tx: baseTx + value.translation.width,
                        ty: baseTy + value.translation.height,
                        scale: sNow,
                        image: img,
                        cw: cw,
                        ch: ch
                    )
                    baseTx = clamped.x
                    baseTy = clamped.y
                    liveDrag = .zero
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { factor in
                    guard !previewingBlur else { return }
                    liveScale = factor
                }
                .onEnded { factor in
                    guard !previewingBlur, let img = sourceImage else { return }
                    let nextScale = clampedScale(baseScale * factor, image: img, cw: cw, ch: ch)
                    let applied = baseScale > 0 ? (nextScale / baseScale) : 1.0
                    let nextTx = cw * 0.5 - (cw * 0.5 - baseTx) * applied
                    let nextTy = ch * 0.5 - (ch * 0.5 - baseTy) * applied
                    let clamped = clampOffset(tx: nextTx, ty: nextTy, scale: nextScale, image: img, cw: cw, ch: ch)
                    baseScale = nextScale
                    baseTx = clamped.x
                    baseTy = clamped.y
                    liveScale = 1.0
                }
        )
        .onTapGesture(count: 2) {
            guard !previewingBlur else { return }
            Haptics.tap()
            resetTransform(cw: cw, ch: ch)
        }
    }

    private var bottomControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Equal-width 4-button dock matching Android v2.2
            HStack(spacing: 6) {
                SelectableChip(title: "Fill 16:9", isSelected: !fitBlurMode, fullWidth: true, height: 36) {
                    stopBlurPreview()
                    fitBlurMode = false
                    resetTransform(cw: cropSize.width, ch: cropSize.height)
                }
                SelectableChip(title: "Fit + Blur", isSelected: fitBlurMode, fullWidth: true, height: 36) {
                    stopBlurPreview()
                    fitBlurMode = true
                    resetTransform(cw: cropSize.width, ch: cropSize.height)
                }
                SelectableChip(title: uhd4k ? "4K UHD" : "1080p", isSelected: uhd4k, fullWidth: true, height: 36) {
                    uhd4k.toggle()
                }
                SelectableChip(title: "Tone", isSelected: showToneDrawer, fullWidth: true, height: 36) {
                    showToneDrawer.toggle()
                }
            }

            if showToneDrawer {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        SelectableChip(title: "Bright", isSelected: activeToneChannel == 0, fullWidth: true, height: 32) {
                            activeToneChannel = 0
                        }
                        SelectableChip(title: "Contrast", isSelected: activeToneChannel == 1, fullWidth: true, height: 32) {
                            activeToneChannel = 1
                        }
                        SelectableChip(title: "Vignette", isSelected: activeToneChannel == 2, fullWidth: true, height: 32) {
                            activeToneChannel = 2
                        }
                        SelectableChip(title: "Reset", isSelected: false, height: 32) {
                            brightnessPct = 50
                            contrastPct = 50
                            vignettePct = 0
                            refreshBlurPreviewIfNeeded()
                        }
                    }

                    HStack(spacing: 10) {
                        Slider(
                            value: currentToneBinding,
                            in: 0...100,
                            step: 1,
                            onEditingChanged: { editing in
                                if !editing { refreshBlurPreviewIfNeeded() }
                            }
                        )
                        .tint(Obsidian.accent)

                        Text(toneValueLabel)
                            .font(Outfit.medium(12.5))
                            .foregroundColor(Obsidian.accent)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Obsidian.surface1)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                )
            }

            // Target selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CropTarget.allCases) { target in
                        SelectableChip(title: target.shortLabel, isSelected: selectedTarget == target, height: 34) {
                            selectedTarget = target
                            if target != .bothBlur { stopBlurPreview() }
                        }
                    }
                }
            }

            if selectedTarget == .bothBlur {
                HStack(spacing: 10) {
                    Text("Rest Blur: \(Int(restBlurRadius))")
                        .font(Outfit.medium(12))
                        .foregroundColor(Obsidian.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 92, alignment: .leading)

                    Slider(
                        value: $restBlurRadius,
                        in: 4...100,
                        step: 1,
                        onEditingChanged: { editing in
                            if !editing && previewingBlur {
                                refreshBlurPreviewIfNeeded()
                            }
                        }
                    )
                    .tint(Obsidian.accent)

                    SelectableChip(
                        title: previewingBlur ? "Blurring" : "Preview Blur",
                        isSelected: previewingBlur,
                        height: 32
                    ) {
                        if previewingBlur {
                            stopBlurPreview()
                        } else {
                            previewingBlur = true
                            refreshBlurPreviewIfNeeded()
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Obsidian.surface1)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                )
            }

            HStack(spacing: 12) {
                if selectedTarget != .restOnly {
                    Toggle(isOn: $saveToCollection) {
                        Text("Save to TV")
                            .font(Outfit.regular(13))
                            .foregroundColor(Obsidian.textSecondary)
                    }
                    .toggleStyle(.switch)
                    .tint(Obsidian.accent)
                    .fixedSize()
                }

                Button(sending ? "Sending to TV..." : "Put on TV") {
                    Haptics.tap()
                    applyToTv()
                }
                .disabled(sending || sourceImage == nil)
                .buttonStyle(PrimaryPillButton(height: 46))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(Obsidian.bgNav.ignoresSafeArea(.container, edges: .bottom))
    }

    private var currentToneBinding: Binding<Double> {
        Binding(
            get: {
                switch activeToneChannel {
                case 0: return brightnessPct
                case 1: return contrastPct
                default: return vignettePct
                }
            },
            set: { val in
                switch activeToneChannel {
                case 0: brightnessPct = val
                case 1: contrastPct = val
                default: vignettePct = val
                }
            }
        )
    }

    private var toneValueLabel: String {
        if activeToneChannel == 0 {
            let pct = Int(((brightnessPct - 50) * 0.7).rounded())
            return "\(pct > 0 ? "+" : "")\(pct)%"
        }
        if activeToneChannel == 1 {
            let contrast = 0.5 + contrastPct * 0.01
            return String(format: "%.1f×", contrast)
        }
        return "\(Int(vignettePct))%"
    }

    private func loadSourceImage() async {
        let raw = item.data
        let result = await Task.detached(priority: .userInitiated) { () -> (UIImage, UIImage)? in
            guard let img = ImageProcessor.decodeDownsampled(data: raw, maxPixelSize: 2400) else {
                return nil
            }
            let bg = ImageProcessor.makeBlurredCover(from: img, outSize: CGSize(width: 640, height: 360), radius: 22)
            return (img, bg)
        }.value

        if let (img, bg) = result {
            self.sourceImage = img
            self.blurredBackdrop = bg
            self.fitBlurMode = img.size.height > img.size.width * 1.05
            self.transformInitialized = false
            resetTransform(cw: cropSize.width, ch: cropSize.height)
        } else {
            vm.showToast("Could not decode selected photo")
            dismiss()
        }
    }

    private func updateViewport(_ newSize: CGSize) {
        guard newSize.width > 1, newSize.height > 1 else { return }
        cropSize = newSize
        if !transformInitialized && sourceImage != nil {
            resetTransform(cw: newSize.width, ch: newSize.height)
        }
    }

    private func resetTransform(cw: CGFloat, ch: CGFloat) {
        guard let img = sourceImage, cw > 1, ch > 1 else { return }
        let bw = max(1, img.size.width)
        let bh = max(1, img.size.height)
        let coverScale = max(cw / bw, ch / bh)
        let fitScale = min(cw / bw, ch / bh)
        let s = fitBlurMode ? fitScale : coverScale
        let tx = (cw - bw * s) * 0.5
        let ty = (ch - bh * s) * 0.5
        baseScale = s
        baseTx = tx
        baseTy = ty
        liveScale = 1.0
        liveDrag = .zero
        transformInitialized = true
    }

    private func scaleBounds(for image: UIImage, cw: CGFloat, ch: CGFloat) -> (min: CGFloat, max: CGFloat) {
        let bw = max(1, image.size.width)
        let bh = max(1, image.size.height)
        let coverScale = max(cw / bw, ch / bh)
        let fitScale = min(cw / bw, ch / bh)
        if fitBlurMode {
            return (fitScale * 0.7, max(coverScale * 4.0, 4.0))
        }
        return (coverScale, max(coverScale * 5.0, 5.0))
    }

    private func clampedScale(_ candidate: CGFloat, image: UIImage, cw: CGFloat, ch: CGFloat) -> CGFloat {
        let b = scaleBounds(for: image, cw: cw, ch: ch)
        return max(b.min, min(b.max, candidate))
    }

    private func clampOffset(tx: CGFloat, ty: CGFloat, scale: CGFloat, image: UIImage, cw: CGFloat, ch: CGFloat) -> CGPoint {
        let dw = image.size.width * scale
        let dh = image.size.height * scale
        var nx = tx
        var ny = ty
        if !fitBlurMode {
            if nx > 0 { nx = 0 }
            if nx + dw < cw { nx = cw - dw }
            if ny > 0 { ny = 0 }
            if ny + dh < ch { ny = ch - dh }
        } else {
            if dw <= cw {
                nx = max(0, min(nx, cw - dw))
            } else {
                if nx > 0 { nx = 0 }
                if nx + dw < cw { nx = cw - dw }
            }
            if dh <= ch {
                ny = max(0, min(ny, ch - dh))
            } else {
                if ny > 0 { ny = 0 }
                if ny + dh < ch { ny = ch - dh }
            }
        }
        return CGPoint(x: nx, y: ny)
    }

    private func effectiveTransform(for image: UIImage, cw: CGFloat, ch: CGFloat) -> (scale: CGFloat, tx: CGFloat, ty: CGFloat) {
        let s = clampedScale(baseScale * liveScale, image: image, cw: cw, ch: ch)
        let applied = baseScale > 0 ? (s / baseScale) : 1.0
        let rawTx = cw * 0.5 - (cw * 0.5 - baseTx) * applied + liveDrag.width
        let rawTy = ch * 0.5 - (ch * 0.5 - baseTy) * applied + liveDrag.height
        let pt = clampOffset(tx: rawTx, ty: rawTy, scale: s, image: image, cw: cw, ch: ch)
        return (s, pt.x, pt.y)
    }

    private func stopBlurPreview() {
        previewingBlur = false
        blurPreviewImage = nil
    }

    private func refreshBlurPreviewIfNeeded() {
        guard previewingBlur, let src = sourceImage, cropSize.width > 1 else { return }
        let t = effectiveTransform(for: src, cw: cropSize.width, ch: cropSize.height)
        let leftNorm = t.tx / cropSize.width
        let topNorm = t.ty / cropSize.height
        let scaleRelW = t.scale / cropSize.width
        let fit = fitBlurMode
        let bright = Float((brightnessPct - 50) * 0.007)
        let cont = Float(0.5 + contrastPct * 0.01)
        let vig = Float(vignettePct / 100.0)
        // Map Android StackBlur(radius * 0.55) on 480px preview to CoreImage Gaussian sigma (~r / sqrt(6))
        let r = max(1.0, restBlurRadius * 0.22)

        Task {
            let blurred = await Task.detached(priority: .userInitiated) { () -> UIImage in
                let small = ImageProcessor.render16x9(
                    source: src,
                    targetW: 480,
                    targetH: 270,
                    fitBlurMode: fit,
                    leftNorm: leftNorm,
                    topNorm: topNorm,
                    scaleRelWidth: scaleRelW,
                    brightnessDelta: bright,
                    contrastMult: cont,
                    vignetteStrength: vig
                )
                return ImageProcessor.gaussianBlur(image: small, radius: r)
            }.value
            if self.previewingBlur {
                self.blurPreviewImage = blurred
            }
        }
    }

    private func applyToTv() {
        guard !sending, let src = sourceImage, cropSize.width > 1 else { return }
        sending = true

        let t = effectiveTransform(for: src, cw: cropSize.width, ch: cropSize.height)
        let leftNorm = t.tx / cropSize.width
        let topNorm = t.ty / cropSize.height
        let scaleRelW = t.scale / cropSize.width
        let fit = fitBlurMode
        let target = selectedTarget
        let targetW = uhd4k ? 3840 : 1920
        let targetH = uhd4k ? 2160 : 1080
        let use4k = uhd4k
        let rawData = item.data
        let brightness = Float((brightnessPct - 50) * 0.007)
        let contrast = Float(0.5 + contrastPct * 0.01)
        let vignette = Float(vignettePct / 100.0)
        // Map Android StackBlur(radius * 0.7) on 960px image to CoreImage Gaussian sigma (~r / sqrt(6))
        let blurR = CGFloat(max(1.5, (restBlurRadius * 0.28).rounded()))
        let saveName = (saveToCollection && target != .restOnly)
            ? "photo_\(Int64(Date().timeIntervalSince1970 * 1000)).jpg"
            : nil

        Task {
            do {
                let (mainJpeg, restJpeg) = try await Task.detached(priority: .userInitiated) { () -> (Data, Data?) in
                    var renderSrc = src
                    var effScale = scaleRelW
                    if use4k, let hi = ImageProcessor.decodeDownsampled(data: rawData, maxPixelSize: 3840),
                       hi.size.width > src.size.width {
                        effScale = scaleRelW * (src.size.width / hi.size.width)
                        renderSrc = hi
                    }
                    let rendered = ImageProcessor.render16x9(
                        source: renderSrc,
                        targetW: targetW,
                        targetH: targetH,
                        fitBlurMode: fit,
                        leftNorm: leftNorm,
                        topNorm: topNorm,
                        scaleRelWidth: effScale,
                        brightnessDelta: brightness,
                        contrastMult: contrast,
                        vignetteStrength: vignette
                    )
                    guard let mainData = ImageProcessor.jpegData(from: rendered, quality: use4k ? 0.90 : 0.92) else {
                        throw TvClientError.message("Failed encoding JPEG")
                    }
                    var blurData: Data? = nil
                    if target == .bothBlur {
                        let down = ImageProcessor.decodeDownsampled(data: mainData, maxPixelSize: 960) ?? rendered
                        let blurred = ImageProcessor.gaussianBlur(image: down, radius: blurR)
                        blurData = ImageProcessor.jpegData(from: blurred, quality: 0.88)
                    }
                    return (mainData, blurData)
                }.value

                vm.store.saveRecent(label: "Photo", jpegData: mainJpeg)
                vm.refreshRecents()

                switch target {
                case .restOnly:
                    try await vm.client.uploadRestWallpaper(jpegData: mainJpeg)
                case .bothBlur:
                    try await vm.client.uploadHomeWallpaper(jpegData: mainJpeg, saveName: saveName, restMode: "keep")
                    if let restJpeg {
                        try await vm.client.uploadRestWallpaper(jpegData: restJpeg)
                    }
                case .bothSharp:
                    try await vm.client.uploadHomeWallpaper(jpegData: mainJpeg, saveName: saveName, restMode: "sharp")
                case .homeOnly:
                    try await vm.client.uploadHomeWallpaper(jpegData: mainJpeg, saveName: saveName, restMode: "keep")
                }

                vm.showToast("TV wallpaper updated!")
                dismiss()
                await vm.connectAndSync(autoScanOnFail: false)
            } catch {
                sending = false
                vm.showToast("Send failed: \(error.localizedDescription)", duration: 3.2)
            }
        }
    }
}

