import SwiftUI

struct ThemesTabView: View {
    @EnvironmentObject private var vm: AppViewModel

    private let categories = [
        "All", "Favorites", "Featured", "Abstract", "Scenic", "Minimal", "Saved on TV"
    ]

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Themes")
                    .font(Outfit.light(26))
                    .foregroundColor(Obsidian.textPrimary)
                Spacer()
                Button {
                    Haptics.tap()
                    vm.showGradientSheet = true
                } label: {
                    Text("Gradient")
                        .font(Outfit.medium(12.5))
                        .foregroundColor(Obsidian.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(Obsidian.surface2)
                                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.tap()
                    vm.launchPhotoPicker(target: .bothSharp)
                } label: {
                    Text("+ Photo")
                        .font(Outfit.medium(12.5))
                        .foregroundColor(Obsidian.onPrimaryPill)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Capsule(style: .continuous).fill(Obsidian.primaryPill))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        SelectableChip(title: cat, isSelected: vm.selectedCategory == cat, height: 34) {
                            vm.selectCategory(cat)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if vm.selectedCategory == "Saved on TV" {
                if vm.savedItems.isEmpty {
                    emptyView(
                        title: vm.connected ? "No saved wallpapers on TV" : "Connect TV to view saved wallpapers",
                        hint: vm.connected
                            ? "Check 'Save to TV' when applying a photo or gradient"
                            : "Tap Connect above once your TV is reachable"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(vm.savedItems) { item in
                                savedCard(item)
                                    .onAppear { vm.ensureSavedThumbnail(name: item.name) }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                let items = vm.filteredPresets()
                if items.isEmpty {
                    let isFav = vm.selectedCategory == "Favorites"
                    emptyView(
                        title: isFav ? "No favorites yet" : "No items in \(vm.selectedCategory)",
                        hint: isFav ? "Tap ★ on any theme card to save it here" : "Try another category above"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(items) { preset in
                                presetCard(preset)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    private func emptyView(title: String, hint: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Text(title)
                .font(Outfit.medium(15))
                .foregroundColor(Obsidian.textPrimary)
                .multilineTextAlignment(.center)
            Text(hint)
                .font(Outfit.regular(12.5))
                .foregroundColor(Obsidian.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func presetCard(_ p: ThemePreset) -> some View {
        let isFav = vm.favoriteIds.contains(p.id)
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if !p.wallpaper || p.asset.isEmpty {
                        Color.black
                    } else if let thumb = vm.presetThumbnails[p.id] {
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(hex: 0x050507)
                    }
                }
                .frame(height: 98)
                .frame(maxWidth: .infinity)
                .clipped()

                Button {
                    Haptics.tap()
                    vm.toggleFavorite(p.id)
                } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isFav ? Obsidian.statusAmber : Obsidian.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(Color(hex: 0x14141A, alpha: 0.86))
                                .overlay(Circle().stroke(Obsidian.outline, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .padding(7)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(p.title)
                    .font(Outfit.medium(13))
                    .foregroundColor(Obsidian.textPrimary)
                    .lineLimit(1)

                Text(p.wallpaper ? "\(p.category) · Dim \(p.dim)%" : "Pure Black · Glow \(p.ambientGlow ? "On" : "Off")")
                    .font(Outfit.regular(11))
                    .foregroundColor(Obsidian.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Obsidian.surface1)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            if !p.wallpaper || p.asset.isEmpty {
                vm.applyPureOledBlack()
            } else {
                vm.previewTheme = PreviewThemeItem(preset: p)
            }
        }
    }

    private func savedCard(_ item: SavedWallpaperItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumb = vm.savedThumbnails[item.name] {
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color(hex: 0x050507)
                            ProgressView().tint(Obsidian.textTertiary)
                        }
                    }
                }
                .frame(height: 98)
                .frame(maxWidth: .infinity)
                .clipped()

                Button {
                    Haptics.tap()
                    vm.deleteConfirmItem = item
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Obsidian.statusRed)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(Color(hex: 0x14141A, alpha: 0.86))
                                .overlay(Circle().stroke(Obsidian.outline, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .padding(7)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cleanTitle(item.name))
                    .font(Outfit.medium(13))
                    .foregroundColor(Obsidian.textPrimary)
                    .lineLimit(1)

                Text(item.size > 0 ? "Saved on TV · \(max(1, item.size / 1024)) KB" : "Saved on TV")
                    .font(Outfit.regular(11))
                    .foregroundColor(Obsidian.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Obsidian.surface1)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            vm.selectSaved(item)
        }
    }

    private func cleanTitle(_ name: String) -> String {
        if let dot = name.lastIndex(of: "."), dot > name.startIndex {
            return String(name[..<dot])
        }
        return name
    }
}

