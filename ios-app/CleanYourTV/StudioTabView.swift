import SwiftUI

struct StudioTabView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CleanYourTV Studio")
                        .font(Outfit.light(26))
                        .foregroundColor(Obsidian.textPrimary)

                    Text(subtitleText)
                        .font(Outfit.regular(13))
                        .foregroundColor(Obsidian.textSecondary)

                    if vm.connected, let st = vm.status {
                        Text("\(st.model) · CleanYourTV")
                            .font(Outfit.regular(11.5))
                            .foregroundColor(Obsidian.textTertiary)
                            .padding(.top, 2)
                    }
                }

                // Live 16:9 TV Preview Card
                ObsidianCard(radius: 18, padding: 12) {
                    VStack(spacing: 10) {
                        ZStack {
                            Color(hex: 0x050508)

                            if let img = vm.previewImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            } else {
                                Text(emptyPreviewMessage)
                                    .font(Outfit.regular(13))
                                    .foregroundColor(Obsidian.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(20)
                            }

                            Color.black.opacity(previewScrimOpacity)
                                .allowsHitTesting(false)

                            if vm.showPreviewGuide {
                                TvGuideOverlayView(
                                    restMode: vm.previewRestMode,
                                    columns: vm.status?.columns ?? 5
                                )
                            }
                        }
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Obsidian.outlineSubtle, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !vm.connected {
                                Haptics.tap()
                                vm.focusIpInConnectSheet = false
                                vm.showConnectSheet = true
                            }
                        }

                        // Segmented Preview Toggle
                        HStack(spacing: 3) {
                            previewSegmentButton("Home", active: !vm.previewRestMode) {
                                vm.setPreviewMode(restMode: false)
                            }
                            previewSegmentButton("Rest Mode", active: vm.previewRestMode) {
                                vm.setPreviewMode(restMode: true)
                            }
                            previewSegmentButton("TV UI Guide", active: vm.showPreviewGuide) {
                                vm.showPreviewGuide.toggle()
                            }
                        }
                        .padding(3)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Obsidian.surface2)
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Obsidian.outlineSubtle, lineWidth: 1))
                        )

                        // Metadata Footer + Rest Status Badge
                        HStack(spacing: 8) {
                            Text(previewMetaText)
                                .font(Outfit.regular(11.5))
                                .foregroundColor(Obsidian.textTertiary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(restBadgeText)
                                .font(Outfit.medium(11))
                                .foregroundColor(restBadgeColor)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Obsidian.surface2)
                                        .overlay(Capsule(style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                                )
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Primary Wallpaper Actions
                HStack(spacing: 8) {
                    Button("Pick Photo") {
                        Haptics.tap()
                        vm.launchPhotoPicker(target: .bothSharp)
                    }
                    .buttonStyle(PrimaryPillButton(height: 46))

                    Button("Gradient Studio") {
                        Haptics.tap()
                        vm.showGradientSheet = true
                    }
                    .buttonStyle(SecondaryPillButton(height: 46))
                }

                HStack(spacing: 8) {
                    Button("Browse Themes") {
                        Haptics.tap()
                        vm.selectedTab = 1
                    }
                    .buttonStyle(SecondaryPillButton(height: 42))

                    Button("Pure OLED Black") {
                        Haptics.tap()
                        vm.applyPureOledBlack()
                    }
                    .buttonStyle(SecondaryPillButton(height: 42, textColor: Obsidian.textSecondary))
                }

                // Rest Mode & TV Quick Actions
                ObsidianCard(radius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REST MODE & TV ACTIONS")
                            .font(Outfit.medium(11))
                            .foregroundColor(Obsidian.textTertiary)
                            .tracking(0.6)

                        HStack(spacing: 8) {
                            Button("Preview Rest") {
                                Haptics.tap()
                                vm.runAction(label: "Opening Rest Mode on TV...", reloadAfter: false) {
                                    try await vm.client.previewRestOnTv()
                                }
                            }
                            .buttonStyle(SecondaryPillButton(height: 40))

                            Button("Wake Home") {
                                Haptics.tap()
                                vm.runAction(label: "Waking TV Home...", reloadAfter: false) {
                                    try await vm.client.wakeHomeOnTv()
                                }
                            }
                            .buttonStyle(SecondaryPillButton(height: 40))
                        }

                        HStack(spacing: 6) {
                            SelectableChip(title: "Sharp Rest", isSelected: false, fullWidth: true, height: 36) {
                                vm.setRestSharp()
                            }
                            SelectableChip(title: "Blur Rest", isSelected: false, fullWidth: true, height: 36) {
                                vm.autoBlurCurrentForRest()
                            }
                            SelectableChip(title: "Custom Rest", isSelected: false, fullWidth: true, height: 36) {
                                vm.launchPhotoPicker(target: .restOnly)
                            }
                        }
                    }
                }

                // Recently Sent From Phone
                if !vm.recents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECENTLY SENT FROM PHONE")
                            .font(Outfit.medium(11))
                            .foregroundColor(Obsidian.textTertiary)
                            .tracking(0.6)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(vm.recents) { entry in
                                    recentCard(entry)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private func previewSegmentButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(Outfit.medium(12.5))
                .lineLimit(1)
                .foregroundColor(active ? Obsidian.textPrimary : Obsidian.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active ? Obsidian.surface3 : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(active ? Obsidian.rim : Color.clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func recentCard(_ entry: RecentEntry) -> some View {
        Button {
            Haptics.tap()
            vm.previewRecent = PreviewRecentItem(entry: entry)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                RecentThumbnailImage(fileURL: entry.fileURL)
                    .frame(width: 128, height: 72)
                    .background(Color(hex: 0x050507))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(entry.label)
                    .font(Outfit.medium(12))
                    .foregroundColor(Obsidian.textPrimary)
                    .lineLimit(1)
                    .frame(width: 124, alignment: .leading)
                    .padding(.horizontal, 2)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Obsidian.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var subtitleText: String {
        if vm.connecting {
            return "Checking TV at \(vm.savedHost)..."
        }
        if vm.connected, let st = vm.status {
            return "\(st.screenWidth)×\(st.screenHeight) · \(vm.savedHost)"
        }
        return "Wallpapers, Rest Mode & live TV layout"
    }

    private var previewScrimOpacity: Double {
        if vm.previewImage == nil { return 0 }
        if vm.previewRestMode { return 0.20 }
        return vm.dimPercent.rounded() / 100.0
    }

    private var previewMetaText: String {
        let dim = Int(vm.dimPercent.rounded())
        guard let st = vm.status else {
            return "Wallpaper · Dim \(dim)%"
        }
        if st.wallpaperEnabled {
            return "Dim \(dim)% · Glow \(st.ambientGlow ? "On" : "Off") · \(st.columns) cols"
        }
        return "Pure Black · Glow \(st.ambientGlow ? "On" : "Off") · \(st.columns) cols"
    }

    private var restBadgeText: String {
        guard let st = vm.status else { return "Rest: Sharp" }
        switch st.restMode {
        case "separate": return "Custom / Blurred"
        case "sharp": return "Sharp · Matches Home"
        default: return "OLED Black"
        }
    }

    private var restBadgeColor: Color {
        guard let st = vm.status else { return Obsidian.textPrimary }
        return st.restMode == "black" ? Obsidian.textSecondary : Obsidian.statusGreen
    }

    private var emptyPreviewMessage: String {
        guard vm.connected, let st = vm.status else {
            return "Tap Connect above or pick a wallpaper below"
        }
        if vm.previewRestMode {
            return "Rest Mode matches Home sharp\nTap Blur Rest or Custom Rest below to customize"
        }
        if !st.wallpaperEnabled {
            return "Wallpaper disabled (Pure OLED Black)"
        }
        if st.hasWallpaper {
            return "TV theme wallpaper active\nPick Photo, Gradient, or Themes below to replace"
        }
        return "No custom wallpaper set on TV yet"
    }
}

private struct RecentThumbnailImage: View {
    let fileURL: URL
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color(hex: 0x050507)
            }
        }
        .task(id: fileURL) {
            let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
                guard let data = try? Data(contentsOf: fileURL) else { return nil }
                return ImageProcessor.decodeDownsampled(data: data, maxPixelSize: 320)
            }.value
            self.uiImage = loaded
        }
    }
}

