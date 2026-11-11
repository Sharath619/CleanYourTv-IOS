import SwiftUI

struct ThemePreviewSheet: View {
    enum Mode {
        case preset(ThemePreset)
        case recent(RecentEntry)
    }

    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @State private var fullImage: UIImage?

    var body: some View {
        ZStack {
            Obsidian.bgRoot.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text(titleText)
                            .font(Outfit.medium(19))
                            .foregroundColor(Obsidian.textPrimary)
                        Spacer()

                        if case .preset(let p) = mode {
                            let isFav = vm.favoriteIds.contains(p.id)
                            Button {
                                Haptics.tap()
                                vm.toggleFavorite(p.id)
                            } label: {
                                Image(systemName: isFav ? "star.fill" : "star")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(isFav ? Obsidian.statusAmber : Obsidian.textSecondary)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle()
                                            .fill(Obsidian.surface2)
                                            .overlay(Circle().stroke(Obsidian.outline, lineWidth: 1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            Haptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Obsidian.textSecondary)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(Obsidian.surface2)
                                        .overlay(Circle().stroke(Obsidian.outline, lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Text(subtitleText)
                        .font(Outfit.regular(12.5))
                        .foregroundColor(Obsidian.textSecondary)

                    ZStack {
                        Color(hex: 0x050507)
                        if let fullImage {
                            Image(uiImage: fullImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        TvGuideOverlayView(restMode: false, columns: vm.status?.columns ?? 5)
                    }
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Obsidian.outline, lineWidth: 1)
                    )

                    VStack(spacing: 8) {
                        Button("Set Wallpaper") {
                            Haptics.tap()
                            dismiss()
                            switch mode {
                            case .preset(let p):
                                vm.applyPreset(p, includeStyle: false, restOnly: false)
                            case .recent(let r):
                                vm.applyRecent(r, restOnly: false)
                            }
                        }
                        .buttonStyle(PrimaryPillButton(height: 46))

                        if case .preset(let p) = mode {
                            Button("Apply Theme & Colors") {
                                Haptics.tap()
                                dismiss()
                                vm.applyPreset(p, includeStyle: true, restOnly: false)
                            }
                            .buttonStyle(SecondaryPillButton(height: 44))
                        }

                        Button("Set Rest Mode Only") {
                            Haptics.tap()
                            dismiss()
                            switch mode {
                            case .preset(let p):
                                vm.applyPreset(p, includeStyle: false, restOnly: true)
                            case .recent(let r):
                                vm.applyRecent(r, restOnly: true)
                            }
                        }
                        .buttonStyle(SecondaryPillButton(height: 44, textColor: Obsidian.textSecondary))
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .task {
            let store = vm.store
            let currentMode = mode
            let loaded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                switch currentMode {
                case .preset(let p):
                    return store.loadAssetImage(p.asset, maxPixel: 1280)
                case .recent(let entry):
                    guard let data = try? Data(contentsOf: entry.fileURL) else { return nil }
                    return ImageProcessor.decodeDownsampled(data: data, maxPixelSize: 960)
                }
            }.value
            self.fullImage = loaded
        }
    }

    private var titleText: String {
        switch mode {
        case .preset(let p): return p.title
        case .recent(let r): return r.label
        }
    }

    private var subtitleText: String {
        switch mode {
        case .preset(let p):
            return "Recommended: Dim \(p.dim)% · App Glow \(p.ambientGlow ? "On" : "Off")"
        case .recent:
            return "Saved in your recent creations on iPhone"
        }
    }
}

struct OflNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let licenseText: String

    var body: some View {
        ZStack {
            Obsidian.bgRoot.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Typography & Open-Source Notice")
                        .font(Outfit.medium(18))
                        .foregroundColor(Obsidian.textPrimary)
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .font(Outfit.medium(14))
                    .foregroundColor(Obsidian.accent)
                }

                ScrollView {
                    Text("Design language inspired by CleanYourTV.\n\nOutfit Font License:\n\n\(licenseText)")
                        .font(Outfit.regular(12.5))
                        .foregroundColor(Obsidian.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}
