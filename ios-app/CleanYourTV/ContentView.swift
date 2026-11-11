import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Obsidian.bgTopGlow, Obsidian.bgRoot, Obsidian.bgRoot],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                if !vm.connected && !vm.connecting {
                    offlineBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Group {
                    switch vm.selectedTab {
                    case 0:
                        StudioTabView()
                    case 1:
                        ThemesTabView()
                    default:
                        ControlsTabView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomNavBar
            }

            if let toast = vm.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(Outfit.medium(13))
                        .foregroundColor(Obsidian.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Obsidian.surface2.opacity(0.96))
                                .overlay(Capsule(style: .continuous).stroke(Obsidian.rim, lineWidth: 1))
                                .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 78)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
            }

            if let busy = vm.busyMessage {
                ZStack {
                    Color.black.opacity(0.70)
                        .ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(Obsidian.accent)
                            .scaleEffect(1.2)
                        Text(busy)
                            .font(Outfit.medium(14))
                            .foregroundColor(Obsidian.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Obsidian.surface1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Obsidian.outline, lineWidth: 1)
                            )
                    )
                    .padding(32)
                }
            }
        }
        .photosPicker(isPresented: $vm.showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedPhotoItem = nil
                        vm.openCrop(with: data)
                    }
                } else {
                    await MainActor.run {
                        selectedPhotoItem = nil
                        vm.showToast("Could not open selected photo")
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showConnectSheet, onDismiss: {
            vm.prefoundTvs = []
        }) {
            TvConnectSheet(focusIp: vm.focusIpInConnectSheet, prefound: vm.prefoundTvs)
                .environmentObject(vm)
        }
        .sheet(isPresented: $vm.showGradientSheet) {
            GradientStudioSheet()
                .environmentObject(vm)
        }
        .sheet(item: $vm.previewTheme) { item in
            ThemePreviewSheet(mode: .preset(item.preset))
                .environmentObject(vm)
        }
        .sheet(item: $vm.previewRecent) { item in
            ThemePreviewSheet(mode: .recent(item.entry))
                .environmentObject(vm)
        }
        .sheet(isPresented: $vm.showOflSheet) {
            OflNoticeSheet(licenseText: vm.store.oflNoticeText())
        }
        .fullScreenCover(item: $vm.cropInput) { item in
            CropStudioView(item: item)
                .environmentObject(vm)
        }
        .alert("Delete saved wallpaper", isPresented: Binding(
            get: { vm.deleteConfirmItem != nil },
            set: { if !$0 { vm.deleteConfirmItem = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let target = vm.deleteConfirmItem {
                    vm.deleteConfirmItem = nil
                    vm.deleteSaved(target)
                }
            }
            Button("Cancel", role: .cancel) {
                vm.deleteConfirmItem = nil
            }
        } message: {
            if let item = vm.deleteConfirmItem {
                Text("Remove \"\(item.name)\" from your TV library?")
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.tap()
                vm.focusIpInConnectSheet = false
                vm.showConnectSheet = true
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(vm.connected ? Obsidian.statusGreen : (vm.connecting ? Obsidian.statusAmber : Obsidian.statusRed))
                        .frame(width: 8, height: 8)
                    Text(pillTitle)
                        .font(Outfit.medium(13))
                        .foregroundColor(Obsidian.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    Capsule(style: .continuous)
                        .fill(Obsidian.surface2)
                        .overlay(Capsule(style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                vm.focusIpInConnectSheet = true
                vm.showConnectSheet = true
            } label: {
                Text("TV IP")
                    .font(Outfit.medium(12.5))
                    .foregroundColor(Obsidian.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .fill(Obsidian.surface2)
                            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(Obsidian.outline, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                Task { await vm.scanForTvs() }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(Obsidian.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Obsidian.surface2)
                            .overlay(Circle().stroke(Obsidian.outline, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan Wi-Fi for TV")
        }
    }

    private var pillTitle: String {
        if vm.connecting {
            return "Connecting · \(vm.savedHost)"
        }
        if vm.connected, let st = vm.status {
            return "\(st.model) · Connected"
        }
        return "Offline · \(vm.savedHost)"
    }

    private var offlineBanner: some View {
        ObsidianCard(radius: 16, padding: 12, background: Obsidian.surface2) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TV not connected (\(vm.savedHost))")
                        .font(Outfit.medium(13))
                        .foregroundColor(Obsidian.statusAmber)
                    Text(offlineDiagnosticText)
                        .font(Outfit.regular(11.5))
                        .foregroundColor(Obsidian.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button {
                    Haptics.tap()
                    vm.focusIpInConnectSheet = false
                    vm.showConnectSheet = true
                } label: {
                    Text("Connect")
                        .font(Outfit.medium(12.5))
                        .foregroundColor(Obsidian.onPrimaryPill)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule(style: .continuous).fill(Obsidian.primaryPill))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var offlineDiagnosticText: String {
        if !vm.lastErrorMessage.isEmpty {
            return vm.lastErrorMessage
        }
        if vm.wifiSummary.wifiConnected {
            let ipLabel = vm.wifiSummary.wifiIp.isEmpty ? "\(vm.wifiSummary.prefix)*" : vm.wifiSummary.wifiIp
            return "iPhone Wi-Fi: \(ipLabel) · Tap Connect"
        }
        return "iPhone Wi-Fi appears off — connect to your TV's Wi-Fi"
    }

    private var bottomNavBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Obsidian.outlineSubtle)
                .frame(height: 1)

            HStack(spacing: 0) {
                navTab(idx: 0, icon: "tv", title: "Studio")
                navTab(idx: 1, icon: "photo.on.rectangle.angled", title: "Themes")
                navTab(idx: 2, icon: "slider.horizontal.3", title: "TV Look")
            }
            .padding(.top, 4)
            .padding(.bottom, 6)
            .frame(maxWidth: 620)
        }
        .frame(maxWidth: .infinity)
        .background(Obsidian.bgNav.ignoresSafeArea(.container, edges: .bottom))
    }

    private func navTab(idx: Int, icon: String, title: String) -> some View {
        let active = vm.selectedTab == idx
        return Button {
            Haptics.tap()
            vm.selectedTab = idx
            if idx == 1 && vm.selectedCategory == "Saved on TV" {
                Task { await vm.refreshSavedWallpapers() }
            }
        } label: {
            VStack(spacing: 4) {
                Capsule(style: .continuous)
                    .fill(active ? Obsidian.accent : Color.clear)
                    .frame(width: 26, height: 2.5)
                    .padding(.bottom, 2)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: active ? .medium : .regular))
                    .foregroundColor(active ? Obsidian.accent : Obsidian.textTertiary)
                    .frame(height: 20)

                Text(title)
                    .font(active ? Outfit.medium(11) : Outfit.regular(11))
                    .foregroundColor(active ? Obsidian.textPrimary : Obsidian.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

