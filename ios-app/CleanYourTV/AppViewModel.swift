import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    let client = TvClient()
    let store = LocalStore()

    @Published var selectedTab: Int = 0
    @Published var connected: Bool = false
    @Published var connecting: Bool = true
    @Published var status: TvStatus?
    @Published var lastErrorMessage: String = ""
    @Published var wifiSummary: WifiInfoSummary = TvClient.inspectWifi()

    @Published var previewRestMode: Bool = false
    @Published var showPreviewGuide: Bool = true
    @Published var previewImage: UIImage?

    @Published var presets: [ThemePreset] = []
    @Published var savedItems: [SavedWallpaperItem] = []
    @Published var savedThumbnails: [String: UIImage] = [:]
    @Published var presetThumbnails: [String: UIImage] = [:]
    @Published var favoriteIds: Set<String> = []
    @Published var selectedCategory: String = "All"
    @Published var recents: [RecentEntry] = []

    // Controls synced with TV
    @Published var wallpaperEnabled: Bool = true
    @Published var ambientGlow: Bool = false
    @Published var dimPercent: Double = 25

    // Navigation & overlays
    @Published var busyMessage: String?
    @Published var toastMessage: String?
    @Published var showConnectSheet: Bool = false
    @Published var focusIpInConnectSheet: Bool = false
    @Published var prefoundTvs: [DiscoveredTv] = []
    @Published var showGradientSheet: Bool = false
    @Published var showOflSheet: Bool = false

    // Gallery Picker + Cropper
    @Published var showPhotoPicker: Bool = false
    @Published var pendingCropTarget: CropTarget = .bothSharp
    @Published var cropInput: CropInputItem?

    // Preview / Confirm dialogs
    @Published var previewTheme: PreviewThemeItem?
    @Published var previewRecent: PreviewRecentItem?
    @Published var deleteConfirmItem: SavedWallpaperItem?

    private var toastHideTask: Task<Void, Never>?
    private var loadingSavedThumbNames = Set<String>()

    var savedHost: String { client.host }
    var savedPort: Int { client.port }
    var baseUrl: String { client.baseUrl }

    init() {
        self.presets = store.loadPresets()
        self.favoriteIds = store.favoriteIds()
        self.recents = store.listRecents()
        Task {
            await loadPresetThumbnails()
            await connectAndSync(autoScanOnFail: true)
        }
    }

    func loadPresetThumbnails() async {
        let items = presets
        let store = self.store
        let loaded = await Task.detached(priority: .utility) { () -> [String: UIImage] in
            var map: [String: UIImage] = [:]
            for p in items where p.wallpaper && !p.asset.isEmpty {
                if let img = store.loadAssetImage(p.asset, maxPixel: 480) {
                    map[p.id] = img
                }
            }
            return map
        }.value
        self.presetThumbnails = loaded
    }

    func refreshRecents() {
        self.recents = store.listRecents()
    }

    func connectAndSync(autoScanOnFail: Bool) async {
        connecting = true
        wifiSummary = TvClient.inspectWifi()
        do {
            let st = try await client.fetchStatus()
            applyConnectedStatus(st)
            await refreshPreviewBitmap()
            await refreshSavedWallpapers()
        } catch {
            if autoScanOnFail {
                let found = await client.discoverTvs()
                if let first = found.first {
                    client.setEndpoint(host: first.host, port: first.port)
                    if let st = try? await client.fetchStatus() {
                        applyConnectedStatus(st)
                        await refreshPreviewBitmap()
                        await refreshSavedWallpapers()
                        return
                    }
                }
            }
            applyOfflineState(errorDetail: client.lastError)
        }
    }

    private func applyConnectedStatus(_ st: TvStatus) {
        self.connecting = false
        self.connected = true
        self.status = st
        self.lastErrorMessage = ""
        self.wallpaperEnabled = st.wallpaperEnabled
        self.ambientGlow = st.ambientGlow
        self.dimPercent = Double(max(0, min(85, st.wallpaperDim)))
    }

    private func applyOfflineState(errorDetail: String) {
        self.connecting = false
        self.connected = false
        self.status = nil
        self.lastErrorMessage = errorDetail
        self.previewImage = nil
        self.wifiSummary = TvClient.inspectWifi()
    }

    func scanForTvs() async {
        busyMessage = "Scanning Wi-Fi for CleanYourTV..."
        let found = await client.discoverTvs()
        let wifi = TvClient.inspectWifi()
        self.wifiSummary = wifi
        busyMessage = nil

        if found.isEmpty {
            let msg = wifi.wifiConnected
                ? "No TV found on \(wifi.prefix.isEmpty ? "Wi-Fi" : "\(wifi.prefix)*"). Check IP on TV."
                : "iPhone is not connected to Wi-Fi."
            showToast(msg, duration: 3.2)
            prefoundTvs = []
            focusIpInConnectSheet = true
            showConnectSheet = true
        } else if found.count == 1 {
            let tv = found[0]
            client.setEndpoint(host: tv.host, port: tv.port)
            showToast("Found \(tv.model) (\(tv.host))")
            await connectAndSync(autoScanOnFail: false)
        } else {
            prefoundTvs = found
            focusIpInConnectSheet = false
            showConnectSheet = true
        }
    }

    func setPreviewMode(restMode: Bool) {
        previewRestMode = restMode
        Task {
            await refreshPreviewBitmap()
        }
    }

    func refreshPreviewBitmap() async {
        let rest = previewRestMode
        do {
            guard let data = try await client.fetchPreviewData(restMode: rest) else {
                self.previewImage = nil
                return
            }
            let img = await Task.detached(priority: .userInitiated) {
                ImageProcessor.decodeDownsampled(data: data, maxPixelSize: 960)
            }.value
            self.previewImage = img
        } catch {
            self.previewImage = nil
        }
    }

    func refreshSavedWallpapers() async {
        do {
            let items = try await client.fetchSavedWallpapers()
            self.savedItems = items
            let validNames = Set(items.map(\.name))
            self.savedThumbnails = self.savedThumbnails.filter { validNames.contains($0.key) }
            if selectedCategory == "Saved on TV" {
                preloadSavedThumbnails(items)
            }
        } catch {
            // Keep existing cached list when momentarily offline
        }
    }

    func ensureSavedThumbnail(name: String) {
        guard savedThumbnails[name] == nil, !loadingSavedThumbNames.contains(name) else { return }
        loadingSavedThumbNames.insert(name)
        Task {
            defer { loadingSavedThumbNames.remove(name) }
            if let data = try? await client.fetchSavedThumbnailData(name: name) {
                let img = await Task.detached(priority: .utility) {
                    ImageProcessor.decodeDownsampled(data: data, maxPixelSize: 480)
                }.value
                if let img {
                    self.savedThumbnails[name] = img
                }
            }
        }
    }

    private func preloadSavedThumbnails(_ items: [SavedWallpaperItem]) {
        for item in items.prefix(12) {
            ensureSavedThumbnail(name: item.name)
        }
    }

    func selectCategory(_ category: String) {
        selectedCategory = category
        if category == "Saved on TV" {
            preloadSavedThumbnails(savedItems)
            Task { await refreshSavedWallpapers() }
        }
    }

    func filteredPresets() -> [ThemePreset] {
        switch selectedCategory {
        case "All":
            return presets
        case "Favorites":
            return presets.filter { favoriteIds.contains($0.id) }
        default:
            return presets.filter { $0.category == selectedCategory }
        }
    }

    func toggleFavorite(_ presetId: String) {
        favoriteIds = store.toggleFavorite(presetId)
    }

    func launchPhotoPicker(target: CropTarget) {
        pendingCropTarget = target
        showPhotoPicker = true
    }

    func openCrop(with data: Data) {
        cropInput = CropInputItem(
            data: data,
            initialTarget: pendingCropTarget,
            columns: status?.columns ?? 5
        )
    }

    func applyPureOledBlack() {
        runAction(label: "Switching to Pure OLED Black...", reloadAfter: true) {
            try await self.client.updateConfig([
                "wallpaper": false,
                "background_color": "#000000",
                "rest_mode": "sharp"
            ])
        }
    }

    func setRestSharp() {
        runAction(label: "Setting sharp Rest Mode...", reloadAfter: true) {
            try await self.client.setRestSharp()
        }
    }

    func autoBlurCurrentForRest() {
        runAction(label: "Soft-blurring active wallpaper...", reloadAfter: true) {
            guard let data = try await self.client.fetchPreviewData(restMode: false),
                  let src = ImageProcessor.decodeDownsampled(data: data, maxPixelSize: 960) else {
                throw TvClientError.message("No active home wallpaper")
            }
            let jpeg = await Task.detached(priority: .userInitiated) { () -> Data? in
                let blurred = ImageProcessor.gaussianBlur(image: src, radius: 16)
                return ImageProcessor.jpegData(from: blurred, quality: 0.88)
            }.value
            guard let jpeg else { throw TvClientError.message("Failed encoding blurred image") }
            try await self.client.uploadRestWallpaper(jpegData: jpeg)
        }
    }

    func applyPreset(_ preset: ThemePreset, includeStyle: Bool, restOnly: Bool) {
        if !preset.wallpaper || preset.asset.isEmpty {
            applyPureOledBlack()
            return
        }
        let label = restOnly
            ? "Updating Rest Mode..."
            : (includeStyle ? "Applying \(preset.title) look..." : "Putting \(preset.title) on TV...")
        runAction(label: label, reloadAfter: true) {
            guard let data = self.store.readAssetData(preset.asset) else {
                throw TvClientError.message("Missing theme artwork")
            }
            if restOnly {
                try await self.client.uploadRestWallpaper(jpegData: data)
            } else if includeStyle {
                try await self.client.uploadHomeWallpaper(
                    jpegData: data,
                    restMode: "sharp",
                    dimPercent: preset.dim,
                    ambientGlow: preset.ambientGlow,
                    accentColor: preset.accentColor,
                    backgroundColor: preset.backgroundColor
                )
            } else {
                try await self.client.uploadHomeWallpaper(jpegData: data, restMode: "sharp")
            }
        }
    }

    func applyRecent(_ entry: RecentEntry, restOnly: Bool) {
        let label = restOnly ? "Updating Rest Mode..." : "Sending to TV..."
        runAction(label: label, reloadAfter: true) {
            let data = try Data(contentsOf: entry.fileURL)
            if restOnly {
                try await self.client.uploadRestWallpaper(jpegData: data)
            } else {
                try await self.client.uploadHomeWallpaper(jpegData: data, restMode: "sharp")
            }
        }
    }

    func applyGradient(preset: GradientPreset, glowStrength: Float, vignetteStrength: Float, topLeft: Bool, restOnly: Bool) {
        let label = restOnly ? "Updating Rest Mode..." : "Creating \(preset.name) wallpaper..."
        runAction(label: label, reloadAfter: true) {
            let jpeg = await Task.detached(priority: .userInitiated) { () -> Data? in
                let full = GradientRenderer.render(
                    width: 1920,
                    height: 1080,
                    preset: preset,
                    glowStrength: glowStrength,
                    vignetteStrength: vignetteStrength,
                    topLeftGlow: topLeft
                )
                return ImageProcessor.jpegData(from: full, quality: restOnly ? 0.90 : 0.92)
            }.value
            guard let jpeg else { throw TvClientError.message("Failed creating gradient") }
            self.store.saveRecent(label: preset.name, jpegData: jpeg)
            self.refreshRecents()
            if restOnly {
                try await self.client.uploadRestWallpaper(jpegData: jpeg)
            } else {
                let fname = "gradient_\(preset.name.lowercased()).jpg"
                try await self.client.uploadHomeWallpaper(jpegData: jpeg, saveName: fname, restMode: "sharp")
            }
        }
    }

    func selectSaved(_ item: SavedWallpaperItem) {
        runAction(label: "Switching TV wallpaper...", reloadAfter: true) {
            try await self.client.selectSavedWallpaper(name: item.name, restMode: "sharp")
        }
    }

    func deleteSaved(_ item: SavedWallpaperItem) {
        runAction(label: "Removing from TV...", reloadAfter: true) {
            try await self.client.deleteSavedWallpaper(name: item.name)
            self.savedThumbnails.removeValue(forKey: item.name)
        }
    }

    func pushConfigPatch(_ patch: [String: Any], refreshPreview: Bool = false) {
        Task {
            do {
                try await client.updateConfig(patch)
                let st = try await client.fetchStatus()
                applyConnectedStatus(st)
                if refreshPreview {
                    await refreshPreviewBitmap()
                }
            } catch {
                showToast("Update failed: \(error.localizedDescription)")
            }
        }
    }

    func runAction(label: String, reloadAfter: Bool, task: @escaping @MainActor () async throws -> Void) {
        busyMessage = label
        Task {
            do {
                try await task()
                if reloadAfter {
                    let st = try await client.fetchStatus()
                    busyMessage = nil
                    applyConnectedStatus(st)
                    showToast("TV updated!")
                    await refreshPreviewBitmap()
                    await refreshSavedWallpapers()
                } else {
                    busyMessage = nil
                    showToast("Done")
                }
            } catch {
                busyMessage = nil
                showToast("Error: \(error.localizedDescription)", duration: 3.4)
            }
        }
    }

    func showToast(_ message: String, duration: Double = 2.4) {
        toastHideTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) {
            toastMessage = message
        }
        toastHideTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.toastMessage = nil
                    }
                }
            }
        }
    }
}
