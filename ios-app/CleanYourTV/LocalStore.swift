import Foundation
import UIKit

final class LocalStore: @unchecked Sendable {
    private let defaults = UserDefaults.standard
    private let lock = NSLock()
    private let favKey = "cyt_fav_ids"
    private let maxRecents = 8

    func loadPresets() -> [ThemePreset] {
        let url: URL? =
            Bundle.main.resourceURL?.appendingPathComponent("themes/themes.json")
            ?? Bundle.main.url(forResource: "themes", withExtension: "json", subdirectory: "themes")
        guard let fileUrl = url,
              let data = try? Data(contentsOf: fileUrl),
              let list = try? JSONDecoder().decode([ThemePreset].self, from: data) else {
            return []
        }
        return list
    }

    func assetURL(for relativePath: String) -> URL? {
        guard !relativePath.isEmpty else { return nil }
        if let root = Bundle.main.resourceURL?.appendingPathComponent(relativePath),
           FileManager.default.fileExists(atPath: root.path) {
            return root
        }
        let ns = relativePath as NSString
        let dir = ns.deletingLastPathComponent
        let base = (ns.lastPathComponent as NSString).deletingPathExtension
        let ext = (ns.lastPathComponent as NSString).pathExtension
        return Bundle.main.url(
            forResource: base,
            withExtension: ext.isEmpty ? nil : ext,
            subdirectory: dir.isEmpty ? nil : dir
        )
    }

    func readAssetData(_ relativePath: String) -> Data? {
        guard let url = assetURL(for: relativePath) else { return nil }
        return try? Data(contentsOf: url)
    }

    func loadAssetImage(_ relativePath: String, maxPixel: Int = 960) -> UIImage? {
        guard let data = readAssetData(relativePath) else { return nil }
        return ImageProcessor.decodeDownsampled(data: data, maxPixelSize: maxPixel)
    }

    func favoriteIds() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(defaults.stringArray(forKey: favKey) ?? [])
    }

    func isFavorite(_ id: String) -> Bool {
        favoriteIds().contains(id)
    }

    @discardableResult
    func toggleFavorite(_ id: String) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        var set = Set(defaults.stringArray(forKey: favKey) ?? [])
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
        defaults.set(Array(set), forKey: favKey)
        return set
    }

    func saveRecent(label: String, jpegData: Data) {
        guard !jpegData.isEmpty, let dir = recentsDirectory(create: true) else { return }
        let safe = label
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let clipped = String(safe.prefix(28))
        let ms = Int64(Date().timeIntervalSince1970 * 1000)
        let fileURL = dir.appendingPathComponent("\(ms)__\(clipped.isEmpty ? "Wallpaper" : clipped).jpg")
        try? jpegData.write(to: fileURL, options: .atomic)
        pruneRecents(in: dir)
    }

    func listRecents() -> [RecentEntry] {
        guard let dir = recentsDirectory(create: false),
              let urls = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        let jpgs = urls.filter { $0.pathExtension.lowercased() == "jpg" }
        let sorted = jpgs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        return sorted.map { url in
            let name = url.deletingPathExtension().lastPathComponent
            let label: String
            if let range = name.range(of: "__") {
                label = String(name[range.upperBound...]).replacingOccurrences(of: "_", with: " ")
            } else {
                label = "Custom"
            }
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            return RecentEntry(fileURL: url, label: label, modified: mod)
        }
    }

    func oflNoticeText() -> String {
        if let url = Bundle.main.url(forResource: "OFL", withExtension: "txt"),
           let txt = try? String(contentsOf: url, encoding: .utf8) {
            return txt
        }
        return "Outfit Font — SIL Open Font License 1.1\nhttps://scripts.sil.org/OFL"
    }

    private func recentsDirectory(create: Bool) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("CleanYourTV/recents", isDirectory: true)
        if create && !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func pruneRecents(in dir: URL) {
        let items = listRecents()
        guard items.count > maxRecents else { return }
        for item in items.dropFirst(maxRecents) {
            try? FileManager.default.removeItem(at: item.fileURL)
        }
    }
}
